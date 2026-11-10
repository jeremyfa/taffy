// Ported from taffy 0.15.0: src/tree/cache.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

import taffy.geometry.LineOf;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.AvailableSpace;
import taffy.style.AvailableSpace.Definite;
import taffy.util.OptionalFloat;

/**
 * The cache key of a layout input. Internal (`Cache` extends it: the cache is the key of its final
 * layout entry, and `NodeData` extends `Cache`: nothing is allocated per node for its cache).
 *
 * Rust packs the f32 bits of the values into integers. This port compares the float values
 * directly (with an extra flag telling known dimensions apart from available space), which
 * is equivalent except for NaN values and is much faster on targets without cheap float to bits conversion.
 */
@:noCompletion
class CacheKey {

    /** The known dimension (or encoded available space) in the horizontal axis */
    public var kdAvWidth:Float = 0.0;

    /** The known dimension (or encoded available space) in the vertical axis */
    public var kdAvHeight:Float = 0.0;

    /** Bit 0: `kdAvWidth` is a known dimension, bit 1: `kdAvHeight` is a known dimension */
    public var kdFlags:Int = 0;

    /** The absolute parent width (infinity when unknown, sign dropped like the Rust bit packing) */
    public var parentWidth:Float = 0.0;

    /** The absolute parent height (infinity when unknown, sign dropped like the Rust bit packing) */
    public var parentHeight:Float = 0.0;

    /** The requested axis bits: 1 horizontal, 2 vertical, 3 both */
    public var axisBits:Int = 0;

    /** Whether each known dimension is definite (bit 0: width, bit 1: height), normalized to true without a known dimension */
    public var definite:Int = 0;

    /*
     * What the key drops of the input the entry was computed for (the available space where a
     * known dimension replaces it, the parent size before its sign is dropped): with the key and
     * the cache's mode, the input itself, which `Cache.matchesRelayout()` lays a node out again
     * for. Not in Rust taffy.
     */
    public var inputAvailableWidth:AvailableSpace = MaxContent;
    public var inputAvailableHeight:AvailableSpace = MaxContent;
    public var inputParentWidth:OptionalFloat = OptionalFloat.NONE;
    public var inputParentHeight:OptionalFloat = OptionalFloat.NONE;

    public function new() {}

    /** Records what the key of `input` drops (see `inputAvailableWidth`) */
    public inline function recordInput(input:LayoutInput):Void {
        final available = input.availableSpace;
        inputAvailableWidth = available.width;
        inputAvailableHeight = available.height;
        final parent = input.parentSize;
        inputParentWidth = parent.width;
        inputParentHeight = parent.height;
    }

    /** Copies the recorded input of `other` */
    public inline function copyInputFrom(other:CacheKey):Void {
        inputAvailableWidth = other.inputAvailableWidth;
        inputAvailableHeight = other.inputAvailableHeight;
        inputParentWidth = other.inputParentWidth;
        inputParentHeight = other.inputParentHeight;
    }

    static final TRUE_TRUE:SizeOf<Bool> = new SizeOf<Bool>(true, true);
    static final TRUE_FALSE:SizeOf<Bool> = new SizeOf<Bool>(true, false);
    static final FALSE_TRUE:SizeOf<Bool> = new SizeOf<Bool>(false, true);
    static final FALSE_FALSE:SizeOf<Bool> = new SizeOf<Bool>(false, false);
    static final LINE_TRUE_TRUE:LineOf<Bool> = new LineOf<Bool>(true, true);
    static final LINE_TRUE_FALSE:LineOf<Bool> = new LineOf<Bool>(true, false);
    static final LINE_FALSE_TRUE:LineOf<Bool> = new LineOf<Bool>(false, true);
    static final LINE_FALSE_FALSE:LineOf<Bool> = new LineOf<Bool>(false, false);

    /**
     * The input of this entry (its key, its recorded part and `mode`, the `Cache.mode` bits) as a
     * pooled `LayoutInput` (`LayoutInput.release()` after the call it is given to). The definiteness
     * of an absent known dimension comes back as true, as the key and the algorithms read it.
     */
    public inline function acquireInput(runMode:RunMode, mode:Int):LayoutInput {
        final knownWidth = (kdFlags & 1) != 0 ? OptionalFloat.some(kdAvWidth) : OptionalFloat.NONE;
        final knownHeight = (kdFlags & 2) != 0 ? OptionalFloat.some(kdAvHeight) : OptionalFloat.NONE;
        final kdd = (definite & 1) != 0 ? ((definite & 2) != 0 ? TRUE_TRUE : TRUE_FALSE) : ((definite & 2) != 0 ? FALSE_TRUE : FALSE_FALSE);
        final start = (mode & 2) != 0;
        final end = (mode & 4) != 0;
        final collapsible = start ? (end ? LINE_TRUE_TRUE : LINE_TRUE_FALSE) : (end ? LINE_FALSE_TRUE : LINE_FALSE_FALSE);
        final axis:RequestedAxis = axisBits == 1 ? Horizontal : (axisBits == 2 ? Vertical : Both);
        final sizingMode:SizingMode = (mode & 1) != 0 ? InherentSize : ContentSize;
        return LayoutInput.acquireParts(runMode, sizingMode, axis, knownWidth, knownHeight, kdd, inputParentWidth, inputParentHeight,
            inputAvailableWidth, inputAvailableHeight, collapsible);
    }

    public inline function setFrom(input:LayoutInput):Void {
        final kd = input.knownDimensions;
        final av = input.availableSpace;
        final kdw = kd.width;
        final kdh = kd.height;
        var flags = 0;
        if (kdw.isSome()) {
            kdAvWidth = kdw.unwrap();
            flags |= 1;
        }
        else {
            kdAvWidth = availableSpaceCacheKey(av.width);
        }
        if (kdh.isSome()) {
            kdAvHeight = kdh.unwrap();
            flags |= 2;
        }
        else {
            kdAvHeight = availableSpaceCacheKey(av.height);
        }
        kdFlags = flags;
        final pw = input.parentSize.width;
        final ph = input.parentSize.height;
        parentWidth = pw.isSome() ? Math.abs(pw.unwrap()) : Math.POSITIVE_INFINITY;
        parentHeight = ph.isSome() ? Math.abs(ph.unwrap()) : Math.POSITIVE_INFINITY;
        axisBits = switch input.axis {
            case Horizontal: 1;
            case Vertical: 2;
            case Both: 3;
        }
        final kdd = input.knownDimensionsAreDefinite;
        definite = ((kdd.width || kdw.isNone()) ? 1 : 0) | ((kdd.height || kdh.isNone()) ? 2 : 0);
    }

    public inline function copyFrom(other:CacheKey):Void {
        copyInputFrom(other);
        kdAvWidth = other.kdAvWidth;
        kdAvHeight = other.kdAvHeight;
        kdFlags = other.kdFlags;
        parentWidth = other.parentWidth;
        parentHeight = other.parentHeight;
        axisBits = other.axisBits;
        definite = other.definite;
    }

    /** Whether the known dimensions / available space parts of both keys are equal */
    public inline function kdAvEquals(other:CacheKey):Bool {
        return kdAvWidth == other.kdAvWidth && kdAvHeight == other.kdAvHeight && kdFlags == other.kdFlags;
    }

    public inline function equals(other:CacheKey):Bool {
        return kdAvEquals(other)
            && parentWidth == other.parentWidth
            && parentHeight == other.parentHeight
            && axisBits == other.axisBits
            && definite == other.definite;
    }

    /**
     * Whether a cached entry with this key contains a valid size for the axis requested by `other`.
     * Sizes computed for a single axis may contain garbage values in the other axis.
     */
    public inline function sizeIsValidFor(other:CacheKey):Bool {
        return axisBits == 3 || axisBits == other.axisBits;
    }

    /** Encode an available space like Rust: definite values are negated, min-content is -infinity, max-content is +infinity */
    static inline function availableSpaceCacheKey(input:AvailableSpace):Float {
        return switch input {
            case MinContent: Math.NEGATIVE_INFINITY;
            case MaxContent: Math.POSITIVE_INFINITY;
            case definite: -definite.definiteValue();
        }
    }

}

/**
 * A cached measurement entry
 */
private class MeasureEntry extends CacheKey {

    /** The key of the entry (the entry itself: one object instead of two) */
    public var key(get, never):CacheKey;

    inline function get_key():CacheKey {
        return this;
    }

    public var content:Size = Size.ZERO;

    /** The output returned by cache hits, built from `content` on the first hit and shared by the next ones */
    public var output:Null<LayoutOutput> = null;

    /** The next entry (entries are a chain of at most `CACHE_SIZE`, made on first use: no array per cache) */
    public var next:Null<MeasureEntry> = null;

    public function new() {
        super();
    }

}

/**
 * Cached intermediate layout results of a node.
 *
 * The cache is the key of its final layout entry (no key object per cache), and the measure
 * entries are a chain made on first use (no array per cache).
 */
class Cache extends CacheKey {

    /** The number of cache entries for each node in the tree */
    static inline final CACHE_SIZE:Int = 9;

    /** Set if the sizing mode is `InherentSize` */
    static inline final INHERENT_SIZE_BIT:Int = 1;

    /** Set if the node's top margin is collapsible */
    static inline final COLLAPSIBLE_START_MARGIN_BIT:Int = 2;

    /** Set if the node's bottom margin is collapsible */
    static inline final COLLAPSIBLE_END_MARGIN_BIT:Int = 4;

    /**
     * The number of times a result was stored into a non-empty cache whose entries were computed with
     * a different `sizingMode` or `verticalMarginsAreCollapsible`, dropping those entries.
     */
    public static var modeChangeEvictions:Int = 0;

    /**
     * Whether stored entries record their input (`recordInput`), set from `TaffyTree.recordInputs`
     * while a tree lays out. Without it, a stored entry makes the cache `lossy`.
     */
    @:noCompletion
    public static var recordInputs:Bool = true;

    /** A key reused for lookups to avoid allocations */
    static final scratchKey:CacheKey = new CacheKey();

    /** The key of the final layout entry (the cache itself) */
    var finalLayoutKey(get, never):CacheKey;

    inline function get_finalLayoutKey():CacheKey {
        return this;
    }

    /** The cache entry for the node's final layout */
    var finalLayoutEntry:Null<LayoutOutput> = null;

    /** The cache entries for the node's preliminary size measurements: entry `i` is the `i`th of the chain (made on first use) */
    var firstMeasureEntry:Null<MeasureEntry> = null;

    /** Which measure entries hold a value */
    var usedEntries:Int = 0;

    /** Tracks which measure entries have been used since the eviction cursor last passed them */
    var recentlyUsedEntries:Int = 0;

    /** The next measure entry to consider replacing */
    var nextMeasureEntry:Int = 0;

    /** Tracks if all cache entries are empty */
    var empty:Bool = true;

    /** The `sizingMode` and `verticalMarginsAreCollapsible` inputs that all of the cache's entries were computed with */
    var mode:Int = 0;

    /**
     * Whether a result computed since the cache was last cleared is missing from it (not cached,
     * evicted, replaced, or computed in a way that is not cached: hidden layout, a block formatting
     * context shared with the parent). While false, the entries hold every input the node was laid
     * out for since then, which `matchesRelayout()` relies on. Not in Rust taffy.
     */
    public var lossy(default, null):Bool = false;

    public function new() {
        super();
    }

    /** Marks a result missing from the cache (see `lossy`) */
    public inline function markLossy():Void {
        lossy = true;
    }

    /** Whether the cache holds a final layout entry */
    public inline function hasFinalLayout():Bool {
        return finalLayoutEntry != null;
    }

    /** The same value, zero signs included (NaN matches NaN) */
    static inline function sameFloat(a:Float, b:Float):Bool {
        return a == b ? (a != 0.0 || 1.0 / a == 1.0 / b) : (a != a && b != b);
    }

    static inline function sameSize(a:Size, b:Size):Bool {
        return a == b || (sameFloat(a.width, b.width) && sameFloat(a.height, b.height));
    }

    static inline function sameOptional(a:OptionalFloat, b:OptionalFloat):Bool {
        return a.isNone() ? b.isNone() : (b.isSome() && sameFloat(a.unwrap(), b.unwrap()));
    }

    /** Whether two final layout outputs are the same for a parent (out-of-flow candidates: none on both) */
    static function sameFinalOutput(a:LayoutOutput, b:LayoutOutput):Bool {
        if (a == b)
            return true;
        if (!a.oofCandidates.isEmpty() || !b.oofCandidates.isEmpty())
            return false;
        final ra = a.scrollableOverflowRect;
        final rb = b.scrollableOverflowRect;
        return sameSize(a.size, b.size)
            && (ra == rb || (sameFloat(ra.left, rb.left) && sameFloat(ra.right, rb.right) && sameFloat(ra.top, rb.top) && sameFloat(ra.bottom, rb.bottom)))
            && (a.baselines == b.baselines || (sameOptional(a.baselines.first, b.baselines.first) && sameOptional(a.baselines.last, b.baselines.last)))
            && (a.topMargin == b.topMargin || (sameFloat(a.topMargin.positive, b.topMargin.positive) && sameFloat(a.topMargin.negative, b.topMargin.negative)))
            && (a.bottomMargin == b.bottomMargin || (sameFloat(a.bottomMargin.positive, b.bottomMargin.positive) && sameFloat(a.bottomMargin.negative, b.bottomMargin.negative)))
            && a.marginsCanCollapseThrough == b.marginsCanCollapseThrough;
    }

    /** See `TaffyTree.matchesRelayout` (this is the reference) */
    @:allow(taffy.tree.TaffyTree)
    function matchesRelayout(tree:LayoutPartialTree, nodeId:NodeId):Bool {
        var entry = firstMeasureEntry;
        var index = 0;
        while (entry != null) {
            if (usedEntries & (1 << index) != 0) {
                final output = tree.computeChildLayout(nodeId, entry.acquireInput(ComputeSize, mode));
                LayoutInput.release();
                if (!sameSize(output.size, entry.content))
                    return false;
            }
            entry = entry.next;
            index++;
        }
        final reference = finalLayoutEntry;
        final output = tree.computeChildLayout(nodeId, acquireInput(PerformLayout, mode));
        LayoutInput.release();
        return sameFinalOutput(output, reference);
    }

    /** A copy of this cache (its entries, keys, recorded inputs and state). Not in Rust taffy. */
    public function snapshot():Cache {
        final copy = new Cache();
        copy.copyFrom(this);
        copy.finalLayoutEntry = finalLayoutEntry;
        var entry = firstMeasureEntry;
        var last:Null<MeasureEntry> = null;
        while (entry != null) {
            final copied = new MeasureEntry();
            copied.copyFrom(entry);
            copied.content = entry.content;
            copied.output = entry.output;
            if (last == null)
                copy.firstMeasureEntry = copied;
            else
                last.next = copied;
            last = copied;
            entry = entry.next;
        }
        copy.usedEntries = usedEntries;
        copy.recentlyUsedEntries = recentlyUsedEntries;
        copy.nextMeasureEntry = nextMeasureEntry;
        copy.empty = empty;
        copy.mode = mode;
        copy.lossy = lossy;
        return copy;
    }

    /** The measure entry at `index`, made with the entries before it when missing */
    function measureEntryAt(index:Int):MeasureEntry {
        var entry = firstMeasureEntry;
        if (entry == null) {
            entry = new MeasureEntry();
            firstMeasureEntry = entry;
        }
        for (_ in 0...index) {
            var next = entry.next;
            if (next == null) {
                next = new MeasureEntry();
                entry.next = next;
            }
            entry = next;
        }
        return entry;
    }

    static inline function modeOf(input:LayoutInput):Int {
        return (input.sizingMode == InherentSize ? INHERENT_SIZE_BIT : 0)
            | (input.verticalMarginsAreCollapsible.start ? COLLAPSIBLE_START_MARGIN_BIT : 0)
            | (input.verticalMarginsAreCollapsible.end ? COLLAPSIBLE_END_MARGIN_BIT : 0);
    }

    /** Try to retrieve a cached result from the cache */
    @:noDebug
    public function get(input:LayoutInput):Null<LayoutOutput> {
        if (mode != modeOf(input))
            return null;
        final key = scratchKey;
        key.setFrom(input);
        switch input.runMode {
            case PerformLayout:
                if (finalLayoutEntry != null && finalLayoutKey.equals(key)) {
                    // Shared without a copy when it carries no out-of-flow candidates: callers never
                    // mutate the output of a child layout (only the algorithm that builds an output
                    // updates it, before it is stored), they only `take()` its candidates, which
                    // leaves an empty list unchanged. A list with candidates is copied, as `take()`
                    // empties it.
                    return finalLayoutEntry.oofCandidates.isEmpty() ? finalLayoutEntry : finalLayoutEntry.clone();
                }
                return null;
            case ComputeSize:
                var entry = firstMeasureEntry;
                var index = 0;
                while (entry != null) {
                    final current = entry;
                    final currentIndex = index;
                    entry = entry.next;
                    index++;
                    if (usedEntries & (1 << currentIndex) == 0)
                        continue;
                    final ek = current.key;
                    if (ek.kdAvEquals(key)
                        && ek.definite == key.definite
                        && ek.parentWidth == key.parentWidth
                        && ek.sizeIsValidFor(key)) {
                        recentlyUsedEntries |= 1 << currentIndex;
                        // Shared between hits, like the final layout entry above
                        var output = current.output;
                        if (output == null) {
                            output = LayoutOutput.fromOuterSize(current.content);
                            current.output = output;
                        }
                        return output;
                    }
                }
                return null;
            case PerformHiddenLayout:
                return null;
        }
    }

    /** Store a computed size in the cache */
    @:noDebug
    public function store(input:LayoutInput, layoutOutput:LayoutOutput):Void {
        if (input.runMode == PerformHiddenLayout)
            return;
        final m = modeOf(input);
        if (mode != m) {
            final dropped = !empty;
            if (dropped)
                modeChangeEvictions++;
            clear();
            mode = m;
            if (dropped)
                lossy = true;
        }
        switch input.runMode {
            case PerformLayout:
                if (finalLayoutEntry != null && !lossy) {
                    final key = scratchKey;
                    key.setFrom(input);
                    if (!finalLayoutKey.equals(key))
                        lossy = true;
                }
                empty = false;
                finalLayoutKey.setFrom(input);
                if (recordInputs)
                    finalLayoutKey.recordInput(input);
                else
                    lossy = true;
                // See `get`: an output without candidates is never mutated once returned, so it is
                // kept as is (an empty list is normalized so that `take()` cannot reach its array)
                if (layoutOutput.oofCandidates.isEmpty()) {
                    layoutOutput.oofCandidates = OofCandidates.EMPTY;
                    finalLayoutEntry = layoutOutput;
                }
                else {
                    finalLayoutEntry = layoutOutput.clone();
                }
            case ComputeSize:
                // Results that carry margin-collapse metadata cannot be reconstructed from their size, so don't cache them
                if (layoutOutput.marginsCanCollapseThrough
                    || !layoutOutput.topMargin.equals(CollapsibleMarginSet.ZERO)
                    || !layoutOutput.bottomMargin.equals(CollapsibleMarginSet.ZERO)) {
                    lossy = true;
                    return;
                }
                empty = false;
                final key = scratchKey;
                key.setFrom(input);
                // Entries are created on first use (most nodes use one or two)
                var existing = firstMeasureEntry;
                var existingIndex = 0;
                while (existing != null) {
                    final index = existingIndex;
                    final entry = existing;
                    existing = existing.next;
                    existingIndex++;
                    if (usedEntries & (1 << index) != 0 && entry.key.equals(key)) {
                        if (entry.content != layoutOutput.size) {
                            entry.content = layoutOutput.size;
                            entry.output = null;
                        }
                        recentlyUsedEntries |= 1 << index;
                        return;
                    }
                }
                while (recentlyUsedEntries & (1 << nextMeasureEntry) != 0) {
                    recentlyUsedEntries &= ~(1 << nextMeasureEntry);
                    nextMeasureEntry++;
                    if (nextMeasureEntry == CACHE_SIZE)
                        nextMeasureEntry = 0;
                }
                final entryIndex = nextMeasureEntry;
                if (usedEntries & (1 << entryIndex) != 0)
                    lossy = true;
                final entry = measureEntryAt(entryIndex);
                entry.key.copyFrom(key);
                if (recordInputs)
                    entry.key.recordInput(input);
                else
                    lossy = true;
                entry.content = layoutOutput.size;
                entry.output = null;
                usedEntries |= 1 << entryIndex;
                recentlyUsedEntries |= 1 << entryIndex;
                nextMeasureEntry++;
                if (nextMeasureEntry == CACHE_SIZE)
                    nextMeasureEntry = 0;
            case PerformHiddenLayout:
        }
    }

    /** Clear all cache entries and reports clear operation outcome */
    public function clear():ClearState {
        lossy = false;
        if (empty)
            return AlreadyEmpty;
        empty = true;
        finalLayoutEntry = null;
        usedEntries = 0;
        recentlyUsedEntries = 0;
        nextMeasureEntry = 0;
        return Cleared;
    }

    /** Returns true if all cache entries are empty, else false */
    public function isEmpty():Bool {
        return finalLayoutEntry == null && usedEntries == 0;
    }

}
