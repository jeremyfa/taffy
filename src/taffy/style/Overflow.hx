// Ported from taffy 0.15.0: src/style/mod.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * How children overflowing their container should affect layout.
 *
 * The default value is `Visible`.
 */
enum abstract Overflow(Int) {

    /** The automatic minimum size of this node as a flexbox/grid item should be based on the size of its content. */
    var Visible = 0;

    /** Like `Visible`, but the content is clipped. Does not establish a scroll container. */
    var Clip = 1;

    /** The automatic minimum size of this node as a flexbox/grid item should be 0. */
    var Hidden = 2;

    /** Like `Hidden`, and space is reserved for a scrollbar. */
    var Scroll = 3;

    /** Returns true for overflow modes that contain their contents (`Hidden`, `Scroll`) */
    public inline function isScrollContainer():Bool {
        return this >= 2;
    }

    /** Returns `0.0` if the overflow mode would cause the automatic minimum size of a flexbox or CSS Grid item to be 0, else null */
    public inline function maybeIntoAutomaticMinSize():Null<Float> {
        return isScrollContainer() ? 0.0 : null;
    }

    /** Parse a CSS keyword, or return null */
    public static function parse(input:String):Null<Overflow> {
        return switch (StringTools.trim(input).toLowerCase()) {
            case "visible": Visible;
            case "hidden": Hidden;
            case "clip": Clip;
            case "scroll": Scroll;
            case _: null;
        }
    }

}
