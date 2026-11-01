// Ported from taffy 0.15.0: src/style/mod.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * The CSS `contain` property, as a set of flags (only `layout` and `paint` affect layout).
 */
abstract Contain(Int) {

    /** No containment */
    public static inline final NONE:Contain = new Contain(0);

    /** Layout containment */
    public static inline final LAYOUT:Contain = new Contain(1);

    /** Paint containment */
    public static inline final PAINT:Contain = new Contain(2);

    /** `contain: content` (layout and paint) */
    public static inline final CONTENT:Contain = new Contain(3);

    /** The default value */
    public static inline final DEFAULT:Contain = NONE;

    public inline function new(bits:Int) {
        this = bits;
    }

    public inline function bits():Int {
        return this;
    }

    /** Whether all flags of `other` are set */
    public inline function contains(other:Contain):Bool {
        return this & other.bits() == other.bits();
    }

    /** Whether any flag of `other` is set */
    public inline function intersects(other:Contain):Bool {
        return this & other.bits() != 0;
    }

    /** Union of both flag sets */
    public inline function union(other:Contain):Contain {
        return new Contain(this | other.bits());
    }

    /** Whether the node establishes an independent formatting context (layout or paint containment) */
    public inline function establishesIndependentFormattingContext():Bool {
        return this & 3 != 0;
    }

    /** Whether the node's baseline is suppressed (layout containment) */
    public inline function suppressesBaseline():Bool {
        return this & 1 == 1;
    }

    /** Whether the node contains its scrollable overflow (layout or paint containment) */
    public inline function containsScrollableOverflow():Bool {
        return this & 3 != 0;
    }

    /** Parse a CSS value, or return null */
    public static function parse(input:String):Null<Contain> {
        final parts = StringTools.trim(input).toLowerCase().split(" ").filter(p -> p != "");
        if (parts.length == 0)
            return null;
        if (parts.length == 1 && parts[0] == "none")
            return NONE;
        if (parts.length == 1 && parts[0] == "content")
            return CONTENT;
        var flags = 0;
        var seen = 0;
        for (p in parts) {
            final bits = switch p {
                case "layout": 1;
                case "paint": 2;
                case "style": 64;
                case _: return null;
            }
            if (seen & bits != 0)
                return null;
            seen |= bits;
            flags |= bits & 3;
        }
        return new Contain(flags);
    }

}
