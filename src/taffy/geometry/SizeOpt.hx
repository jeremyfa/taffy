// Ported from taffy 0.15.0: src/geometry.rs, src/util/math.rs, src/style/available_space.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.geometry;

import taffy.style.AvailableSpace;
import taffy.style.FlexDirection;
import taffy.util.OptionalFloat;

/**
 * The width and height of a rectangle, each optional (Rust `Size<Option<f32>>`).
 *
 * The fields are `OptionalFloat`, a plain float, so nothing is boxed (the
 * generic `SizeOf<Null<Float>>` stored `Dynamic` fields on hxcpp).
 *
 * Immutable: every operation returns a new instance.
 */
@:structInit
class SizeOpt {

    /** Both axes absent (Rust `Size::NONE`) */
    public static final NONE:SizeOpt = new SizeOpt(OptionalFloat.NONE, OptionalFloat.NONE);

    /** The x extent of the rectangle */
    public final width:OptionalFloat;

    /** The y extent of the rectangle */
    public final height:OptionalFloat;

    public inline function new(width:OptionalFloat, height:OptionalFloat) {
        #if taffy_census
        taffy.util.Census.optional(width, 'SizeOpt.new');
        taffy.util.Census.optional(height, 'SizeOpt.new');
        #end
        this.width = width;
        this.height = height;
    }

    /** Both axes set (Rust `Size::new` wrapped in `Some`) */
    public static inline function some(width:Float, height:Float):SizeOpt {
        return new SizeOpt(OptionalFloat.some(width), OptionalFloat.some(height));
    }

    /** Creates a size with either the width or height set based on the provided `direction` */
    public static inline function fromCross(direction:FlexDirection, value:OptionalFloat):SizeOpt {
        return direction.isRow() ? new SizeOpt(OptionalFloat.NONE, value) : new SizeOpt(value, OptionalFloat.NONE);
    }

    /** Get either the width or height depending on the `AbsoluteAxis` passed in */
    public inline function getAbs(axis:AbsoluteAxis):OptionalFloat {
        return axis == Horizontal ? width : height;
    }

    /** Get either the width or height depending on the `AbstractAxis` passed in */
    public inline function get(axis:AbstractAxis):OptionalFloat {
        return axis == Inline ? width : height;
    }

    /** Return a copy with the given axis set to value */
    public inline function with(axis:AbstractAxis, value:OptionalFloat):SizeOpt {
        return axis == Inline ? new SizeOpt(value, height) : new SizeOpt(width, value);
    }

    /** Swap width and height */
    public inline function transpose():SizeOpt {
        return new SizeOpt(height, width);
    }

    /** Applies the function `f` to both the width and height */
    public inline function map(f:OptionalFloat->OptionalFloat):SizeOpt {
        return new SizeOpt(f(width), f(height));
    }

    public inline function withWidth(value:OptionalFloat):SizeOpt {
        return new SizeOpt(value, height);
    }

    public inline function withHeight(value:OptionalFloat):SizeOpt {
        return new SizeOpt(width, value);
    }

    /** Get the main axis value for the given flex direction */
    public inline function main(direction:FlexDirection):OptionalFloat {
        return direction.isRow() ? width : height;
    }

    /** Get the cross axis value for the given flex direction */
    public inline function cross(direction:FlexDirection):OptionalFloat {
        return direction.isRow() ? height : width;
    }

    /** Return a copy with the main axis set to value */
    public inline function withMain(direction:FlexDirection, value:OptionalFloat):SizeOpt {
        return direction.isRow() ? new SizeOpt(value, height) : new SizeOpt(width, value);
    }

    /** Return a copy with the cross axis set to value */
    public inline function withCross(direction:FlexDirection, value:OptionalFloat):SizeOpt {
        return direction.isRow() ? new SizeOpt(width, value) : new SizeOpt(value, height);
    }

    /** Applies aspect_ratio (if one is supplied) to the Size: if width is set but not height, height is width / ratio and vice versa */
    public function maybeApplyAspectRatio(aspectRatio:OptionalFloat):SizeOpt {
        if (aspectRatio.isNone())
            return this;
        final ratio:Float = aspectRatio.unwrap();
        if (width.isSome() && height.isNone()) {
            final w:Float = width.unwrap();
            return new SizeOpt(OptionalFloat.some(w), OptionalFloat.some(w / ratio));
        }
        if (width.isNone() && height.isSome()) {
            final h:Float = height.unwrap();
            return new SizeOpt(OptionalFloat.some(h * ratio), OptionalFloat.some(h));
        }
        return this;
    }

    /** Performs `Option::unwrap_or` on each component separately */
    public inline function unwrapOr(alt:Size):Size {
        return new Size(width.unwrapOr(alt.width), height.unwrapOr(alt.height));
    }

    /** Performs `Option::or` on each component separately */
    public inline function or(alt:SizeOpt):SizeOpt {
        return new SizeOpt(width.or(alt.width), height.or(alt.height));
    }

    /** Return true if both components are set */
    public inline function bothAxisDefined():Bool {
        return width.isSome() && height.isSome();
    }

    public inline function maybeMin(rhs:SizeOpt):SizeOpt {
        return new SizeOpt(width.maybeMin(rhs.width), height.maybeMin(rhs.height));
    }

    public inline function maybeMax(rhs:SizeOpt):SizeOpt {
        return new SizeOpt(width.maybeMax(rhs.width), height.maybeMax(rhs.height));
    }

    public inline function maybeClamp(min:SizeOpt, max:SizeOpt):SizeOpt {
        return new SizeOpt(width.maybeClamp(min.width, max.width), height.maybeClamp(min.height, max.height));
    }

    public inline function maybeAdd(rhs:SizeOpt):SizeOpt {
        return new SizeOpt(width.maybeAdd(rhs.width), height.maybeAdd(rhs.height));
    }

    public inline function maybeSub(rhs:SizeOpt):SizeOpt {
        return new SizeOpt(width.maybeSub(rhs.width), height.maybeSub(rhs.height));
    }

    /** `maybe_add` with a concrete rhs (Rust `Size<Option<f32>>.maybe_add(Size<f32>)`) */
    public inline function maybeAddSize(rhs:Size):SizeOpt {
        return new SizeOpt(width.maybeAdd(OptionalFloat.some(rhs.width)), height.maybeAdd(OptionalFloat.some(rhs.height)));
    }

    /** `maybe_sub` with a concrete rhs (Rust `Size<Option<f32>>.maybe_sub(Size<f32>)`) */
    public inline function maybeSubSize(rhs:Size):SizeOpt {
        return new SizeOpt(width.maybeSub(OptionalFloat.some(rhs.width)), height.maybeSub(OptionalFloat.some(rhs.height)));
    }

    /** `maybe_max` with a concrete rhs (Rust `Size<Option<f32>>.maybe_max(Size<f32>)`) */
    public inline function maybeMaxSize(rhs:Size):SizeOpt {
        return new SizeOpt(width.maybeMax(OptionalFloat.some(rhs.width)), height.maybeMax(OptionalFloat.some(rhs.height)));
    }

    /** `maybe_min` with a concrete rhs (Rust `Size<Option<f32>>.maybe_min(Size<f32>)`) */
    public inline function maybeMinSize(rhs:Size):SizeOpt {
        return new SizeOpt(width.maybeMin(OptionalFloat.some(rhs.width)), height.maybeMin(OptionalFloat.some(rhs.height)));
    }

    /** Convert to `SizeAvail`: `Some(v)` becomes `Definite(v)`, `None` becomes `MaxContent` */
    public inline function toAvailableSpace():SizeAvail {
        return new SizeAvail(AvailableSpaceTools.fromOption(width), AvailableSpaceTools.fromOption(height));
    }

    public inline function equals(other:SizeOpt):Bool {
        return width == other.width && height == other.height;
    }

    public function toString():String {
        return 'Size(width: $width, height: $height)';
    }

}
