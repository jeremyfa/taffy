// Ported from taffy 0.15.0: src/geometry.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.geometry;

import taffy.style.FlexDirection;
import taffy.util.OptionalFloat;

/**
 * An axis-aligned UI rectangle whose sides are optional (Rust `Rect<Option<f32>>`).
 *
 * The fields are `OptionalFloat`, a plain float, so nothing is boxed.
 *
 * Immutable: every operation returns a new instance.
 */
@:structInit
class RectOpt {

    /** All sides absent (Rust `Rect::NONE`) */
    public static final NONE:RectOpt = new RectOpt(OptionalFloat.NONE, OptionalFloat.NONE, OptionalFloat.NONE, OptionalFloat.NONE);

    /** The starting (left) side */
    public final left:OptionalFloat;

    /** The ending (right) side */
    public final right:OptionalFloat;

    /** The top side */
    public final top:OptionalFloat;

    /** The bottom side */
    public final bottom:OptionalFloat;

    public inline function new(left:OptionalFloat, right:OptionalFloat, top:OptionalFloat, bottom:OptionalFloat) {
        #if taffy_census
        taffy.util.Census.optional(left, 'RectOpt.new');
        taffy.util.Census.optional(right, 'RectOpt.new');
        taffy.util.Census.optional(top, 'RectOpt.new');
        taffy.util.Census.optional(bottom, 'RectOpt.new');
        #end
        this.left = left;
        this.right = right;
        this.top = top;
        this.bottom = bottom;
    }

    /** Applies the function `f` to all four sides of the rect */
    public inline function map(f:(OptionalFloat) -> OptionalFloat):RectOpt {
        return new RectOpt(f(left), f(right), f(top), f(bottom));
    }

    /** Swap the horizontal and vertical components */
    public inline function transpose():RectOpt {
        return new RectOpt(top, bottom, left, right);
    }

    /** The `start` or `top` value of the rect, depending on the direction */
    public inline function mainStart(direction:FlexDirection):OptionalFloat {
        return direction.isRow() ? left : top;
    }

    /** The `end` or `bottom` value of the rect, depending on the direction */
    public inline function mainEnd(direction:FlexDirection):OptionalFloat {
        return direction.isRow() ? right : bottom;
    }

    /** The `top` or `start` value of the rect, depending on the direction */
    public inline function crossStart(direction:FlexDirection):OptionalFloat {
        return direction.isRow() ? top : left;
    }

    /** The `bottom` or `end` value of the rect, depending on the direction */
    public inline function crossEnd(direction:FlexDirection):OptionalFloat {
        return direction.isRow() ? bottom : right;
    }

    public inline function withLeft(value:OptionalFloat):RectOpt {
        return new RectOpt(value, right, top, bottom);
    }

    public inline function withRight(value:OptionalFloat):RectOpt {
        return new RectOpt(left, value, top, bottom);
    }

    public inline function withTop(value:OptionalFloat):RectOpt {
        return new RectOpt(left, right, value, bottom);
    }

    public inline function withBottom(value:OptionalFloat):RectOpt {
        return new RectOpt(left, right, top, value);
    }

    /** Replace absent sides with `alt` */
    public inline function unwrapOr(alt:Float):Rect {
        return new Rect(left.unwrapOr(alt), right.unwrapOr(alt), top.unwrapOr(alt), bottom.unwrapOr(alt));
    }

    public inline function equals(other:RectOpt):Bool {
        return left == other.left && right == other.right && top == other.top && bottom == other.bottom;
    }

    public function toString():String {
        return 'Rect(left: $left, right: $right, top: $top, bottom: $bottom)';
    }

}
