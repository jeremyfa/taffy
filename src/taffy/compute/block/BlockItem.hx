// Ported from taffy 0.15.0: src/compute/block.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.block;

import taffy.geometry.Point;
import taffy.geometry.PointOf;
import taffy.geometry.Rect;
import taffy.geometry.RectOf;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.AlignItems;
import taffy.style.Clear;
import taffy.style.Contain;
import taffy.style.CssFloat;
import taffy.style.Dimension;
import taffy.style.Direction;
import taffy.style.LengthPercentageAuto;
import taffy.style.Overflow;
import taffy.style.Position;
import taffy.tree.Layout;
import taffy.tree.NodeId;
import taffy.tree.OofCandidates;
import taffy.geometry.SizeOpt;

/**
 * Per-child data that is accumulated and modified over the course of the block layout algorithm
 */
class BlockItem {

    /** The identifier for the associated node */
    public var nodeId:NodeId;

    /** The "source order" of the item */
    public var order:Int;

    /** Items that are tables don't have stretch sizing applied to them */
    public var isTable:Bool;

    /** Compressible replaced items resolve an auto width to their intrinsic size rather than being stretch-sized */
    public var isCompressibleReplaced:Bool;

    /** Whether the child is a non-independent block or inline node */
    public var isInSameBfc:Bool;

    /** The `float` style of the node */
    public var float:CssFloat;

    /** The `clear` style of the node */
    public var clear:Clear;

    /** The size style of this item. Used to detect and resolve sizing keywords */
    public var sizeStyle:SizeOf<Dimension>;

    /** The base size of this item */
    public var size:SizeOpt;

    /** The minimum allowable size of this item */
    public var minSize:SizeOpt;

    /** The maximum allowable size of this item */
    public var maxSize:SizeOpt;

    /** The overflow style of the item */
    public var overflow:PointOf<Overflow>;

    /** The contain style of the item */
    public var contain:Contain;

    /** The width of the item's scrollbars (if it has scrollbars) */
    public var scrollbarWidth:Float;

    /** The position style of the item */
    public var position:Position;

    /** The `direction` style of the item (used to resolve `self-start`/`self-end`) */
    public var direction:Direction;

    /** The `align-self` style of the item */
    public var alignSelf:Null<AlignItems>;

    /** The `justify-self` style of the item */
    public var justifySelf:Null<AlignItems>;

    /** The inset of this item */
    public var inset:RectOf<LengthPercentageAuto>;

    /** The margin of this item */
    public var margin:RectOf<LengthPercentageAuto>;

    /** The padding of this item */
    public var padding:Rect;

    /** The border of this item */
    public var border:Rect;

    /** The sum of padding and border for this item */
    public var paddingBorderSum:Size;

    /** The computed border box size of this item */
    public var computedSize:Size = Size.ZERO;

    /**
     * The y coordinate of the computed "static position" of this item (the only coordinate that is
     * read: the static position rectangle of an out-of-flow item spans the content box horizontally)
     */
    public var staticY:Float = 0.0;

    /** Whether margins can be collapsed through this item */
    public var canBeCollapsedThrough:Bool = false;

    /** Pending layout for in-flow items, committed after the `align-content` pass */
    public var finalLayout:Null<Layout> = null;

    /** Out-of-flow candidates bubbled out of this (in-flow) item's subtree */
    public var oofCandidates:OofCandidates = OofCandidates.EMPTY;

    public function new() {}

    /** Reset the fields that `BlockLayout.generateItemList` does not set (items are reused between layout calls) */
    public inline function resetState():Void {
        computedSize = Size.ZERO;
        staticY = 0.0;
        canBeCollapsedThrough = false;
        finalLayout = null;
        oofCandidates = OofCandidates.EMPTY;
    }

}
