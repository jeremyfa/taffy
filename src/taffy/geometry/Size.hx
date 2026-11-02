// Ported from taffy 0.15.0: src/geometry.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.geometry;

import taffy.style.FlexDirection;
import taffy.util.OptionalFloat;
import taffy.util.Sys;
import taffy.util.MaybeMath;

/**
 * The width and height of a rectangle (concrete `Size<f32>`).
 *
 * Immutable: every operation returns a new instance.
 */
@:structInit
class Size {

    /** A size with both axes set to zero */
    public static final ZERO:Size = new Size(0.0, 0.0);

    /** The x extent of the rectangle */
    public final width:Float;

    /** The y extent of the rectangle */
    public final height:Float;

    public inline function new(width:Float, height:Float) {
        #if taffy_census
        taffy.util.Census.conc(width);
        taffy.util.Census.conc(height);
        #end
        this.width = width;
        this.height = height;
    }

    /** `new Size(width, height)`, or the shared `ZERO` when both are +0 (for results that are stored) */
    public static inline function shared(width:Float, height:Float):Size {
        return (isPositiveZero(width) && isPositiveZero(height)) ? ZERO : new Size(width, height);
    }

    /** Whether `v` is +0 (not -0, which `ZERO` would turn into +0) */
    public static inline function isPositiveZero(v:Float):Bool {
        return v == 0.0 && 1.0 / v > 0.0;
    }

    /** Get either the width or height depending on the `AbsoluteAxis` passed in */
    public inline function getAbs(axis:AbsoluteAxis):Float {
        return axis == Horizontal ? width : height;
    }

    /** Get either the width or height depending on the `AbstractAxis` passed in */
    public inline function get(axis:AbstractAxis):Float {
        return axis == Inline ? width : height;
    }

    /** Return a copy with the given axis set to value */
    public inline function with(axis:AbstractAxis, value:Float):Size {
        final inl = axis == Inline;
        return new Size(inl ? value : width, inl ? height : value);
    }

    /** Swap width and height */
    public inline function transpose():Size {
        return new Size(height, width);
    }

    public inline function add(rhs:Size):Size {
        return new Size(width + rhs.width, height + rhs.height);
    }

    public inline function sub(rhs:Size):Size {
        return new Size(width - rhs.width, height - rhs.height);
    }

    public inline function map(f:Float->Float):Size {
        return new Size(f(width), f(height));
    }

    public inline function withWidth(value:Float):Size {
        return new Size(value, height);
    }

    public inline function withHeight(value:Float):Size {
        return new Size(width, value);
    }

    /** Get the main axis value for the given flex direction */
    public inline function main(direction:FlexDirection):Float {
        return direction.isRow() ? width : height;
    }

    /** Get the cross axis value for the given flex direction */
    public inline function cross(direction:FlexDirection):Float {
        return direction.isRow() ? height : width;
    }

    /** Return a copy with the main axis set to value */
    public inline function withMain(direction:FlexDirection, value:Float):Size {
        final isRow = direction.isRow();
        return new Size(isRow ? value : width, isRow ? height : value);
    }

    /** Return a copy with the cross axis set to value */
    public inline function withCross(direction:FlexDirection, value:Float):Size {
        final isRow = direction.isRow();
        return new Size(isRow ? width : value, isRow ? value : height);
    }

    /** Applies `f32_max` to each component separately */
    public inline function f32Max(rhs:Size):Size {
        return new Size(Sys.f32Max(width, rhs.width), Sys.f32Max(height, rhs.height));
    }

    /** Applies `f32_min` to each component separately */
    public inline function f32Min(rhs:Size):Size {
        return new Size(Sys.f32Min(width, rhs.width), Sys.f32Min(height, rhs.height));
    }

    /** Return true if both width and height are greater than 0 */
    public inline function hasNonZeroArea():Bool {
        return width > 0.0 && height > 0.0;
    }

    /** Convert to a `SizeOpt` with both axes set (Rust: `size.map(Some)`) */
    public inline function toOptions():SizeOpt {
        return new SizeOpt(OptionalFloat.some(width), OptionalFloat.some(height));
    }

    /** `MaybeMath::maybe_min` with an optional rhs */
    public inline function maybeMin(rhs:SizeOpt):Size {
        return new Size(MaybeMath.maybeMinF(width, rhs.width), MaybeMath.maybeMinF(height, rhs.height));
    }

    /** `MaybeMath::maybe_max` with an optional rhs */
    public inline function maybeMax(rhs:SizeOpt):Size {
        return new Size(MaybeMath.maybeMaxF(width, rhs.width), MaybeMath.maybeMaxF(height, rhs.height));
    }

    /** `MaybeMath::maybe_clamp` with optional bounds */
    public inline function maybeClamp(min:SizeOpt, max:SizeOpt):Size {
        return new Size(MaybeMath.maybeClampF(width, min.width, max.width), MaybeMath.maybeClampF(height, min.height, max.height));
    }

    /** `MaybeMath::maybe_add` with an optional rhs */
    public inline function maybeAdd(rhs:SizeOpt):Size {
        return new Size(MaybeMath.maybeAddF(width, rhs.width), MaybeMath.maybeAddF(height, rhs.height));
    }

    /** `MaybeMath::maybe_sub` with an optional rhs */
    public inline function maybeSub(rhs:SizeOpt):Size {
        return new Size(MaybeMath.maybeSubF(width, rhs.width), MaybeMath.maybeSubF(height, rhs.height));
    }

    public inline function equals(other:Size):Bool {
        return width == other.width && height == other.height;
    }

    public function toString():String {
        return 'Size(width: $width, height: $height)';
    }

}
