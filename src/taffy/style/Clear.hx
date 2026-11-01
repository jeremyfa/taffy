// Ported from taffy 0.15.0: src/style/float.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * The CSS `clear` property
 */
enum abstract Clear(Int) {

    /** Clear left floats */
    var Left = 0;

    /** Clear right floats */
    var Right = 1;

    /** Clear both left and right floats */
    var Both = 2;

    /** Do not clear floats */
    var None = 3;

    /** Parse a CSS keyword, or return null */
    public static function parse(input:String):Null<Clear> {
        return switch (StringTools.trim(input).toLowerCase()) {
            case "left": Left;
            case "right": Right;
            case "both": Both;
            case "none": None;
            case _: null;
        }
    }

}
