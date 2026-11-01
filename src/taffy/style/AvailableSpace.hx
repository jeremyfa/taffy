// Ported from taffy 0.15.0: src/style/available_space.rs, src/util/math.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

import taffy.util.Sys;

/**
 * The amount of space available to a node in a given axis.
 * https://www.w3.org/TR/css-sizing-3/#available
 *
 * Note: compare values with `equals()` (from `AvailableSpaceTools`), not `==`.
 * Helpers are available with `using taffy.style.AvailableSpace;`.
 */
enum AvailableSpace {

    /** The amount of space available is the specified number of pixels */
    Definite(value:Float);

    /** The amount of space available is indefinite and the node should be laid out under a min-content constraint */
    MinContent;

    /** The amount of space available is indefinite and the node should be laid out under a max-content constraint */
    MaxContent;

}

/**
 * Methods of `AvailableSpace`
 */
class AvailableSpaceTools {

    /** `Definite(0.0)` */
    public static final ZERO:AvailableSpace = Definite(0.0);

    /** Create a `Definite` value */
    public static inline function definite(value:Float):AvailableSpace {
        return Definite(value);
    }

    /** `Some(value)` becomes `Definite(value)`, `None` becomes `MaxContent` */
    public static inline function fromOption(option:Null<Float>):AvailableSpace {
        return option != null ? Definite(option) : MaxContent;
    }

    /** Returns true for definite values, else false */
    public static inline function isDefinite(self:AvailableSpace):Bool {
        return self.match(Definite(_));
    }

    /** Convert to `Null<Float>`: definite values become the value, else null */
    public static inline function intoOption(self:AvailableSpace):Null<Float> {
        return switch self {
            case Definite(value): value;
            case _: null;
        }
    }

    /** Return the definite value or a default value */
    public static inline function unwrapOr(self:AvailableSpace, def:Float):Float {
        return switch self {
            case Definite(value): value;
            case _: def;
        }
    }

    /** Return the definite value. Throws if the value is not definite */
    public static inline function unwrap(self:AvailableSpace):Float {
        return switch self {
            case Definite(value): value;
            case _: throw 'AvailableSpace is not definite';
        }
    }

    /** Return self if definite or a default value */
    public static inline function or(self:AvailableSpace, def:AvailableSpace):AvailableSpace {
        return switch self {
            case Definite(_): self;
            case _: def;
        }
    }

    /** If passed value is set then return `Definite` containing that value, else return self */
    public static inline function maybeSet(self:AvailableSpace, value:Null<Float>):AvailableSpace {
        return value != null ? Definite(value) : self;
    }

    /** If self is definite, map the value through `mapFunction` */
    public static inline function mapDefiniteValue(self:AvailableSpace, mapFunction:Float->Float):AvailableSpace {
        return switch self {
            case Definite(value): Definite(mapFunction(value));
            case _: self;
        }
    }

    /** Compute free space given the passed used space */
    public static inline function computeFreeSpace(self:AvailableSpace, usedSpace:Float):Float {
        return switch self {
            case MaxContent: Math.POSITIVE_INFINITY;
            case MinContent: 0.0;
            case Definite(availableSpace): availableSpace - usedSpace;
        }
    }

    /** Compare equality with another AvailableSpace, treating definite values within `f32::EPSILON` of each other as equal */
    public static function isRoughlyEqual(self:AvailableSpace, other:AvailableSpace):Bool {
        return switch [self, other] {
            case [Definite(a), Definite(b)]: Sys.abs(a - b) < Sys.F32_EPSILON;
            case [MinContent, MinContent]: true;
            case [MaxContent, MaxContent]: true;
            case _: false;
        }
    }

    /** Structural equality (Rust `PartialEq`) */
    public static function equals(self:AvailableSpace, other:AvailableSpace):Bool {
        return switch [self, other] {
            case [Definite(a), Definite(b)]: a == b;
            case [MinContent, MinContent]: true;
            case [MaxContent, MaxContent]: true;
            case _: false;
        }
    }

    /** `MaybeMath::maybe_min` (`rhs` may be null) */
    public static function maybeMin(self:AvailableSpace, rhs:Null<Float>):AvailableSpace {
        return switch self {
            case Definite(val): rhs != null ? Definite(Sys.f32Min(val, rhs)) : self;
            case MinContent: rhs != null ? Definite(rhs) : MinContent;
            case MaxContent: rhs != null ? Definite(rhs) : MaxContent;
        }
    }

    /** `MaybeMath::maybe_max` (`rhs` may be null) */
    public static function maybeMax(self:AvailableSpace, rhs:Null<Float>):AvailableSpace {
        return switch self {
            case Definite(val): rhs != null ? Definite(Sys.f32Max(val, rhs)) : self;
            case _: self;
        }
    }

    /** `MaybeMath::maybe_clamp` (bounds may be null) */
    public static function maybeClamp(self:AvailableSpace, min:Null<Float>, max:Null<Float>):AvailableSpace {
        return switch self {
            case Definite(val): Definite(taffy.util.MaybeMath.maybeClampF(val, min, max));
            case _: self;
        }
    }

    /** `MaybeMath::maybe_add` (`rhs` may be null) */
    public static function maybeAdd(self:AvailableSpace, rhs:Null<Float>):AvailableSpace {
        return switch self {
            case Definite(val): rhs != null ? Definite(val + (rhs : Float)) : self;
            case _: self;
        }
    }

    /** `MaybeMath::maybe_sub` (`rhs` may be null) */
    public static function maybeSub(self:AvailableSpace, rhs:Null<Float>):AvailableSpace {
        return switch self {
            case Definite(val): rhs != null ? Definite(val - (rhs : Float)) : self;
            case _: self;
        }
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
        return Definite(v.value);
    }

}
