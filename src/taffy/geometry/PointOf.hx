// Ported from taffy 0.15.0: src/geometry.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.geometry;

import taffy.style.FlexDirection;

/**
 * A 2-dimensional coordinate, generic version (`Point<T>` where `T` is not `f32`).
 *
 * Immutable: every operation returns a new instance.
 */
@:structInit
class PointOf<T> {

    /** The x-coordinate */
    public final x:T;

    /** The y-coordinate */
    public final y:T;

    public inline function new(x:T, y:T) {
        this.x = x;
        this.y = y;
    }

    /** Applies the function `f` to both the x and y */
    public inline function map<R>(f:T->R):PointOf<R> {
        return new PointOf<R>(f(x), f(y));
    }

    /** Gets the extent of the specified layout axis */
    public inline function get(axis:AbstractAxis):T {
        return axis == Inline ? x : y;
    }

    /** Return a copy with the given axis set to value */
    public inline function with(axis:AbstractAxis, value:T):PointOf<T> {
        return axis == Inline ? new PointOf<T>(value, y) : new PointOf<T>(x, value);
    }

    public inline function withX(value:T):PointOf<T> {
        return new PointOf<T>(value, y);
    }

    public inline function withY(value:T):PointOf<T> {
        return new PointOf<T>(x, value);
    }

    /** Swap x and y components */
    public inline function transpose():PointOf<T> {
        return new PointOf<T>(y, x);
    }

    /** Gets the component in the main layout axis */
    public inline function main(direction:FlexDirection):T {
        return direction.isRow() ? x : y;
    }

    /** Gets the component in the cross layout axis */
    public inline function cross(direction:FlexDirection):T {
        return direction.isRow() ? y : x;
    }

    public function toString():String {
        return 'Point(x: $x, y: $y)';
    }

}

/**
 * Helpers for `PointOf<Null<Float>>` (Rust `Point<Option<f32>>`).
 */
class OptionPointTools {

    /** A `PointOf<Null<Float>>` with both components set to `null` (Rust `Point::NONE`) */
    public static final NONE:PointOf<Null<Float>> = new PointOf<Null<Float>>(null, null);

}
