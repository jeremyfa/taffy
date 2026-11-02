// Ported from taffy 0.15.0: src/geometry.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.geometry;

import taffy.style.FlexDirection;

/**
 * An axis-aligned UI rectangle, generic version (`Rect<T>` where `T` is not `f32`).
 *
 * Immutable: every operation returns a new instance.
 */
@:structInit
@:generic
class RectOf<T> {

    /** The starting (left) side */
    public final left:T;

    /** The ending (right) side */
    public final right:T;

    /** The top side */
    public final top:T;

    /** The bottom side */
    public final bottom:T;

    public inline function new(left:T, right:T, top:T, bottom:T) {
        #if taffy_census
        taffy.util.Census.any(left, 'RectOf.new');
        taffy.util.Census.any(right, 'RectOf.new');
        taffy.util.Census.any(top, 'RectOf.new');
        taffy.util.Census.any(bottom, 'RectOf.new');
        #end
        this.left = left;
        this.right = right;
        this.top = top;
        this.bottom = bottom;
    }

    /** Applies the function `f` to all four sides of the rect */
    public inline function map<R>(f:T->R):RectOf<R> {
        return new RectOf<R>(f(left), f(right), f(top), f(bottom));
    }

    /** Applies `f` to each side with the matching component of `size` (width for left/right, height for top/bottom) */
    public inline function zipSize<U, R>(size:SizeOf<U>, f:T->U->R):RectOf<R> {
        return new RectOf<R>(f(left, size.width), f(right, size.width), f(top, size.height), f(bottom, size.height));
    }

    /** Swap the horizontal and vertical components */
    public inline function transpose():RectOf<T> {
        return new RectOf<T>(top, bottom, left, right);
    }

    /** Returns a `LineOf` representing the left and right properties */
    public inline function horizontalComponents():LineOf<T> {
        return new LineOf<T>(left, right);
    }

    /** Returns a `LineOf` containing the top and bottom properties */
    public inline function verticalComponents():LineOf<T> {
        return new LineOf<T>(top, bottom);
    }

    /** The `start` or `top` value of the rect, depending on the direction */
    public inline function mainStart(direction:FlexDirection):T {
        return direction.isRow() ? left : top;
    }

    /** The `end` or `bottom` value of the rect, depending on the direction */
    public inline function mainEnd(direction:FlexDirection):T {
        return direction.isRow() ? right : bottom;
    }

    /** The `top` or `start` value of the rect, depending on the direction */
    public inline function crossStart(direction:FlexDirection):T {
        return direction.isRow() ? top : left;
    }

    /** The `bottom` or `end` value of the rect, depending on the direction */
    public inline function crossEnd(direction:FlexDirection):T {
        return direction.isRow() ? bottom : right;
    }

    public inline function withLeft(value:T):RectOf<T> {
        return new RectOf<T>(value, right, top, bottom);
    }

    public inline function withRight(value:T):RectOf<T> {
        return new RectOf<T>(left, value, top, bottom);
    }

    public inline function withTop(value:T):RectOf<T> {
        return new RectOf<T>(left, right, value, bottom);
    }

    public inline function withBottom(value:T):RectOf<T> {
        return new RectOf<T>(left, right, top, value);
    }

    public function toString():String {
        return 'Rect(left: $left, right: $right, top: $top, bottom: $bottom)';
    }

}
