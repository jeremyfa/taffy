// Ported from taffy 0.15.0: src/tree/layout.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

import taffy.geometry.LineOf;
import taffy.geometry.SizeOf;
import taffy.style.AvailableSpace;
import taffy.geometry.SizeOpt;
import taffy.geometry.SizeAvail;
import taffy.util.OptionalFloat;

/**
 * A struct containing the inputs constraints/hints for laying out a node, which are passed in by the parent.
 *
 * Immutable for its users (Rust passes it by value). The layout algorithms reuse the inputs they
 * pass to a child once the child call returns (`acquire` / `release`), so a layout function must
 * not keep a reference to its `inputs` after it returns.
 */
@:structInit
class LayoutInput {

    /** A LayoutInput that can be used to request hidden layout */
    public static final HIDDEN:LayoutInput = new LayoutInput(
        PerformHiddenLayout,
        InherentSize,
        Both,
        SizeOpt.NONE,
        new SizeOf<Bool>(true, true),
        SizeOpt.NONE,
        new SizeAvail(MaxContent, MaxContent),
        new LineOf<Bool>(false, false)
    );

    /** Whether we only need to know the Node's size, or whether we need to perform a full layout */
    public var runMode(default, null):RunMode;

    /** Whether a Node's style sizes should be taken into account or ignored */
    public var sizingMode(default, null):SizingMode;

    /** Which axis we need the size of */
    public var axis(default, null):RequestedAxis;

    /**
     * Known dimensions represent dimensions (width/height) which should be taken as fixed when performing layout.
     * Layout functions will be called with both known dimensions set for final layout.
     */
    public var knownDimensions(default, null):SizeOpt;

    /**
     * Whether each known dimension should be treated as a *definite* size when laying out the node's
     * own content. Ignored (treated as `true`) for axes where the corresponding known dimension is null.
     */
    public var knownDimensionsAreDefinite(default, null):SizeOf<Bool>;

    /** Parent size dimensions are intended to be used for percentage resolution. */
    public var parentSize(default, null):SizeOpt;

    /**
     * Available space represents an amount of space to layout into, and is used as a soft constraint
     * for the purpose of wrapping. A definite available space is the space available to the node's border box.
     */
    public var availableSpace(default, null):SizeAvail;

    /** Specific to CSS Block layout. Used for correctly computing margin collapsing. */
    public var verticalMarginsAreCollapsible(default, null):LineOf<Bool>;

    public inline function new(
        runMode:RunMode,
        sizingMode:SizingMode,
        axis:RequestedAxis,
        knownDimensions:SizeOpt,
        knownDimensionsAreDefinite:SizeOf<Bool>,
        parentSize:SizeOpt,
        availableSpace:SizeAvail,
        verticalMarginsAreCollapsible:LineOf<Bool>
    ) {
        this.runMode = runMode;
        this.sizingMode = sizingMode;
        this.axis = axis;
        this.knownDimensions = knownDimensions;
        this.knownDimensionsAreDefinite = knownDimensionsAreDefinite;
        this.parentSize = parentSize;
        this.availableSpace = availableSpace;
        this.verticalMarginsAreCollapsible = verticalMarginsAreCollapsible;
    }

    /**
     * Inputs reused for child calls, one per nesting level: `acquire` takes the input at `poolDepth`,
     * `release` gives it back once the child call that received it has returned (a child layout never
     * keeps its inputs). If a call throws, the level is not given back and the next calls use fresh
     * levels above it, which stays correct.
     */
    static final pool:Array<LayoutInput> = [];

    static var poolDepth:Int = 0;

    /**
     * An input for a child call (internal to the layout algorithms): call `release()` right after
     * the call that receives it returns, and do not use the input afterwards.
     */
    @:noCompletion
    public static inline function acquire(
        runMode:RunMode,
        sizingMode:SizingMode,
        axis:RequestedAxis,
        knownDimensions:SizeOpt,
        knownDimensionsAreDefinite:SizeOf<Bool>,
        parentSize:SizeOpt,
        availableSpace:SizeAvail,
        verticalMarginsAreCollapsible:LineOf<Bool>
    ):LayoutInput {
        final depth = poolDepth;
        poolDepth = depth + 1;
        return if (depth < pool.length) {
            pool[depth].reset(runMode, sizingMode, axis, knownDimensions, knownDimensionsAreDefinite, parentSize, availableSpace, verticalMarginsAreCollapsible);
        }
        else {
            final input = new LayoutInput(runMode, sizingMode, axis, knownDimensions, knownDimensionsAreDefinite, parentSize, availableSpace, verticalMarginsAreCollapsible);
            pool.push(input);
            input;
        }
    }

    /**
     * `acquire` with the sizes given as values: they are written into sizes owned by the pooled
     * input (no `SizeOpt` / `SizeAvail` allocated per child call).
     */
    @:noCompletion
    public static inline function acquireParts(
        runMode:RunMode,
        sizingMode:SizingMode,
        axis:RequestedAxis,
        knownWidth:OptionalFloat,
        knownHeight:OptionalFloat,
        knownDimensionsAreDefinite:SizeOf<Bool>,
        parentWidth:OptionalFloat,
        parentHeight:OptionalFloat,
        availableWidth:AvailableSpace,
        availableHeight:AvailableSpace,
        verticalMarginsAreCollapsible:LineOf<Bool>
    ):LayoutInput {
        final depth = poolDepth;
        poolDepth = depth + 1;
        var input:LayoutInput;
        if (depth < pool.length) {
            input = pool[depth];
        }
        else {
            input = new LayoutInput(runMode, sizingMode, axis, SizeOpt.NONE, knownDimensionsAreDefinite, SizeOpt.NONE, SizeAvail.MAX_CONTENT, verticalMarginsAreCollapsible);
            pool.push(input);
        }
        var known = input.ownKnown;
        if (known == null) {
            known = new SizeOpt(knownWidth, knownHeight);
            input.ownKnown = known;
        }
        else {
            known.set(knownWidth, knownHeight);
        }
        var parent = input.ownParent;
        if (parent == null) {
            parent = new SizeOpt(parentWidth, parentHeight);
            input.ownParent = parent;
        }
        else {
            parent.set(parentWidth, parentHeight);
        }
        var available = input.ownAvailable;
        if (available == null) {
            available = new SizeAvail(availableWidth, availableHeight);
            input.ownAvailable = available;
        }
        else {
            available.set(availableWidth, availableHeight);
        }
        return input.reset(runMode, sizingMode, axis, known, knownDimensionsAreDefinite, parent, available, verticalMarginsAreCollapsible);
    }

    /**
     * `acquire` with the known dimensions given as values, written into a size owned by the pooled
     * input (the other sizes are kept as given).
     */
    @:noCompletion
    public static inline function acquireKnownParts(
        runMode:RunMode,
        sizingMode:SizingMode,
        axis:RequestedAxis,
        knownWidth:OptionalFloat,
        knownHeight:OptionalFloat,
        knownDimensionsAreDefinite:SizeOf<Bool>,
        parentSize:SizeOpt,
        availableSpace:SizeAvail,
        verticalMarginsAreCollapsible:LineOf<Bool>
    ):LayoutInput {
        final depth = poolDepth;
        poolDepth = depth + 1;
        var input:LayoutInput;
        if (depth < pool.length) {
            input = pool[depth];
        }
        else {
            input = new LayoutInput(runMode, sizingMode, axis, SizeOpt.NONE, knownDimensionsAreDefinite, parentSize, availableSpace, verticalMarginsAreCollapsible);
            pool.push(input);
        }
        var known = SizeOpt.NONE;
        if (knownWidth.isSome() || knownHeight.isSome()) {
            known = input.ownKnown;
            if (known == null) {
                known = new SizeOpt(knownWidth, knownHeight);
                input.ownKnown = known;
            }
            else {
                known.set(knownWidth, knownHeight);
            }
        }
        return input.reset(runMode, sizingMode, axis, known, knownDimensionsAreDefinite, parentSize, availableSpace, verticalMarginsAreCollapsible);
    }

    /** The sizes owned by a pooled input (`acquireParts`), changed in place when it is reused */
    var ownKnown:Null<SizeOpt> = null;
    var ownParent:Null<SizeOpt> = null;
    var ownAvailable:Null<SizeAvail> = null;

    /** Give back the last input taken with `acquire` */
    @:noCompletion
    public static inline function release():Void {
        poolDepth--;
    }

    /** Overwrite every field (inputs reused through `acquire`) */
    inline function reset(
        runMode:RunMode,
        sizingMode:SizingMode,
        axis:RequestedAxis,
        knownDimensions:SizeOpt,
        knownDimensionsAreDefinite:SizeOf<Bool>,
        parentSize:SizeOpt,
        availableSpace:SizeAvail,
        verticalMarginsAreCollapsible:LineOf<Bool>
    ):LayoutInput {
        this.runMode = runMode;
        this.sizingMode = sizingMode;
        this.axis = axis;
        this.knownDimensions = knownDimensions;
        this.knownDimensionsAreDefinite = knownDimensionsAreDefinite;
        this.parentSize = parentSize;
        this.availableSpace = availableSpace;
        this.verticalMarginsAreCollapsible = verticalMarginsAreCollapsible;
        return this;
    }

    /**
     * Swap the horizontal and vertical axes of every per-axis input.
     * `verticalMarginsAreCollapsible` is reset to false as margins cannot collapse across a change of block axis.
     */
    public function transpose():LayoutInput {
        return new LayoutInput(
            runMode,
            sizingMode,
            axis.transpose(),
            knownDimensions.transpose(),
            knownDimensionsAreDefinite.transpose(),
            parentSize.transpose(),
            availableSpace.transpose(),
            new LineOf<Bool>(false, false)
        );
    }

    /** Return a copy with a different run mode */
    public inline function withRunMode(runMode:RunMode):LayoutInput {
        return new LayoutInput(runMode, sizingMode, axis, knownDimensions, knownDimensionsAreDefinite, parentSize, availableSpace, verticalMarginsAreCollapsible);
    }

    /** Return a copy with different known dimensions */
    public inline function withKnownDimensions(knownDimensions:SizeOpt):LayoutInput {
        return new LayoutInput(runMode, sizingMode, axis, knownDimensions, knownDimensionsAreDefinite, parentSize, availableSpace, verticalMarginsAreCollapsible);
    }

    /** Return a copy with a different available space */
    public inline function withAvailableSpace(availableSpace:SizeAvail):LayoutInput {
        return new LayoutInput(runMode, sizingMode, axis, knownDimensions, knownDimensionsAreDefinite, parentSize, availableSpace, verticalMarginsAreCollapsible);
    }

    public function toString():String {
        return 'LayoutInput(runMode: $runMode, sizingMode: $sizingMode, axis: $axis, knownDimensions: $knownDimensions, parentSize: $parentSize, availableSpace: $availableSpace)';
    }

}
