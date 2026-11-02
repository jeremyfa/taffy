// Ported from taffy 0.15.0: src/tree/layout.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

import taffy.geometry.Rect;
import taffy.geometry.Size;
import taffy.geometry.Point;

/**
 * A struct containing the result of laying a single node, which is returned up to the parent node.
 *
 * Mutable (layout algorithms update it in place); `clone()` before storing it elsewhere.
 */
@:structInit
class LayoutOutput {

    /** The size of the node */
    public var size:Size;

    /** The scrollable overflow rectangle of the node's content */
    public var scrollableOverflowRect:Rect;

    /** The first and last baselines of the node in the horizontal axis, if any */
    public var baselines:Baselines;

    /** Top margin that can be collapsed with (CSS block layout) */
    public var topMargin:CollapsibleMarginSet;

    /** Bottom margin that can be collapsed with (CSS block layout) */
    public var bottomMargin:CollapsibleMarginSet;

    /** Whether margins can be collapsed through this node (CSS block layout) */
    public var marginsCanCollapseThrough:Bool;

    /**
     * Out-of-flow (absolute/fixed) descendants of this node for which this node is *not* the
     * containing block. These bubble up the tree until they reach their containing block.
     */
    public var oofCandidates:OofCandidates;

    /** The node's inset-resolution area for out-of-flow boxes (null for leaves and size-only runs) */
    public var oofPositioningArea:Null<OofPositioningArea>;

    public inline function new(
        size:Size,
        scrollableOverflowRect:Rect,
        baselines:Baselines,
        topMargin:CollapsibleMarginSet,
        bottomMargin:CollapsibleMarginSet,
        marginsCanCollapseThrough:Bool,
        ?oofCandidates:OofCandidates,
        ?oofPositioningArea:OofPositioningArea
    ) {
        this.size = size;
        this.scrollableOverflowRect = scrollableOverflowRect;
        this.baselines = baselines;
        this.topMargin = topMargin;
        this.bottomMargin = bottomMargin;
        this.marginsCanCollapseThrough = marginsCanCollapseThrough;
        this.oofCandidates = oofCandidates != null ? oofCandidates : OofCandidates.EMPTY;
        this.oofPositioningArea = oofPositioningArea;
    }

    /** An all-zero `LayoutOutput` for hidden nodes (a new instance) */
    public static inline function hidden():LayoutOutput {
        return new LayoutOutput(Size.ZERO, Rect.ZERO, Baselines.NONE, CollapsibleMarginSet.ZERO, CollapsibleMarginSet.ZERO, false);
    }

    /** Construct a `LayoutOutput` from just the size, scrollable overflow rectangle and baselines */
    public static inline function fromSizesAndBaselines(size:Size, scrollableOverflowRect:Rect, baselines:Baselines):LayoutOutput {
        return new LayoutOutput(size, scrollableOverflowRect, baselines, CollapsibleMarginSet.ZERO, CollapsibleMarginSet.ZERO, false);
    }

    /** Construct a `LayoutOutput` from just the container size and scrollable overflow rectangle */
    public static inline function fromSizes(size:Size, scrollableOverflowRect:Rect):LayoutOutput {
        return fromSizesAndBaselines(size, scrollableOverflowRect, Baselines.NONE);
    }

    /** Construct a `LayoutOutput` from just the container's size */
    public static inline function fromOuterSize(size:Size):LayoutOutput {
        return fromSizes(size, Rect.ZERO);
    }

    /**
     * Swap the horizontal and vertical axes of the output (inverse of `LayoutInput.transpose()`).
     * Baselines and collapsible margins are dropped. Out-of-flow candidates are unaffected.
     */
    public function transpose():LayoutOutput {
        final area = oofPositioningArea;
        return new LayoutOutput(
            size.transpose(),
            scrollableOverflowRect.transpose(),
            Baselines.NONE,
            CollapsibleMarginSet.ZERO,
            CollapsibleMarginSet.ZERO,
            false,
            oofCandidates,
            area != null ? new OofPositioningArea(area.size.transpose(), area.offset.transpose()) : null
        );
    }

    /** Create a copy (the candidate list is copied too) */
    public function clone():LayoutOutput {
        return new LayoutOutput(size, scrollableOverflowRect, baselines, topMargin, bottomMargin, marginsCanCollapseThrough, oofCandidates.clone(), oofPositioningArea);
    }

}
