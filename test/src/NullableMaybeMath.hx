package;

import taffy.util.F32;
import taffy.util.Sys;

/**
 * Frozen copy of the `Null<Float>` implementation of `taffy.util.MaybeMath`
 * as it was before the `OptionalFloat` conversion: the reference the tests of
 * `OptionalFloatTests` compare the new helpers with.
 *
 * This class is outside the `taffy` package, so the `F32` build macro does
 * not apply: the additions and subtractions round to f32 explicitly, like the
 * macro did in the original.
 */
class NullableMaybeMath {

    public static function maybeMin(self:Null<Float>, rhs:Null<Float>):Null<Float> {
        return self == null ? null : (rhs == null ? self : Sys.f32Min(self, rhs));
    }

    public static function maybeMax(self:Null<Float>, rhs:Null<Float>):Null<Float> {
        return self == null ? null : (rhs == null ? self : Sys.f32Max(self, rhs));
    }

    public static function maybeClamp(self:Null<Float>, min:Null<Float>, max:Null<Float>):Null<Float> {
        return self == null ? null : maybeClampF(self, min, max);
    }

    public static function maybeAdd(self:Null<Float>, rhs:Null<Float>):Null<Float> {
        return self == null ? null : (rhs == null ? self : F32.fround((self : Float) + (rhs : Float)));
    }

    public static function maybeSub(self:Null<Float>, rhs:Null<Float>):Null<Float> {
        return self == null ? null : (rhs == null ? self : F32.fround((self : Float) - (rhs : Float)));
    }

    public static function maybeMinF(self:Float, rhs:Null<Float>):Float {
        return rhs == null ? self : Sys.f32Min(self, rhs);
    }

    public static function maybeMaxF(self:Float, rhs:Null<Float>):Float {
        return rhs == null ? self : Sys.f32Max(self, rhs);
    }

    public static function maybeClampF(self:Float, min:Null<Float>, max:Null<Float>):Float {
        if (min != null && max != null)
            return Sys.f32Max(Sys.f32Min(self, max), min);
        if (max != null)
            return Sys.f32Min(self, max);
        if (min != null)
            return Sys.f32Max(self, min);
        return self;
    }

    public static function maybeAddF(self:Float, rhs:Null<Float>):Float {
        return rhs == null ? self : F32.fround(self + (rhs : Float));
    }

    public static function maybeSubF(self:Float, rhs:Null<Float>):Float {
        return rhs == null ? self : F32.fround(self - (rhs : Float));
    }

    public static function unwrapOr(self:Null<Float>, alt:Float):Float {
        return self == null ? alt : (self : Float);
    }

    public static function or(self:Null<Float>, alt:Null<Float>):Null<Float> {
        return self == null ? alt : self;
    }

}
