// Ported from taffy 0.15.0: src/geometry.rs, src/util/math.rs, src/style/available_space.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.geometry;

import taffy.style.AvailableSpace;
import taffy.style.FlexDirection;
import taffy.util.MaybeMath;
import taffy.util.OptionalFloat;

using taffy.style.AvailableSpace;

/**
 * The width and height of a rectangle, generic version (`Size<T>` where `T` is not `f32`).
 *
 * Used as `SizeOf<Dimension>`, `SizeOf<Bool>`... Rust `Size<Option<f32>>` and
 * `Size<AvailableSpace>` are the concrete `SizeOpt` and `SizeAvail` (unboxed fields).
 *
 * Immutable: every operation returns a new instance.
 */
@:structInit
@:generic
class SizeOf<T> {

    /** The x extent of the rectangle */
    public final width:T;

    /** The y extent of the rectangle */
    public final height:T;

    public inline function new(width:T, height:T) {
        #if taffy_census
        taffy.util.Census.any(width, 'SizeOf.new');
        taffy.util.Census.any(height, 'SizeOf.new');
        #end
        this.width = width;
        this.height = height;
    }

    /** Get either the width or height depending on the `AbsoluteAxis` passed in */
    public inline function getAbs(axis:AbsoluteAxis):T {
        return axis == Horizontal ? width : height;
    }

    /** Get either the width or height depending on the `AbstractAxis` passed in */
    public inline function get(axis:AbstractAxis):T {
        return axis == Inline ? width : height;
    }

    /** Return a copy with the given axis set to value */
    public inline function with(axis:AbstractAxis, value:T):SizeOf<T> {
        return axis == Inline ? new SizeOf<T>(value, height) : new SizeOf<T>(width, value);
    }

    /** Swap width and height */
    public inline function transpose():SizeOf<T> {
        return new SizeOf<T>(height, width);
    }

    /** Applies the function `f` to both the width and height */
    public inline function map<R>(f:(T) -> R):SizeOf<R> {
        return new SizeOf<R>(f(width), f(height));
    }

    /** Applies the function `f` to the width */
    public inline function mapWidth(f:(T) -> T):SizeOf<T> {
        return new SizeOf<T>(f(width), height);
    }

    /** Applies the function `f` to the height */
    public inline function mapHeight(f:(T) -> T):SizeOf<T> {
        return new SizeOf<T>(width, f(height));
    }

    /** Applies the function `f` to both the width and height of this value and another passed value */
    public inline function zipMap<O, R>(other:SizeOf<O>, f:(T, O) -> R):SizeOf<R> {
        return new SizeOf<R>(f(width, other.width), f(height, other.height));
    }

    public inline function withWidth(value:T):SizeOf<T> {
        return new SizeOf<T>(value, height);
    }

    public inline function withHeight(value:T):SizeOf<T> {
        return new SizeOf<T>(width, value);
    }

    /** Get the main axis value for the given flex direction */
    public inline function main(direction:FlexDirection):T {
        return direction.isRow() ? width : height;
    }

    /** Get the cross axis value for the given flex direction */
    public inline function cross(direction:FlexDirection):T {
        return direction.isRow() ? height : width;
    }

    /** Return a copy with the main axis set to value */
    public inline function withMain(direction:FlexDirection, value:T):SizeOf<T> {
        return direction.isRow() ? new SizeOf<T>(value, height) : new SizeOf<T>(width, value);
    }

    /** Return a copy with the cross axis set to value */
    public inline function withCross(direction:FlexDirection, value:T):SizeOf<T> {
        return direction.isRow() ? new SizeOf<T>(width, value) : new SizeOf<T>(value, height);
    }

    /** Return a copy with the main axis mapped through `mapper` */
    public inline function mapMain(direction:FlexDirection, mapper:(T) -> T):SizeOf<T> {
        return direction.isRow() ? new SizeOf<T>(mapper(width), height) : new SizeOf<T>(width, mapper(height));
    }

    /** Return a copy with the cross axis mapped through `mapper` */
    public inline function mapCross(direction:FlexDirection, mapper:(T) -> T):SizeOf<T> {
        return direction.isRow() ? new SizeOf<T>(width, mapper(height)) : new SizeOf<T>(mapper(width), height);
    }

    public function toString():String {
        return 'Size(width: $width, height: $height)';
    }

}
