// Ported from taffy 0.15.0: src/geometry.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.geometry;

import taffy.style.FlexDirection;
import taffy.util.OptionalFloat;
import taffy.util.Sys;

/**
 * An axis-aligned UI rectangle (concrete `Rect<f32>`).
 *
 * Immutable: every operation returns a new instance.
 */
@:structInit
class Rect {

    /** A `Rect` with all sides set to zero */
    public static final ZERO:Rect = new Rect(0.0, 0.0, 0.0, 0.0);

    /** This can represent either the x-coordinate of the starting edge, or the amount of padding on the starting side. */
    public final left:Float;

    /** This can represent either the x-coordinate of the ending edge, or the amount of padding on the ending side. */
    public final right:Float;

    /** This can represent either the y-coordinate of the top edge, or the amount of padding on the top side. */
    public final top:Float;

    /** This can represent either the y-coordinate of the bottom edge, or the amount of padding on the bottom side. */
    public final bottom:Float;

    public inline function new(left:Float, right:Float, top:Float, bottom:Float) {
        #if taffy_census
        taffy.util.Census.conc(left);
        taffy.util.Census.conc(right);
        taffy.util.Census.conc(top);
        taffy.util.Census.conc(bottom);
        #end
        this.left = left;
        this.right = right;
        this.top = top;
        this.bottom = bottom;
    }

    public inline function add(rhs:Rect):Rect {
        return new Rect(left + rhs.left, right + rhs.right, top + rhs.top, bottom + rhs.bottom);
    }

    public inline function map(f:Float->Float):Rect {
        return new Rect(f(left), f(right), f(top), f(bottom));
    }

    /** Swap the horizontal and vertical components (left with top, right with bottom) */
    public inline function transpose():Rect {
        return new Rect(top, bottom, left, right);
    }

    /** Returns a `Line` representing the left and right properties */
    public inline function horizontalComponents():Line {
        return new Line(left, right);
    }

    /** Returns a `Line` containing the top and bottom properties */
    public inline function verticalComponents():Line {
        return new Line(top, bottom);
    }

    /** The sum of `left` and `right` */
    public inline function horizontalAxisSum():Float {
        return left + right;
    }

    /** The sum of `top` and `bottom` */
    public inline function verticalAxisSum():Float {
        return top + bottom;
    }

    /** Both horizontal and vertical sums as a `Size` */
    public inline function sumAxes():Size {
        return new Size(left + right, top + bottom);
    }

    /** Get either the horizontal or vertical sum depending on the `AbsoluteAxis` passed in */
    public inline function gridAxisSum(axis:AbsoluteAxis):Float {
        return axis == Horizontal ? left + right : top + bottom;
    }

    /** The sum of the two fields of the rect representing the main axis */
    public inline function mainAxisSum(direction:FlexDirection):Float {
        return direction.isRow() ? left + right : top + bottom;
    }

    /** The sum of the two fields of the rect representing the cross axis */
    public inline function crossAxisSum(direction:FlexDirection):Float {
        return direction.isRow() ? top + bottom : left + right;
    }

    /** The `start` or `top` value of the rect, depending on the direction */
    public inline function mainStart(direction:FlexDirection):Float {
        return direction.isRow() ? left : top;
    }

    /** The `end` or `bottom` value of the rect, depending on the direction */
    public inline function mainEnd(direction:FlexDirection):Float {
        return direction.isRow() ? right : bottom;
    }

    /** The `top` or `start` value of the rect, depending on the direction */
    public inline function crossStart(direction:FlexDirection):Float {
        return direction.isRow() ? top : left;
    }

    /** The `bottom` or `end` value of the rect, depending on the direction */
    public inline function crossEnd(direction:FlexDirection):Float {
        return direction.isRow() ? bottom : right;
    }

    public inline function withLeft(value:Float):Rect {
        return new Rect(value, right, top, bottom);
    }

    public inline function withRight(value:Float):Rect {
        return new Rect(left, value, top, bottom);
    }

    public inline function withTop(value:Float):Rect {
        return new Rect(left, right, value, bottom);
    }

    public inline function withBottom(value:Float):Rect {
        return new Rect(left, right, top, value);
    }

    /** Get the union of this rect and another (smallest rect that contains both) */
    public inline function union(other:Rect):Rect {
        return new Rect(Sys.f32Min(left, other.left), Sys.f32Max(right, other.right), Sys.f32Min(top, other.top), Sys.f32Max(bottom, other.bottom));
    }

    /** Convert to a `RectOpt` with all sides set */
    public inline function toOptions():RectOpt {
        return new RectOpt(OptionalFloat.some(left), OptionalFloat.some(right), OptionalFloat.some(top), OptionalFloat.some(bottom));
    }

    public inline function equals(other:Rect):Bool {
        return left == other.left && right == other.right && top == other.top && bottom == other.bottom;
    }

    public function toString():String {
        return 'Rect(left: $left, right: $right, top: $top, bottom: $bottom)';
    }

}
