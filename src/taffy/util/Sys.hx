// Ported from taffy 0.15.0: src/util/sys.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.util;

/**
 * Float helpers matching the semantics of the Rust `f32` functions used by taffy.
 */
class Sys {

    /** Rust `f32::EPSILON` */
    public static inline final F32_EPSILON:Float = 1.1920928955078125e-7;

    /** Rust `f32::MAX` */
    public static inline final F32_MAX:Float = 3.4028234663852886e+38;

    /** Rust `f32::INFINITY` */
    public static final INFINITY:Float = Math.POSITIVE_INFINITY;

    /** Rust `f32::NEG_INFINITY` */
    public static final NEG_INFINITY:Float = Math.NEGATIVE_INFINITY;

    /** Round half away from zero for positive values (`(value + 0.5).floor()`), like taffy */
    public static inline function round(value:Float):Float {
        return Math.ffloor(value + 0.5);
    }

    public static inline function ceil(value:Float):Float {
        return Math.fceil(value);
    }

    public static inline function floor(value:Float):Float {
        return Math.ffloor(value);
    }

    public static inline function abs(value:Float):Float {
        return value < 0 ? -value : value;
    }

    /** Maximum of two floats, ignoring NaN like Rust `f32::max` */
    public static inline function f32Max(a:Float, b:Float):Float {
        return a > b ? a : (b != b ? a : b);
    }

    /** Minimum of two floats, ignoring NaN like Rust `f32::min` */
    public static inline function f32Min(a:Float, b:Float):Float {
        return a < b ? a : (b != b ? a : b);
    }

    /** Rust `f32::clamp` */
    public static inline function f32Clamp(value:Float, min:Float, max:Float):Float {
        return value < min ? min : (value > max ? max : value);
    }

    /** Rust `f32::is_finite` */
    public static inline function isFinite(value:Float):Bool {
        return value == value && value != Math.POSITIVE_INFINITY && value != Math.NEGATIVE_INFINITY;
    }

    /** Rust `f32::is_nan` */
    public static inline function isNaN(value:Float):Bool {
        return value != value;
    }

    /** Integer minimum */
    public static inline function imin(a:Int, b:Int):Int {
        return a < b ? a : b;
    }

    /** Integer maximum */
    public static inline function imax(a:Int, b:Int):Int {
        return a > b ? a : b;
    }

}
