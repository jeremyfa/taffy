// Ported from taffy 0.15.0: src/geometry.rs, src/util/math.rs, src/style/available_space.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.geometry;

import taffy.style.AvailableSpace;
import taffy.style.FlexDirection;
import taffy.util.MaybeMath;

using taffy.style.AvailableSpace;

/**
 * The width and height of a rectangle, generic version (`Size<T>` where `T` is not `f32`).
 *
 * Used as `SizeOf<Null<Float>>` (Rust `Size<Option<f32>>`), `SizeOf<AvailableSpace>`,
 * `SizeOf<Dimension>`, `SizeOf<Bool>`... Type specific helpers live in the
 * `OptionSizeTools` and `AvailableSpaceSizeTools` static extensions of this module.
 *
 * Immutable: every operation returns a new instance.
 */
@:structInit
class SizeOf<T> {

    /** The x extent of the rectangle */
    public final width:T;

    /** The y extent of the rectangle */
    public final height:T;

    public inline function new(width:T, height:T) {
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
    public inline function map<R>(f:T->R):SizeOf<R> {
        return new SizeOf<R>(f(width), f(height));
    }

    /** Applies the function `f` to the width */
    public inline function mapWidth(f:T->T):SizeOf<T> {
        return new SizeOf<T>(f(width), height);
    }

    /** Applies the function `f` to the height */
    public inline function mapHeight(f:T->T):SizeOf<T> {
        return new SizeOf<T>(width, f(height));
    }

    /** Applies the function `f` to both the width and height of this value and another passed value */
    public inline function zipMap<O, R>(other:SizeOf<O>, f:T->O->R):SizeOf<R> {
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
    public inline function mapMain(direction:FlexDirection, mapper:T->T):SizeOf<T> {
        return direction.isRow() ? new SizeOf<T>(mapper(width), height) : new SizeOf<T>(width, mapper(height));
    }

    /** Return a copy with the cross axis mapped through `mapper` */
    public inline function mapCross(direction:FlexDirection, mapper:T->T):SizeOf<T> {
        return direction.isRow() ? new SizeOf<T>(width, mapper(height)) : new SizeOf<T>(mapper(width), height);
    }

    public function toString():String {
        return 'Size(width: $width, height: $height)';
    }

}

/**
 * Helpers for `SizeOf<Null<Float>>` (Rust `Size<Option<f32>>`).
 * Use with `using taffy.geometry.SizeOf;`.
 */
class OptionSizeTools {

    /** A `SizeOf<Null<Float>>` with both axes set to `null` (Rust `Size::NONE`) */
    public static final NONE:SizeOf<Null<Float>> = new SizeOf<Null<Float>>(null, null);

    /** Create a new `SizeOf<Null<Float>>` with both axes set (Rust `Size::new`) */
    public static inline function some(width:Float, height:Float):SizeOf<Null<Float>> {
        return new SizeOf<Null<Float>>(width, height);
    }

    /** Creates a new `SizeOf<Null<Float>>` with either the width or height set based on the provided `direction` */
    public static inline function fromCross(direction:FlexDirection, value:Null<Float>):SizeOf<Null<Float>> {
        return direction.isRow() ? new SizeOf<Null<Float>>(null, value) : new SizeOf<Null<Float>>(value, null);
    }

    /** Applies aspect_ratio (if one is supplied) to the Size: if width is set but not height, height is width / ratio and vice versa */
    public static function maybeApplyAspectRatio(self:SizeOf<Null<Float>>, aspectRatio:Null<Float>):SizeOf<Null<Float>> {
        if (aspectRatio == null)
            return self;
        final ratio:Float = aspectRatio;
        final w = self.width;
        final h = self.height;
        if (w != null && h == null) {
            final width:Float = w;
            return new SizeOf<Null<Float>>(width, width / ratio);
        }
        if (w == null && h != null) {
            final height:Float = h;
            return new SizeOf<Null<Float>>(height * ratio, height);
        }
        return self;
    }

    /** Performs `Option::unwrap_or` on each component separately */
    public static inline function unwrapOr(self:SizeOf<Null<Float>>, alt:Size):Size {
        return new Size(self.width != null ? (self.width : Float) : alt.width, self.height != null ? (self.height : Float) : alt.height);
    }

    /** Performs `Option::or` on each component separately */
    public static inline function or(self:SizeOf<Null<Float>>, alt:SizeOf<Null<Float>>):SizeOf<Null<Float>> {
        return new SizeOf<Null<Float>>(self.width != null ? self.width : alt.width, self.height != null ? self.height : alt.height);
    }

    /** Return true if both components are set */
    public static inline function bothAxisDefined(self:SizeOf<Null<Float>>):Bool {
        return self.width != null && self.height != null;
    }

    public static inline function maybeMin(self:SizeOf<Null<Float>>, rhs:SizeOf<Null<Float>>):SizeOf<Null<Float>> {
        return new SizeOf<Null<Float>>(MaybeMath.maybeMin(self.width, rhs.width), MaybeMath.maybeMin(self.height, rhs.height));
    }

    public static inline function maybeMax(self:SizeOf<Null<Float>>, rhs:SizeOf<Null<Float>>):SizeOf<Null<Float>> {
        return new SizeOf<Null<Float>>(MaybeMath.maybeMax(self.width, rhs.width), MaybeMath.maybeMax(self.height, rhs.height));
    }

    public static inline function maybeClamp(self:SizeOf<Null<Float>>, min:SizeOf<Null<Float>>, max:SizeOf<Null<Float>>):SizeOf<Null<Float>> {
        return new SizeOf<Null<Float>>(MaybeMath.maybeClamp(self.width, min.width, max.width), MaybeMath.maybeClamp(self.height, min.height, max.height));
    }

    public static inline function maybeAdd(self:SizeOf<Null<Float>>, rhs:SizeOf<Null<Float>>):SizeOf<Null<Float>> {
        return new SizeOf<Null<Float>>(MaybeMath.maybeAdd(self.width, rhs.width), MaybeMath.maybeAdd(self.height, rhs.height));
    }

    public static inline function maybeSub(self:SizeOf<Null<Float>>, rhs:SizeOf<Null<Float>>):SizeOf<Null<Float>> {
        return new SizeOf<Null<Float>>(MaybeMath.maybeSub(self.width, rhs.width), MaybeMath.maybeSub(self.height, rhs.height));
    }

    /** `maybe_add` with a concrete rhs (Rust `Size<Option<f32>>.maybe_add(Size<f32>)`) */
    public static inline function maybeAddSize(self:SizeOf<Null<Float>>, rhs:Size):SizeOf<Null<Float>> {
        return new SizeOf<Null<Float>>(MaybeMath.maybeAdd(self.width, rhs.width), MaybeMath.maybeAdd(self.height, rhs.height));
    }

    /** `maybe_sub` with a concrete rhs (Rust `Size<Option<f32>>.maybe_sub(Size<f32>)`) */
    public static inline function maybeSubSize(self:SizeOf<Null<Float>>, rhs:Size):SizeOf<Null<Float>> {
        return new SizeOf<Null<Float>>(MaybeMath.maybeSub(self.width, rhs.width), MaybeMath.maybeSub(self.height, rhs.height));
    }

    /** `maybe_max` with a concrete rhs (Rust `Size<Option<f32>>.maybe_max(Size<f32>)`) */
    public static inline function maybeMaxSize(self:SizeOf<Null<Float>>, rhs:Size):SizeOf<Null<Float>> {
        return new SizeOf<Null<Float>>(MaybeMath.maybeMax(self.width, rhs.width), MaybeMath.maybeMax(self.height, rhs.height));
    }

    /** `maybe_min` with a concrete rhs (Rust `Size<Option<f32>>.maybe_min(Size<f32>)`) */
    public static inline function maybeMinSize(self:SizeOf<Null<Float>>, rhs:Size):SizeOf<Null<Float>> {
        return new SizeOf<Null<Float>>(MaybeMath.maybeMin(self.width, rhs.width), MaybeMath.maybeMin(self.height, rhs.height));
    }

    /** Convert to `SizeOf<AvailableSpace>`: `Some(v)` becomes `Definite(v)`, `None` becomes `MaxContent` */
    public static inline function toAvailableSpace(self:SizeOf<Null<Float>>):SizeOf<AvailableSpace> {
        return new SizeOf<AvailableSpace>(AvailableSpaceTools.fromOption(self.width), AvailableSpaceTools.fromOption(self.height));
    }

    public static inline function equals(self:SizeOf<Null<Float>>, other:SizeOf<Null<Float>>):Bool {
        return self.width == other.width && self.height == other.height;
    }

}

/**
 * Helpers for `SizeOf<AvailableSpace>`.
 * Use with `using taffy.geometry.SizeOf;`.
 */
class AvailableSpaceSizeTools {

    /** Both axes set to `MaxContent` (Rust `Size::MAX_CONTENT`) */
    public static final MAX_CONTENT:SizeOf<AvailableSpace> = new SizeOf<AvailableSpace>(MaxContent, MaxContent);

    /** Both axes set to `MinContent` (Rust `Size::MIN_CONTENT`) */
    public static final MIN_CONTENT:SizeOf<AvailableSpace> = new SizeOf<AvailableSpace>(MinContent, MinContent);

    /** Convert `SizeOf<AvailableSpace>` into `SizeOf<Null<Float>>` */
    public static inline function intoOptions(self:SizeOf<AvailableSpace>):SizeOf<Null<Float>> {
        return new SizeOf<Null<Float>>(self.width.intoOption(), self.height.intoOption());
    }

    /** If passed value is set then return `Definite` containing that value, else return self */
    public static inline function maybeSet(self:SizeOf<AvailableSpace>, value:SizeOf<Null<Float>>):SizeOf<AvailableSpace> {
        return new SizeOf<AvailableSpace>(self.width.maybeSet(value.width), self.height.maybeSet(value.height));
    }

    public static inline function maybeMin(self:SizeOf<AvailableSpace>, rhs:SizeOf<Null<Float>>):SizeOf<AvailableSpace> {
        return new SizeOf<AvailableSpace>(self.width.maybeMin(rhs.width), self.height.maybeMin(rhs.height));
    }

    public static inline function maybeMax(self:SizeOf<AvailableSpace>, rhs:SizeOf<Null<Float>>):SizeOf<AvailableSpace> {
        return new SizeOf<AvailableSpace>(self.width.maybeMax(rhs.width), self.height.maybeMax(rhs.height));
    }

    public static inline function maybeClamp(self:SizeOf<AvailableSpace>, min:SizeOf<Null<Float>>, max:SizeOf<Null<Float>>):SizeOf<AvailableSpace> {
        return new SizeOf<AvailableSpace>(self.width.maybeClamp(min.width, max.width), self.height.maybeClamp(min.height, max.height));
    }

    public static inline function maybeAdd(self:SizeOf<AvailableSpace>, rhs:SizeOf<Null<Float>>):SizeOf<AvailableSpace> {
        return new SizeOf<AvailableSpace>(self.width.maybeAdd(rhs.width), self.height.maybeAdd(rhs.height));
    }

    public static inline function maybeSub(self:SizeOf<AvailableSpace>, rhs:SizeOf<Null<Float>>):SizeOf<AvailableSpace> {
        return new SizeOf<AvailableSpace>(self.width.maybeSub(rhs.width), self.height.maybeSub(rhs.height));
    }

    /** `maybe_sub` with a concrete rhs */
    public static inline function maybeSubSize(self:SizeOf<AvailableSpace>, rhs:Size):SizeOf<AvailableSpace> {
        return new SizeOf<AvailableSpace>(self.width.maybeSub(rhs.width), self.height.maybeSub(rhs.height));
    }

    /** `maybe_max` with a concrete rhs */
    public static inline function maybeMaxSize(self:SizeOf<AvailableSpace>, rhs:Size):SizeOf<AvailableSpace> {
        return new SizeOf<AvailableSpace>(self.width.maybeMax(rhs.width), self.height.maybeMax(rhs.height));
    }

    public static inline function equals(self:SizeOf<AvailableSpace>, other:SizeOf<AvailableSpace>):Bool {
        return self.width.equals(other.width) && self.height.equals(other.height);
    }

}
