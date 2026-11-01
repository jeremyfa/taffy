// Ported from taffy 0.15.0: src/style/block.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * Used by block layout to implement the legacy behaviour of `<center>` and `<div align="left | right | center">`
 */
enum abstract TextAlign(Int) {

    /** No special legacy text align behaviour. */
    var Auto = 0;

    /** Corresponds to `-webkit-left` or `-moz-left` in browsers */
    var LegacyLeft = 1;

    /** Corresponds to `-webkit-right` or `-moz-right` in browsers */
    var LegacyRight = 2;

    /** Corresponds to `-webkit-center` or `-moz-center` in browsers */
    var LegacyCenter = 3;

    /** Parse a CSS keyword, or return null */
    public static function parse(input:String):Null<TextAlign> {
        return switch (StringTools.trim(input).toLowerCase()) {
            case "auto": Auto;
            case "-webkit-left": LegacyLeft;
            case "-webkit-right": LegacyRight;
            case "-webkit-center": LegacyCenter;
            case _: null;
        }
    }

}
