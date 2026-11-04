// Ported from taffy 0.15.0: src/compute/flexbox.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.flexbox;

import taffy.geometry.PointOf;
import taffy.geometry.Rect;
import taffy.geometry.RectOf;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.AlignItems;
import taffy.style.Contain;
import taffy.style.Dimension;
import taffy.style.FlexDirection;
import taffy.style.Overflow;
import taffy.tree.NodeId;
import taffy.tree.OofCandidates;
import taffy.geometry.SizeOpt;
import taffy.util.OptionalFloat;

/**
 * The intermediate results of a flexbox calculation for a single item
 */
class FlexItem {

    /** The identifier for the associated node */
    public var node:NodeId;

    /** The order of the node relative to it's siblings */
    public var order:Int;

    /** The base size of this item */
    public var size:SizeOpt;

    /**
     * The raw size style of this item. Used to detect and resolve sizing
     * keywords (`min-content`, `max-content`, `fit-content`, `fit-content(...)`, and `stretch`)
     */
    public var sizeStyle:SizeOf<Dimension>;

    /** The minimum allowable size of this item */
    public var minSize:SizeOpt;

    /** The maximum allowable size of this item */
    public var maxSize:SizeOpt;

    /** The aspect ratio of this item */
    public var aspectRatio:OptionalFloat;

    /** The cross-alignment of this item */
    public var alignSelf:AlignItems;

    /** The overflow style of the item */
    public var overflow:PointOf<Overflow>;

    /** The contain style of the item */
    public var contain:Contain;

    /** The width of the scrollbars (if it has any) */
    public var scrollbarWidth:Float;

    /** The flex shrink style of the item */
    public var flexShrink:Float;

    /** The flex grow style of the item */
    public var flexGrow:Float;

    /** Whether the item's used flex basis is definite (rather than derived from the item's content) */
    public var flexBasisIsDefinite:Bool = false;

    /**
     * The minimum size of the item. This differs from minSize above because it also
     * takes into account content based automatic minimum sizes
     */
    public var resolvedMinimumMainSize:Float = 0.0;

    /**
     * The `position: relative` offset of this item, resolved to (width, height) in the
     * container's coordinate space (zero for non-relative items)
     */
    public var relativeInset:Size;

    /** The margin of this item */
    public var margin:Rect;

    /** Whether each margin is an auto margin or not */
    public var marginIsAuto:RectOf<Bool>;

    /** The padding of this item */
    public var padding:Rect;

    /** The border of this item */
    public var border:Rect;

    /** The default size of this item */
    public var flexBasis:Float = 0.0;

    /** The default size of this item, minus padding and border */
    public var innerFlexBasis:Float = 0.0;

    /** The amount by which this item has deviated from its target size */
    public var violation:Float = 0.0;

    /** Is the size of this item locked */
    public var frozen:Bool = false;

    /**
     * Either the max- or min- content flex fraction
     * See https://www.w3.org/TR/css-flexbox-1/#intrinsic-main-sizes
     */
    public var contentFlexFraction:Float = 0.0;

    /** The proposed inner size of this item */
    public final hypotheticalInnerSize:FlexItemSize = new FlexItemSize();

    /** The proposed outer size of this item */
    public final hypotheticalOuterSize:FlexItemSize = new FlexItemSize();

    /** The size that this item wants to be */
    public final targetSize:FlexItemSize = new FlexItemSize();

    /** The size that this item wants to be, plus any padding and border */
    public final outerTargetSize:FlexItemSize = new FlexItemSize();

    /** The position of the bottom edge of this item */
    public var baseline:Float = 0.0;

    /**
     * A temporary value for the main offset
     *
     * Offset is the relative position from the item's natural flow position based on
     * relative position values, alignment, and justification. Does not include margin/padding/border.
     */
    public var offsetMain:Float = 0.0;

    /**
     * A temporary value for the cross offset
     *
     * Offset is the relative position from the item's natural flow position based on
     * relative position values, alignment, and justification. Does not include margin/padding/border.
     */
    public var offsetCross:Float = 0.0;

    /**
     * Out-of-flow candidates bubbled out of this item's subtree. Anchors are relative to the
     * container's border box (translated when the item's final layout is computed).
     */
    public var oofCandidates:OofCandidates;

    /** An item to initialize with `reset` (items are reused between layout calls) */
    public function new() {}

    /** Initialize every field, as a newly created item */
    /** Sizes owned by this pooled item, set again each time it is reused (see `ownedSize`) */
    final ownSize:SizeOpt = new SizeOpt(OptionalFloat.NONE, OptionalFloat.NONE);
    final ownMinSize:SizeOpt = new SizeOpt(OptionalFloat.NONE, OptionalFloat.NONE);
    final ownMaxSize:SizeOpt = new SizeOpt(OptionalFloat.NONE, OptionalFloat.NONE);

    /**
     * `SizeOpt.shared(width, height)` without allocating: the shared `NONE` when both are absent,
     * otherwise `own` set to the values (`own` is one of this item's own sizes)
     */
    static inline function ownedOrNone(own:SizeOpt, width:OptionalFloat, height:OptionalFloat):SizeOpt {
        if (width.isNone() && height.isNone())
            return SizeOpt.NONE;
        own.set(width, height);
        return own;
    }

    /** The item's own size for `reset` (`kind` 0: size, 1: min size, 2: max size) */
    public inline function ownedSize(kind:Int, width:OptionalFloat, height:OptionalFloat):SizeOpt {
        return ownedOrNone(kind == 0 ? ownSize : (kind == 1 ? ownMinSize : ownMaxSize), width, height);
    }

    public function reset(
        node:NodeId,
        order:Int,
        size:SizeOpt,
        sizeStyle:SizeOf<Dimension>,
        minSize:SizeOpt,
        maxSize:SizeOpt,
        aspectRatio:OptionalFloat,
        relativeInset:Size,
        margin:Rect,
        marginIsAuto:RectOf<Bool>,
        padding:Rect,
        border:Rect,
        alignSelf:AlignItems,
        overflow:PointOf<Overflow>,
        contain:Contain,
        scrollbarWidth:Float,
        flexGrow:Float,
        flexShrink:Float
    ):FlexItem {
        this.node = node;
        this.order = order;
        this.size = size;
        this.sizeStyle = sizeStyle;
        this.minSize = minSize;
        this.maxSize = maxSize;
        this.aspectRatio = aspectRatio;
        this.relativeInset = relativeInset;
        this.margin = margin;
        this.marginIsAuto = marginIsAuto;
        this.padding = padding;
        this.border = border;
        this.alignSelf = alignSelf;
        this.overflow = overflow;
        this.contain = contain;
        this.scrollbarWidth = scrollbarWidth;
        this.flexGrow = flexGrow;
        this.flexShrink = flexShrink;
        this.oofCandidates = OofCandidates.EMPTY;
        // The algorithm's state, as in a new item
        this.flexBasisIsDefinite = false;
        this.resolvedMinimumMainSize = 0.0;
        this.flexBasis = 0.0;
        this.innerFlexBasis = 0.0;
        this.violation = 0.0;
        this.frozen = false;
        this.contentFlexFraction = 0.0;
        this.hypotheticalInnerSize.clear();
        this.hypotheticalOuterSize.clear();
        this.targetSize.clear();
        this.outerTargetSize.clear();
        this.baseline = 0.0;
        this.offsetMain = 0.0;
        this.offsetCross = 0.0;
        return this;
    }

    /** Returns true if the item is a https://www.w3.org/TR/css-overflow-3/#scroll-container */
    public inline function isScrollContainer():Bool {
        return overflow.x.isScrollContainer() || overflow.y.isScrollContainer();
    }

    /**
     * Returns true if the item participates in baseline alignment: it has `align-self: baseline`
     * and neither of its cross-axis margins are `auto`.
     * See https://www.w3.org/TR/css-flexbox-1/#baseline-participation
     */
    public inline function participatesInBaselineAlignment(dir:FlexDirection):Bool {
        return alignSelf == AlignItems.BASELINE && !marginIsAuto.crossStart(dir) && !marginIsAuto.crossEnd(dir);
    }

}
