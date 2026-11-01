// Ported from taffy 0.15.0: src/tree/layout.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

import taffy.geometry.Point;
import taffy.geometry.Rect;
import taffy.geometry.Size;
import taffy.util.Sys;

/**
 * The final result of a layout algorithm for a single node.
 *
 * Immutable.
 */
@:structInit
class Layout {

    /** A zero layout with order 0 */
    public static final ZERO:Layout = new Layout(0, Point.ZERO, Size.ZERO, Rect.ZERO, Size.ZERO, Rect.ZERO, Rect.ZERO, Rect.ZERO);

    /** The relative ordering of the node. Nodes with a higher order should be rendered on top of those with a lower order. */
    public final order:Int;

    /** The top-left corner of the node */
    public final location:Point;

    /** The width and height of the node */
    public final size:Size;

    /**
     * The scrollable overflow rectangle of the node, measured from the node's scroll origin
     * (the top-left corner of the padding box in LTR, the top-right corner in RTL).
     */
    public final scrollableOverflowRect:Rect;

    /** The size of the scrollbars in each dimension. If there is no scrollbar then the size will be zero. */
    public final scrollbarSize:Size;

    /** The size of the borders of the node */
    public final border:Rect;

    /** The size of the padding of the node */
    public final padding:Rect;

    /** The size of the margin of the node */
    public final margin:Rect;

    public inline function new(order:Int, location:Point, size:Size, scrollableOverflowRect:Rect, scrollbarSize:Size, border:Rect, padding:Rect, margin:Rect) {
        this.order = order;
        this.location = location;
        this.size = size;
        this.scrollableOverflowRect = scrollableOverflowRect;
        this.scrollbarSize = scrollbarSize;
        this.border = border;
        this.padding = padding;
        this.margin = margin;
    }

    /** Creates a new zero `Layout` with the supplied `order` value */
    public static inline function withOrder(order:Int):Layout {
        return new Layout(order, Point.ZERO, Size.ZERO, Rect.ZERO, Size.ZERO, Rect.ZERO, Rect.ZERO, Rect.ZERO);
    }

    /** Return a copy with a different location */
    public inline function withLocation(location:Point):Layout {
        return new Layout(order, location, size, scrollableOverflowRect, scrollbarSize, border, padding, margin);
    }

    /** Get the width of the node's content box */
    public inline function contentBoxWidth():Float {
        return size.width - padding.left - padding.right - border.left - border.right;
    }

    /** Get the height of the node's content box */
    public inline function contentBoxHeight():Float {
        return size.height - padding.top - padding.bottom - border.top - border.bottom;
    }

    /** Get the size of the node's content box */
    public inline function contentBoxSize():Size {
        return new Size(contentBoxWidth(), contentBoxHeight());
    }

    /** Get x offset of the node's content box relative to it's parent's border box */
    public inline function contentBoxX():Float {
        return location.x + border.left + padding.left;
    }

    /** Get y offset of the node's content box relative to it's parent's border box */
    public inline function contentBoxY():Float {
        return location.y + border.top + padding.top;
    }

    /** Return the maximum horizontal scroll offset of the node */
    public function scrollWidth():Float {
        return Sys.f32Max(0.0, scrollableOverflowRect.right + Sys.f32Min(scrollbarSize.width, size.width) - size.width + border.left + border.right);
    }

    /** Return the maximum vertical scroll offset of the node */
    public function scrollHeight():Float {
        return Sys.f32Max(0.0, scrollableOverflowRect.bottom + Sys.f32Min(scrollbarSize.height, size.height) - size.height + border.top + border.bottom);
    }

    public function toString():String {
        return 'Layout(order: $order, location: $location, size: $size)';
    }

}
