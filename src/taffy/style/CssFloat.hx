// Ported from taffy 0.15.0: src/style/float.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * The CSS `float` property.
 *
 * Named `CssFloat` (Rust `Float`) because `Float` is a core Haxe type.
 */
enum abstract CssFloat(Int) {

    /** The box is floated to the left */
    var Left = 0;

    /** The box is floated to the right */
    var Right = 1;

    /** The box is not floated */
    var None = 2;

    /** Whether the box is floated */
    public inline function isFloated():Bool {
        return this != 2;
    }

    /** The direction of the float, or null if not floated */
    public inline function floatDirection():Null<FloatDirection> {
        return this == 0 ? FloatDirection.Left : (this == 1 ? FloatDirection.Right : null);
    }

    /** Parse a CSS keyword, or return null */
    public static function parse(input:String):Null<CssFloat> {
        return switch (StringTools.trim(input).toLowerCase()) {
            case "left": Left;
            case "right": Right;
            case "none": None;
            case _: null;
        }
    }

}
