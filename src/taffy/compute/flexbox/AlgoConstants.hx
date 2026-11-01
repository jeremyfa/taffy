// Ported from taffy 0.15.0: src/compute/flexbox.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.flexbox;

import taffy.geometry.Point;
import taffy.geometry.Rect;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.AlignContent;
import taffy.style.AlignItems;
import taffy.style.Direction;
import taffy.style.FlexDirection;
import taffy.geometry.SizeOpt;

/**
 * Values that can be cached during the flexbox algorithm
 */
class AlgoConstants {

    /** The direction of the current segment being laid out */
    public var dir:FlexDirection;

    /** The layout direction of the current segment being laid out */
    public var layoutDirection:Direction;

    /** Is this segment a row */
    public var isRow:Bool;

    /** Is this segment a column */
    public var isColumn:Bool;

    /** Is wrapping enabled (in either direction) */
    public var isWrap:Bool;

    /** Is the wrap direction inverted */
    public var isWrapReverse:Bool;

    /** Are items balanced across lines (`flex-wrap: balance`)? */
    public var isBalance:Bool;

    /**
     * The requested minimum number of lines (`flex-line-count`). Set for every
     * multi-line container, null for `nowrap`.
     */
    public var lineCount:Null<Int>;

    /** The item's min_size style */
    public var minSize:SizeOpt;

    /** The item's max_size style */
    public var maxSize:SizeOpt;

    /** The border of this section */
    public var border:Rect;

    /**
     * The space between the content box and the border box.
     * This consists of padding + border + scrollbar_gutter.
     */
    public var contentBoxInset:Rect;

    /** The size reserved for scrollbar gutters in each axis */
    public var scrollbarGutter:Point;

    /** Whether the node being laid out is a scroll container */
    public var isScrollContainer:Bool;

    /** The gap of this section */
    public var gap:Size;

    /** The align_items property of this node */
    public var alignItems:AlignItems;

    /** The align_content property of this node */
    public var alignContent:AlignContent;

    /** The justify_content property of this node */
    public var justifyContent:AlignContent;

    /** The border-box size of the node being laid out (if known) */
    public var nodeOuterSize:SizeOpt;

    /** The content-box size of the node being laid out (if known) */
    public var nodeInnerSize:SizeOpt;

    /**
     * Whether the known main size of the node (if any) is definite. This is `false` when a parent
     * imposes a main size on this node that is derived from the node's own content, in which case
     * it is indefinite for the purposes of resolving percentage sizes of items and collecting items
     * into flex lines. See https://www.w3.org/TR/css-flexbox-1/#definite-sizes.
     */
    public var knownMainSizeIsDefinite:Bool;

    /**
     * Whether the node has a known main size which is definite (as of the start of layout,
     * before the main size is determined from the node's contents)
     */
    public var hasDefiniteMainSize:Bool;

    /** Whether the node has a known cross size which is definite */
    public var hasDefiniteCrossSize:Bool;

    /**
     * Whether the cross-axis space that non-stretched items are fit-content sized into is
     * definite (either the node's cross size is definite, or the cross-axis available space is).
     * A size resolved by fit-content sizing against definite available space is itself definite
     * (see https://www.w3.org/TR/css-sizing-3/#definite).
     */
    public var crossAxisAvailableSpaceIsDefinite:Bool;

    /** The size of the virtual container containing the flex items. */
    public var containerSize:Size;

    /** The size of the internal container */
    public var innerContainerSize:Size;

    public function new() {}

    /**
     * When a multi-line container requests a minimum number of lines (`flex-line-count`),
     * definite cross-axis available space for measuring items is divided between the requested
     * number of lines (after subtracting the cross-axis gaps between them).
     * See https://github.com/w3c/csswg-drafts/issues/13414
     */
    public inline function dividedCrossSpace(crossAvailableSpace:Float):Float {
        final lc = lineCount;
        if (lc != null && (lc : Int) > 1) {
            final lineCount:Float = (lc : Int);
            return (crossAvailableSpace - (lineCount - 1.0) * gap.cross(dir)) / lineCount;
        }
        return crossAvailableSpace;
    }

}
