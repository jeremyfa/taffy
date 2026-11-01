// Ported from taffy 0.15.0: src/geometry.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.geometry;

import taffy.style.FlexDirection;

/**
 * A 2-dimensional coordinate (concrete `Point<f32>`).
 *
 * Immutable: every operation returns a new instance.
 */
@:structInit
class Point {

    /** A `Point` with values (0,0), representing the origin */
    public static final ZERO:Point = new Point(0.0, 0.0);

    /** The x-coordinate */
    public final x:Float;

    /** The y-coordinate */
    public final y:Float;

    public inline function new(x:Float, y:Float) {
        this.x = x;
        this.y = y;
    }

    public inline function add(rhs:Point):Point {
        return new Point(x + rhs.x, y + rhs.y);
    }

    public inline function sub(rhs:Point):Point {
        return new Point(x - rhs.x, y - rhs.y);
    }

    public inline function map(f:Float->Float):Point {
        return new Point(f(x), f(y));
    }

    /** Gets the extent of the specified layout axis */
    public inline function get(axis:AbstractAxis):Float {
        return axis == Inline ? x : y;
    }

    /** Return a copy with the given axis set to value */
    public inline function with(axis:AbstractAxis, value:Float):Point {
        return axis == Inline ? new Point(value, y) : new Point(x, value);
    }

    public inline function withX(value:Float):Point {
        return new Point(value, y);
    }

    public inline function withY(value:Float):Point {
        return new Point(x, value);
    }

    /** Swap x and y components */
    public inline function transpose():Point {
        return new Point(y, x);
    }

    /** Gets the component in the main layout axis */
    public inline function main(direction:FlexDirection):Float {
        return direction.isRow() ? x : y;
    }

    /** Gets the component in the cross layout axis */
    public inline function cross(direction:FlexDirection):Float {
        return direction.isRow() ? y : x;
    }

    /** Convert into a `Size` (x becomes width, y becomes height) */
    public inline function toSize():Size {
        return new Size(x, y);
    }

    public inline function equals(other:Point):Bool {
        return x == other.x && y == other.y;
    }

    public function toString():String {
        return 'Point(x: $x, y: $y)';
    }

}
