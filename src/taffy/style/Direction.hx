// Ported from taffy 0.15.0: src/style/mod.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * The inline base direction of the node (CSS `direction`).
 *
 * The default value is `Ltr`.
 */
enum abstract Direction(Int) {

    /** Left to right */
    var Ltr = 0;

    /** Right to left */
    var Rtl = 1;

    /** Whether the direction is right to left */
    public inline function isRtl():Bool {
        return this == 1;
    }

    /** Parse a CSS keyword, or return null */
    public static function parse(input:String):Null<Direction> {
        return switch (StringTools.trim(input).toLowerCase()) {
            case "ltr": Ltr;
            case "rtl": Rtl;
            case _: null;
        }
    }

}
