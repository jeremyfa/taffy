// Ported from taffy 0.15.0: src/style/available_space.rs, src/util/math.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

import taffy.util.Sys;
import taffy.util.OptionalFloat;

/**
 * The amount of space available to a node in a given axis.
 * https://www.w3.org/TR/css-sizing-3/#available
 *
 * Rust's enum `Definite(f32) | MinContent | MaxContent`, stored in a plain
 * `Float` so that nothing is allocated: a definite value is the float itself,
 * `MinContent` and `MaxContent` are two finite sentinels outside the f32 range
 * (`-2e300` and `-3e300`, distinct from `OptionalFloat.NONE`). Every value
 * computed by taffy goes through `F32.fround`, so no f32 arithmetic can
 * produce them; `Definite(NaN)` and `Definite(inf)` stay definite, like
 * upstream. See `docs/perf/OPTIONAL_FLOAT.md` in the GPUI port (section 6)
 * for the census behind this choice. The sentinels must never be written as
 * literals anywhere else (the `F32` macro would round them to `-inf`).
 *
 * Build values with `Definite(value)` (import `taffy.style.AvailableSpace.Definite`),
 * `MinContent` and `MaxContent`. Switch on a value with
 * `case MinContent:`, `case MaxContent:` and a capture last
 * (`case space: space.definiteValue()`). `==` compares like Rust's
 * `PartialEq` (`equals()` is kept as an alias).
 * Helpers are available with `using taffy.style.AvailableSpace;`.
 */
enum abstract AvailableSpace(Float) {

    static inline final MIN_CONTENT_VALUE:Float = -2e300;

    static inline final MAX_CONTENT_VALUE:Float = -3e300;

    /** The amount of space available is indefinite and the node should be laid out under a min-content constraint */
    var MinContent = MIN_CONTENT_VALUE;

    /** The amount of space available is indefinite and the node should be laid out under a max-content constraint */
    var MaxContent = MAX_CONTENT_VALUE;

    /** The amount of space available is the specified number of pixels */
    public static inline function Definite(value:Float):AvailableSpace {
        return cast value;
    }

    /** Returns true for definite values, else false */
    public inline function isDefinite():Bool {
        return this != MIN_CONTENT_VALUE && this != MAX_CONTENT_VALUE;
    }

    /**
     * The value of a definite space. Only checked with `-D taffy_check_optional`
     * (like `OptionalFloat.unwrap()`).
     */
    public inline function definiteValue():Float {
        #if taffy_check_optional
        if (!isDefinite())
            throw 'AvailableSpace is not definite';
        #end
        return this;
    }

    public function toString():String {
        return this == MIN_CONTENT_VALUE ? 'MinContent' : (this == MAX_CONTENT_VALUE ? 'MaxContent' : 'Definite(' + this + ')');
    }

}

/**
 * Methods of `AvailableSpace`
 */
class AvailableSpaceTools {

    /** `Definite(0.0)` */
    public static inline final ZERO:AvailableSpace = cast 0.0;

    /** Create a `Definite` value */
    public static inline function definite(value:Float):AvailableSpace {
        return AvailableSpace.Definite(value);
    }

    /** `Some(value)` becomes `Definite(value)`, `None` becomes `MaxContent` */
    public static inline function fromOption(option:OptionalFloat):AvailableSpace {
        return option.isSome() ? AvailableSpace.Definite(option.unwrap()) : MaxContent;
    }

    /** Convert to `OptionalFloat`: definite values become the value, else none */
    public static inline function intoOption(self:AvailableSpace):OptionalFloat {
        return self.isDefinite() ? OptionalFloat.some(self.definiteValue()) : OptionalFloat.NONE;
    }

    /** Return the definite value or a default value */
    public static inline function unwrapOr(self:AvailableSpace, def:Float):Float {
        return self.isDefinite() ? self.definiteValue() : def;
    }

    /** Return the definite value. Throws if the value is not definite */
    public static inline function unwrap(self:AvailableSpace):Float {
        if (!self.isDefinite())
            throw 'AvailableSpace is not definite';
        return self.definiteValue();
    }

    /** Return self if definite or a default value */
    public static inline function or(self:AvailableSpace, def:AvailableSpace):AvailableSpace {
        return self.isDefinite() ? self : def;
    }

    /** If passed value is set then return `Definite` containing that value, else return self */
    public static inline function maybeSet(self:AvailableSpace, value:OptionalFloat):AvailableSpace {
        return value.isSome() ? AvailableSpace.Definite(value.unwrap()) : self;
    }

    /** If self is definite, map the value through `mapFunction` */
    public static inline function mapDefiniteValue(self:AvailableSpace, mapFunction:(Float) -> Float):AvailableSpace {
        return self.isDefinite() ? AvailableSpace.Definite(mapFunction(self.definiteValue())) : self;
    }

    /** Compute free space given the passed used space */
    public static inline function computeFreeSpace(self:AvailableSpace, usedSpace:Float):Float {
        return switch self {
            case MaxContent: Math.POSITIVE_INFINITY;
            case MinContent: 0.0;
            case availableSpace: availableSpace.definiteValue() - usedSpace;
        }
    }

    /** Compare equality with another AvailableSpace, treating definite values within `f32::EPSILON` of each other as equal */
    public static function isRoughlyEqual(self:AvailableSpace, other:AvailableSpace):Bool {
        if (self.isDefinite() && other.isDefinite())
            return Sys.abs(self.definiteValue() - other.definiteValue()) < Sys.F32_EPSILON;
        return self == other;
    }

    /** Structural equality (Rust `PartialEq`), the same as `==` */
    public static inline function equals(self:AvailableSpace, other:AvailableSpace):Bool {
        return self == other;
    }

    /** `MaybeMath::maybe_min` (`rhs` may be none) */
    public static inline function maybeMin(self:AvailableSpace, rhs:OptionalFloat):AvailableSpace {
        return if (rhs.isNone()) self else if (self.isDefinite()) AvailableSpace.Definite(Sys.f32Min(self.definiteValue(), rhs.unwrap())) else AvailableSpace.Definite(rhs.unwrap());
    }

    /** `MaybeMath::maybe_max` (`rhs` may be none) */
    public static inline function maybeMax(self:AvailableSpace, rhs:OptionalFloat):AvailableSpace {
        return (self.isDefinite() && rhs.isSome()) ? AvailableSpace.Definite(Sys.f32Max(self.definiteValue(), rhs.unwrap())) : self;
    }

    /** `MaybeMath::maybe_clamp` (bounds may be none) */
    public static inline function maybeClamp(self:AvailableSpace, min:OptionalFloat, max:OptionalFloat):AvailableSpace {
        return self.isDefinite() ? AvailableSpace.Definite(taffy.util.MaybeMath.maybeClampF(self.definiteValue(), min, max)) : self;
    }

    /** `MaybeMath::maybe_add` (`rhs` may be none) */
    public static inline function maybeAdd(self:AvailableSpace, rhs:OptionalFloat):AvailableSpace {
        return (self.isDefinite() && rhs.isSome()) ? AvailableSpace.Definite(self.definiteValue() + rhs.unwrap()) : self;
    }

    /** `MaybeMath::maybe_sub` (`rhs` may be none) */
    public static inline function maybeSub(self:AvailableSpace, rhs:OptionalFloat):AvailableSpace {
        return (self.isDefinite() && rhs.isSome()) ? AvailableSpace.Definite(self.definiteValue() - rhs.unwrap()) : self;
    }

    /** Parse a CSS value (`max-content`, `min-content`, a non negative number with or without unit) */
    public static function parse(input:String):Null<AvailableSpace> {
        final s = StringTools.trim(input).toLowerCase();
        if (s == "max-content")
            return MaxContent;
        if (s == "min-content")
            return MinContent;
        final v = taffy.util.Parse.parseNumberWithUnit(s);
        if (v == null || v.value < 0)
            return null;
        return AvailableSpace.Definite(v.value);
    }

}
