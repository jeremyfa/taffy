// Ported from taffy 0.15.0: src/tree/layout.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

import taffy.geometry.LineOf;
import taffy.geometry.SizeOf;
import taffy.style.AvailableSpace;
import taffy.geometry.SizeOpt;
import taffy.geometry.SizeAvail;

/**
 * A struct containing the inputs constraints/hints for laying out a node, which are passed in by the parent.
 *
 * Immutable (Rust passes it by value).
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
    public final runMode:RunMode;

    /** Whether a Node's style sizes should be taken into account or ignored */
    public final sizingMode:SizingMode;

    /** Which axis we need the size of */
    public final axis:RequestedAxis;

    /**
     * Known dimensions represent dimensions (width/height) which should be taken as fixed when performing layout.
     * Layout functions will be called with both known dimensions set for final layout.
     */
    public final knownDimensions:SizeOpt;

    /**
     * Whether each known dimension should be treated as a *definite* size when laying out the node's
     * own content. Ignored (treated as `true`) for axes where the corresponding known dimension is null.
     */
    public final knownDimensionsAreDefinite:SizeOf<Bool>;

    /** Parent size dimensions are intended to be used for percentage resolution. */
    public final parentSize:SizeOpt;

    /**
     * Available space represents an amount of space to layout into, and is used as a soft constraint
     * for the purpose of wrapping. A definite available space is the space available to the node's border box.
     */
    public final availableSpace:SizeAvail;

    /** Specific to CSS Block layout. Used for correctly computing margin collapsing. */
    public final verticalMarginsAreCollapsible:LineOf<Bool>;

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
