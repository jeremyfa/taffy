// Ported from taffy 0.15.0: src/util/math.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.util;

/**
 * A trait to conveniently calculate minimums and maximums when some data may not be defined.
 *
 * In Haxe, `Option<f32>` is `Null<Float>`. The `maybe*` functions implement the
 * `Option<f32> x Option<f32> -> Option<f32>` behaviour, which also covers
 * `Option<f32> x f32` (a non null rhs). The `maybe*F` functions implement
 * `f32 x Option<f32> -> f32`. Use with `using taffy.util.MaybeMath;`.
 *
 * The `AvailableSpace` variants live in `taffy.style.AvailableSpace.AvailableSpaceTools`.
 */
class MaybeMath {

    /** Returns the minimum of `self` and `rhs`, or `self` if `rhs` is null. Null if `self` is null. */
    public static inline function maybeMin(self:Null<Float>, rhs:Null<Float>):Null<Float> {
        return self == null ? null : (rhs == null ? self : Sys.f32Min(self, rhs));
    }

    /** Returns the maximum of `self` and `rhs`, or `self` if `rhs` is null. Null if `self` is null. */
    public static inline function maybeMax(self:Null<Float>, rhs:Null<Float>):Null<Float> {
        return self == null ? null : (rhs == null ? self : Sys.f32Max(self, rhs));
    }

    /** Returns `self` clamped between `min` and `max` (each bound only applied if set). Null if `self` is null. */
    public static inline function maybeClamp(self:Null<Float>, min:Null<Float>, max:Null<Float>):Null<Float> {
        return self == null ? null : maybeClampF(self, min, max);
    }

    /** Adds `self` and `rhs`, or returns `self` if `rhs` is null. Null if `self` is null. */
    public static inline function maybeAdd(self:Null<Float>, rhs:Null<Float>):Null<Float> {
        return self == null ? null : (rhs == null ? self : (self : Float) + (rhs : Float));
    }

    /** Subtracts `rhs` from `self`, or returns `self` if `rhs` is null. Null if `self` is null. */
    public static inline function maybeSub(self:Null<Float>, rhs:Null<Float>):Null<Float> {
        return self == null ? null : (rhs == null ? self : (self : Float) - (rhs : Float));
    }

    /** `f32::maybe_min(Option<f32>) -> f32` */
    public static inline function maybeMinF(self:Float, rhs:Null<Float>):Float {
        return rhs == null ? self : Sys.f32Min(self, rhs);
    }

    /** `f32::maybe_max(Option<f32>) -> f32` */
    public static inline function maybeMaxF(self:Float, rhs:Null<Float>):Float {
        return rhs == null ? self : Sys.f32Max(self, rhs);
    }

    /** `f32::maybe_clamp(Option<f32>, Option<f32>) -> f32` */
    public static function maybeClampF(self:Float, min:Null<Float>, max:Null<Float>):Float {
        if (min != null && max != null)
            return Sys.f32Max(Sys.f32Min(self, max), min);
        if (max != null)
            return Sys.f32Min(self, max);
        if (min != null)
            return Sys.f32Max(self, min);
        return self;
    }

    /** `f32::maybe_add(Option<f32>) -> f32` */
    public static inline function maybeAddF(self:Float, rhs:Null<Float>):Float {
        return rhs == null ? self : self + (rhs : Float);
    }

    /** `f32::maybe_sub(Option<f32>) -> f32` */
    public static inline function maybeSubF(self:Float, rhs:Null<Float>):Float {
        return rhs == null ? self : self - (rhs : Float);
    }

    /** Rust `Option::unwrap_or` for `Null<Float>` */
    public static inline function unwrapOr(self:Null<Float>, alt:Float):Float {
        return self == null ? alt : (self : Float);
    }

    /** Rust `Option::or` for `Null<Float>` */
    public static inline function or(self:Null<Float>, alt:Null<Float>):Null<Float> {
        return self == null ? alt : self;
    }

}
