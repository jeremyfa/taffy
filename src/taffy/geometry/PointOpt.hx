// Ported from taffy 0.15.0: src/geometry.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.geometry;

import taffy.style.FlexDirection;
import taffy.util.OptionalFloat;

/**
 * A 2-dimensional coordinate whose components are optional (Rust `Point<Option<f32>>`).
 *
 * The fields are `OptionalFloat`, a plain float, so nothing is boxed.
 *
 * Immutable: every operation returns a new instance.
 */
@:structInit
class PointOpt {

    /** Both components absent (Rust `Point::NONE`) */
    public static final NONE:PointOpt = new PointOpt(OptionalFloat.NONE, OptionalFloat.NONE);

    /** The x-coordinate */
    public final x:OptionalFloat;

    /** The y-coordinate */
    public final y:OptionalFloat;

    public inline function new(x:OptionalFloat, y:OptionalFloat) {
        #if taffy_census
        taffy.util.Census.optional(x, 'PointOpt.new');
        taffy.util.Census.optional(y, 'PointOpt.new');
        #end
        this.x = x;
        this.y = y;
    }

    /** Applies the function `f` to both the x and y */
    public inline function map(f:OptionalFloat->OptionalFloat):PointOpt {
        return new PointOpt(f(x), f(y));
    }

    /** Gets the extent of the specified layout axis */
    public inline function get(axis:AbstractAxis):OptionalFloat {
        return axis == Inline ? x : y;
    }

    /** Return a copy with the given axis set to value */
    public inline function with(axis:AbstractAxis, value:OptionalFloat):PointOpt {
        final inl = axis == Inline;
        return new PointOpt(inl ? value : x, inl ? y : value);
    }

    public inline function withX(value:OptionalFloat):PointOpt {
        return new PointOpt(value, y);
    }

    public inline function withY(value:OptionalFloat):PointOpt {
        return new PointOpt(x, value);
    }

    /** Swap x and y components */
    public inline function transpose():PointOpt {
        return new PointOpt(y, x);
    }

    /** Gets the component in the main layout axis */
    public inline function main(direction:FlexDirection):OptionalFloat {
        return direction.isRow() ? x : y;
    }

    /** Gets the component in the cross layout axis */
    public inline function cross(direction:FlexDirection):OptionalFloat {
        return direction.isRow() ? y : x;
    }

    public inline function equals(other:PointOpt):Bool {
        return x == other.x && y == other.y;
    }

    public function toString():String {
        return 'Point(x: $x, y: $y)';
    }

}
