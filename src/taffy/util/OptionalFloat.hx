// Ported from taffy 0.15.0: src/util/math.rs (the `Option<f32>` implementations of `MaybeMath`)
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.util;

/**
 * Rust `Option<f32>` without boxing: a plain `Float` where one value, `NONE`,
 * means "absent".
 *
 * `Null<Float>` is a boxed `Dynamic` on hxcpp, which made every optional
 * float of the layout allocate. This abstract stays a `Float` on every
 * target. The absent value is the finite sentinel `-1e300`, outside the f32
 * range: every value computed by taffy goes through `F32.fround`, so no f32
 * arithmetic can produce it, and if an absent value ever leaks into
 * arithmetic, the rounding turns it into `-inf` (a visible error, not a
 * plausible number). See `docs/perf/OPTIONAL_FLOAT.md` of glaze-golden for
 * the measurements behind this choice.
 *
 * There is deliberately no implicit conversion from `Float`: on hxcpp a
 * `Null<Float>` unifies with `Float`, so a null would silently become
 * `some(0)` (and `some(null)` on JS). Write `some(v)`, or `fromNullable(v)`
 * where the source really is nullable.
 *
 * Semantics follow `Option<f32>` exactly: `some(NaN)` and `some(inf)` are
 * present values, two absent values are equal (`==` compares the underlying
 * floats), NaN keeps its IEEE comparisons.
 *
 * The sentinel must never be written as a literal outside `ABSENT`: the
 * `F32` build macro rounds float literals to f32, which would give `-inf`.
 * Inline constants are left alone by the macro, which is why `ABSENT` and
 * `NONE` are `static inline final`.
 *
 * Define `taffy_check_optional` to make `unwrap()` throw on an absent value
 * (Rust's `Option::unwrap` panic).
 */
abstract OptionalFloat(Float) {

    /** The underlying absent value. Never write this number anywhere else. */
    static inline final ABSENT:Float = -1e300;

    /** Rust `None` */
    public static inline final NONE:OptionalFloat = new OptionalFloat(ABSENT);

    inline function new(value:Float) {
        this = value;
    }

    /** Rust `Some(value)` */
    public static inline function some(value:Float):OptionalFloat {
        return new OptionalFloat(value);
    }

    /** Converts from a nullable float (`null` becomes `NONE`) */
    public static inline function fromNullable(value:Null<Float>):OptionalFloat {
        return value == null ? NONE : new OptionalFloat(value);
    }

    /** Converts to a nullable float (`NONE` becomes `null`) */
    public inline function toNullable():Null<Float> {
        return this == ABSENT ? null : this;
    }

    /** Rust `Option::is_some` */
    public inline function isSome():Bool {
        return this != ABSENT;
    }

    /** Rust `Option::is_none` */
    public inline function isNone():Bool {
        return this == ABSENT;
    }

    /** Rust `Option::unwrap`. Only checked with `-D taffy_check_optional`. */
    public inline function unwrap():Float {
        #if taffy_check_optional
        if (this == ABSENT)
            throw 'OptionalFloat.unwrap() on None';
        #end
        return this;
    }

    /** Rust `Option::unwrap_or` */
    public inline function unwrapOr(alt:Float):Float {
        return this == ABSENT ? alt : this;
    }

    /** Rust `Option::or` */
    public inline function or(alt:OptionalFloat):OptionalFloat {
        return this == ABSENT ? alt : new OptionalFloat(this);
    }

    /** `Option<f32>::maybe_min(Option<f32>)`: `self` if `rhs` is none, none if `self` is none */
    public inline function maybeMin(rhs:OptionalFloat):OptionalFloat {
        return this == ABSENT ? NONE : (rhs.isNone() ? new OptionalFloat(this) : new OptionalFloat(Sys.f32Min(this, rhs.raw())));
    }

    /** `Option<f32>::maybe_max(Option<f32>)`: `self` if `rhs` is none, none if `self` is none */
    public inline function maybeMax(rhs:OptionalFloat):OptionalFloat {
        return this == ABSENT ? NONE : (rhs.isNone() ? new OptionalFloat(this) : new OptionalFloat(Sys.f32Max(this, rhs.raw())));
    }

    /** `Option<f32>::maybe_clamp(Option<f32>, Option<f32>)`: each bound only applied if set, none if `self` is none */
    public inline function maybeClamp(min:OptionalFloat, max:OptionalFloat):OptionalFloat {
        return this == ABSENT ? NONE : new OptionalFloat(clampF(this, min, max));
    }

    /** `f32::maybe_clamp(Option<f32>, Option<f32>) -> f32` */
    @:noDebug
    public static function clampF(value:Float, min:OptionalFloat, max:OptionalFloat):Float {
        if (min.isSome() && max.isSome())
            return Sys.f32Max(Sys.f32Min(value, max.raw()), min.raw());
        if (max.isSome())
            return Sys.f32Min(value, max.raw());
        if (min.isSome())
            return Sys.f32Max(value, min.raw());
        return value;
    }

    /** `Option<f32>::maybe_add(Option<f32>)`: `self` if `rhs` is none, none if `self` is none */
    public inline function maybeAdd(rhs:OptionalFloat):OptionalFloat {
        return this == ABSENT ? NONE : (rhs.isNone() ? new OptionalFloat(this) : new OptionalFloat(this + rhs.raw()));
    }

    /** `Option<f32>::maybe_sub(Option<f32>)`: `self` if `rhs` is none, none if `self` is none */
    public inline function maybeSub(rhs:OptionalFloat):OptionalFloat {
        return this == ABSENT ? NONE : (rhs.isNone() ? new OptionalFloat(this) : new OptionalFloat(this - rhs.raw()));
    }

    /** The underlying float, sentinel included. Only for this module and `MaybeMath`. */
    @:allow(taffy.util.MaybeMath)
    inline function raw():Float {
        return this;
    }

    public function toString():String {
        return this == ABSENT ? 'None' : 'Some(' + this + ')';
    }

}
