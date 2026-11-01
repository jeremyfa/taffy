// Ported from taffy 0.15.0: src/tree/cache.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.AvailableSpace;
import taffy.style.AvailableSpace.Definite;

/**
 * The cache key of a layout input.
 *
 * Rust packs the f32 bits of the values into integers. This port compares the float values
 * directly (with an extra flag telling known dimensions apart from available space), which
 * is equivalent except for NaN values and is much faster on targets without cheap float to bits conversion.
 */
private class CacheKey {

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

    public function new() {}

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
private class MeasureEntry {

    public final key:CacheKey = new CacheKey();

    public var content:Size = Size.ZERO;

    public function new() {}

}

/**
 * Cached intermediate layout results of a node
 */
class Cache {

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

    /** A key reused for lookups to avoid allocations */
    static final scratchKey:CacheKey = new CacheKey();

    /** The key of the final layout entry */
    final finalLayoutKey:CacheKey = new CacheKey();

    /** The cache entry for the node's final layout */
    var finalLayoutEntry:Null<LayoutOutput> = null;

    /** The cache entries for the node's preliminary size measurements (lazily allocated) */
    var measureEntries:Null<Array<MeasureEntry>> = null;

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

    public function new() {}

    static inline function modeOf(input:LayoutInput):Int {
        return (input.sizingMode == InherentSize ? INHERENT_SIZE_BIT : 0)
            | (input.verticalMarginsAreCollapsible.start ? COLLAPSIBLE_START_MARGIN_BIT : 0)
            | (input.verticalMarginsAreCollapsible.end ? COLLAPSIBLE_END_MARGIN_BIT : 0);
    }

    /** Try to retrieve a cached result from the cache */
    public function get(input:LayoutInput):Null<LayoutOutput> {
        if (mode != modeOf(input))
            return null;
        final key = scratchKey;
        key.setFrom(input);
        switch input.runMode {
            case PerformLayout:
                if (finalLayoutEntry != null && finalLayoutKey.equals(key))
                    return finalLayoutEntry.clone();
                return null;
            case ComputeSize:
                if (measureEntries == null)
                    return null;
                for (index in 0...CACHE_SIZE) {
                    if (usedEntries & (1 << index) == 0)
                        continue;
                    final entry = measureEntries[index];
                    final ek = entry.key;
                    if (ek.kdAvEquals(key)
                        && ek.definite == key.definite
                        && ek.parentWidth == key.parentWidth
                        && ek.sizeIsValidFor(key)) {
                        recentlyUsedEntries |= 1 << index;
                        return LayoutOutput.fromOuterSize(entry.content);
                    }
                }
                return null;
            case PerformHiddenLayout:
                return null;
        }
    }

    /** Store a computed size in the cache */
    public function store(input:LayoutInput, layoutOutput:LayoutOutput):Void {
        if (input.runMode == PerformHiddenLayout)
            return;
        final m = modeOf(input);
        if (mode != m) {
            if (!empty)
                modeChangeEvictions++;
            clear();
            mode = m;
        }
        switch input.runMode {
            case PerformLayout:
                empty = false;
                finalLayoutKey.setFrom(input);
                finalLayoutEntry = layoutOutput.clone();
            case ComputeSize:
                // Results that carry margin-collapse metadata cannot be reconstructed from their size, so don't cache them
                if (layoutOutput.marginsCanCollapseThrough
                    || !layoutOutput.topMargin.equals(CollapsibleMarginSet.ZERO)
                    || !layoutOutput.bottomMargin.equals(CollapsibleMarginSet.ZERO)) {
                    return;
                }
                empty = false;
                final key = scratchKey;
                key.setFrom(input);
                if (measureEntries == null)
                    measureEntries = [for (_ in 0...CACHE_SIZE) new MeasureEntry()];
                for (index in 0...CACHE_SIZE) {
                    if (usedEntries & (1 << index) != 0 && measureEntries[index].key.equals(key)) {
                        measureEntries[index].content = layoutOutput.size;
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
                final entry = measureEntries[entryIndex];
                entry.key.copyFrom(key);
                entry.content = layoutOutput.size;
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
