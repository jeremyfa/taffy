// Ported from taffy 0.15.0: src/style/alignment.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * Used to control how child nodes are aligned (`align-items`, `align-self`, `justify-items`, `justify-self`).
 * A keyword plus an overflow-position (`safe` / `unsafe`), packed in an `Int`.
 *
 * `AlignSelf`, `JustifyItems` and `JustifySelf` are aliases of this type.
 */
abstract AlignItems(Int) {

    public static inline final NORMAL:AlignItems = new AlignItems(0);
    public static inline final START:AlignItems = new AlignItems(1);
    public static inline final END:AlignItems = new AlignItems(2);
    public static inline final FLEX_START:AlignItems = new AlignItems(3);
    public static inline final FLEX_END:AlignItems = new AlignItems(4);
    public static inline final SELF_START:AlignItems = new AlignItems(5);
    public static inline final SELF_END:AlignItems = new AlignItems(6);
    public static inline final CENTER:AlignItems = new AlignItems(7);
    public static inline final BASELINE:AlignItems = new AlignItems(8);
    public static inline final STRETCH:AlignItems = new AlignItems(9);
    public static inline final SAFE_START:AlignItems = new AlignItems(1 | (2 << 4));
    public static inline final SAFE_END:AlignItems = new AlignItems(2 | (2 << 4));
    public static inline final SAFE_FLEX_START:AlignItems = new AlignItems(3 | (2 << 4));
    public static inline final SAFE_FLEX_END:AlignItems = new AlignItems(4 | (2 << 4));
    public static inline final SAFE_SELF_START:AlignItems = new AlignItems(5 | (2 << 4));
    public static inline final SAFE_SELF_END:AlignItems = new AlignItems(6 | (2 << 4));
    public static inline final SAFE_CENTER:AlignItems = new AlignItems(7 | (2 << 4));

    inline function new(bits:Int) {
        this = bits;
    }

    /** Create from a keyword and a safety */
    public static inline function of(keyword:AlignItemsKeyword, safety:AlignmentSafety):AlignItems {
        return new AlignItems((keyword : Int) | ((safety : Int) << 4));
    }

    /** The positional keyword */
    public var keyword(get, never):AlignItemsKeyword;

    inline function get_keyword():AlignItemsKeyword {
        return cast (this & 0xF);
    }

    /** The overflow-position */
    public var safety(get, never):AlignmentSafety;

    inline function get_safety():AlignmentSafety {
        return cast (this >> 4);
    }

    /** Whether the value is `safe` */
    public inline function isSafe():Bool {
        return (this >> 4) == 2;
    }

    /** Return a copy with the given safety */
    public inline function withSafety(safety:AlignmentSafety):AlignItems {
        return new AlignItems((this & 0xF) | ((safety : Int) << 4));
    }

    /** Whether the keyword is `Stretch` or `Normal` */
    public inline function isStretchOrNormal():Bool {
        final k = this & 0xF;
        return k == 9 || k == 0;
    }

    /** Resolve `self-start` / `self-end` against the item and container directions */
    @:noDebug
    public function resolveSelfRelative(itemDirection:Direction, containerDirection:Direction, axisIsInline:Bool):AlignItems {
        final flip = axisIsInline && itemDirection != containerDirection;
        final kw:AlignItemsKeyword = switch keyword {
            case SelfStart: flip ? End : Start;
            case SelfEnd: flip ? Start : End;
            case other: other;
        }
        return of(kw, safety);
    }

    @:op(A == B) static inline function eq(a:AlignItems, b:AlignItems):Bool {
        return (cast a : Int) == (cast b : Int);
    }

    @:op(A != B) static inline function neq(a:AlignItems, b:AlignItems):Bool {
        return (cast a : Int) != (cast b : Int);
    }

    /** Parse a CSS value, or return null */
    public static function parse(input:String):Null<AlignItems> {
        final parts = StringTools.trim(input).toLowerCase().split(" ").filter(p -> p != "");
        if (parts.length == 0 || parts.length > 2)
            return null;
        var safety = AlignmentSafety.Default;
        var word = parts[0];
        if (parts.length == 2) {
            safety = switch parts[0] {
                case "safe": AlignmentSafety.Safe;
                case "unsafe": AlignmentSafety.Unsafe;
                case _: return null;
            }
            word = parts[1];
        }
        final kw:AlignItemsKeyword = switch word {
            case "normal": Normal;
            case "start": Start;
            case "end": End;
            case "flex-start": FlexStart;
            case "flex-end": FlexEnd;
            case "self-start": SelfStart;
            case "self-end": SelfEnd;
            case "center": Center;
            case "baseline": Baseline;
            case "stretch": Stretch;
            case _: return null;
        }
        if (safety != AlignmentSafety.Default && (kw == Normal || kw == Baseline || kw == Stretch))
            return null;
        return of(kw, safety);
    }

}

/** Controls alignment of an individual node (`align-self`), see `AlignItems` */
typedef AlignSelf = AlignItems;

/** Used to control how child nodes are aligned in the inline axis (`justify-items`), see `AlignItems` */
typedef JustifyItems = AlignItems;

/** Controls alignment of an individual node in the inline axis (`justify-self`), see `AlignItems` */
typedef JustifySelf = AlignItems;
