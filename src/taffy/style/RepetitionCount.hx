// Ported from taffy 0.15.0: src/style/grid.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * The first argument to a repeated track definition. This type represents the type of automatic repetition to perform.
 *
 * See https://www.w3.org/TR/css-grid-1/#auto-repeat for an explanation of how auto-repeated track definitions work
 * and the difference between AutoFit and AutoFill.
 */
enum RepetitionCount {

    /** Auto-repeating tracks should be generated to fit the container */
    AutoFill;

    /** Auto-repeating tracks should be generated to fit the container (empty tracks are collapsed) */
    AutoFit;

    /** The specified tracks should be repeated exacts N times */
    Count(count:Int);

}

/**
 * Helpers for `RepetitionCount`
 */
class RepetitionCountTools {

    /** Whether the repetition count is `AutoFill` or `AutoFit` */
    public static inline function isAuto(self:RepetitionCount):Bool {
        return switch self {
            case AutoFill | AutoFit: true;
            case Count(_): false;
        }
    }

    /** Whether the repetition count is `AutoFit` */
    public static inline function isAutoFit(self:RepetitionCount):Bool {
        return switch self {
            case AutoFit: true;
            case _: false;
        }
    }

    /** Convert `"auto-fit"` / `"auto-fill"` into a `RepetitionCount`, or return null */
    public static function fromString(value:String):Null<RepetitionCount> {
        return switch value {
            case "auto-fit": AutoFit;
            case "auto-fill": AutoFill;
            case _: null;
        }
    }

    /** Structural equality */
    public static function equals(self:RepetitionCount, other:RepetitionCount):Bool {
        return switch [self, other] {
            case [AutoFill, AutoFill] | [AutoFit, AutoFit]: true;
            case [Count(a), Count(b)]: a == b;
            case _: false;
        }
    }

}
