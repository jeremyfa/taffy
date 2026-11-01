// Ported from taffy 0.15.0: src/util/math.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.util;

/**
 * A trait to conveniently calculate minimums and maximums when some data may not be defined.
 *
 * In Haxe, `Option<f32>` is `OptionalFloat`, whose own methods implement
 * `Option<f32> x Option<f32> -> Option<f32>` (`maybeMin`, `maybeMax`,
 * `maybeClamp`, `maybeAdd`, `maybeSub`). The functions here implement
 * `f32 x Option<f32> -> f32`. Use with `using taffy.util.MaybeMath;`.
 *
 * The `AvailableSpace` variants live in `taffy.style.AvailableSpace.AvailableSpaceTools`.
 */
class MaybeMath {

    /** `f32::maybe_min(Option<f32>) -> f32` */
    public static inline function maybeMinF(self:Float, rhs:OptionalFloat):Float {
        return rhs.isNone() ? self : Sys.f32Min(self, rhs.raw());
    }

    /** `f32::maybe_max(Option<f32>) -> f32` */
    public static inline function maybeMaxF(self:Float, rhs:OptionalFloat):Float {
        return rhs.isNone() ? self : Sys.f32Max(self, rhs.raw());
    }

    /** `f32::maybe_clamp(Option<f32>, Option<f32>) -> f32` */
    public static inline function maybeClampF(self:Float, min:OptionalFloat, max:OptionalFloat):Float {
        return OptionalFloat.clampF(self, min, max);
    }

    /** `f32::maybe_add(Option<f32>) -> f32` */
    public static inline function maybeAddF(self:Float, rhs:OptionalFloat):Float {
        return rhs.isNone() ? self : self + rhs.raw();
    }

    /** `f32::maybe_sub(Option<f32>) -> f32` */
    public static inline function maybeSubF(self:Float, rhs:OptionalFloat):Float {
        return rhs.isNone() ? self : self - rhs.raw();
    }

}
