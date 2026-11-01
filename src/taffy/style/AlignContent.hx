// Ported from taffy 0.15.0: src/style/alignment.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * Sets the distribution of space between and around content items (`align-content`, `justify-content`).
 * A keyword plus an overflow-position (`safe` / `unsafe`), packed in an `Int`.
 *
 * `JustifyContent` is an alias of this type.
 */
abstract AlignContent(Int) {

    public static inline final NORMAL:AlignContent = new AlignContent(0);
    public static inline final START:AlignContent = new AlignContent(1);
    public static inline final END:AlignContent = new AlignContent(2);
    public static inline final FLEX_START:AlignContent = new AlignContent(3);
    public static inline final FLEX_END:AlignContent = new AlignContent(4);
    public static inline final CENTER:AlignContent = new AlignContent(5);
    public static inline final STRETCH:AlignContent = new AlignContent(6);
    public static inline final SPACE_BETWEEN:AlignContent = new AlignContent(7);
    public static inline final SPACE_EVENLY:AlignContent = new AlignContent(8);
    public static inline final SPACE_AROUND:AlignContent = new AlignContent(9);
    public static inline final SAFE_START:AlignContent = new AlignContent(1 | (2 << 4));
    public static inline final SAFE_END:AlignContent = new AlignContent(2 | (2 << 4));
    public static inline final SAFE_FLEX_START:AlignContent = new AlignContent(3 | (2 << 4));
    public static inline final SAFE_FLEX_END:AlignContent = new AlignContent(4 | (2 << 4));
    public static inline final SAFE_CENTER:AlignContent = new AlignContent(5 | (2 << 4));

    inline function new(bits:Int) {
        this = bits;
    }

    /** Create from a keyword and a safety */
    public static inline function of(keyword:AlignContentKeyword, safety:AlignmentSafety):AlignContent {
        return new AlignContent((keyword : Int) | ((safety : Int) << 4));
    }

    /** The keyword */
    public var keyword(get, never):AlignContentKeyword;

    inline function get_keyword():AlignContentKeyword {
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
    public inline function withSafety(safety:AlignmentSafety):AlignContent {
        return new AlignContent((this & 0xF) | ((safety : Int) << 4));
    }

    /** Return a copy with the given keyword (keeping the safety) */
    public inline function withKeyword(keyword:AlignContentKeyword):AlignContent {
        return new AlignContent((keyword : Int) | (this & ~0xF));
    }

    @:op(A == B) static inline function eq(a:AlignContent, b:AlignContent):Bool {
        return (cast a : Int) == (cast b : Int);
    }

    @:op(A != B) static inline function neq(a:AlignContent, b:AlignContent):Bool {
        return (cast a : Int) != (cast b : Int);
    }

    /** Parse a CSS value, or return null */
    public static function parse(input:String):Null<AlignContent> {
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
        final kw:AlignContentKeyword = switch word {
            case "normal": Normal;
            case "start": Start;
            case "end": End;
            case "flex-start": FlexStart;
            case "flex-end": FlexEnd;
            case "center": Center;
            case "stretch": Stretch;
            case "space-between": SpaceBetween;
            case "space-evenly": SpaceEvenly;
            case "space-around": SpaceAround;
            case _: return null;
        }
        if (safety != AlignmentSafety.Default && (kw == Normal || kw == Stretch || kw == SpaceBetween || kw == SpaceEvenly || kw == SpaceAround))
            return null;
        return of(kw, safety);
    }

}

/** Sets the distribution of space between and around content items in the inline axis, see `AlignContent` */
typedef JustifyContent = AlignContent;
