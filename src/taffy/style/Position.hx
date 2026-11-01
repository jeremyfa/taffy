// Ported from taffy 0.15.0: src/style/mod.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * The positioning strategy for this item (CSS `position`).
 *
 * The default value of `Style.position` is `Static`.
 */
enum abstract Position(Int) {

    /** The offset is computed relative to the final position given by the layout algorithm. Insets have no effect. */
    var Static = 0;

    /** The offset is computed relative to the final position given by the layout algorithm. */
    var Relative = 1;

    /** The node is taken out of the normal flow and positioned relative to its containing block. */
    var Absolute = 2;

    /** The node is taken out of the normal flow and positioned relative to the initial containing block. */
    var Fixed = 3;

    /** Treated as `Relative` by this implementation. */
    var Sticky = 4;

    /** Whether the position takes the box out of flow (`Absolute` or `Fixed`) */
    public inline function isOutOfFlow():Bool {
        return this == 2 || this == 3;
    }

    /** Whether the position is not `Static` */
    public inline function isPositioned():Bool {
        return this != 0;
    }

    /** Parse a CSS keyword, or return null */
    public static function parse(input:String):Null<Position> {
        return switch (StringTools.trim(input).toLowerCase()) {
            case "static": Static;
            case "relative": Relative;
            case "absolute": Absolute;
            case "fixed": Fixed;
            case "sticky": Sticky;
            case _: null;
        }
    }

}
