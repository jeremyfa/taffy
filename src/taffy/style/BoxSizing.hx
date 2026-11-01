// Ported from taffy 0.15.0: src/style/mod.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * Specifies whether size styles for this node are assigned to the node's "content box" or "border box".
 *
 * The default value is `BorderBox`.
 */
enum abstract BoxSizing(Int) {

    /** Size styles such size, min_size, max_size specify the box's "border box" */
    var BorderBox = 0;

    /** Size styles such size, min_size, max_size specify the box's "content box" */
    var ContentBox = 1;

    /** Parse a CSS keyword, or return null */
    public static function parse(input:String):Null<BoxSizing> {
        return switch (StringTools.trim(input).toLowerCase()) {
            case "border-box": BorderBox;
            case "content-box": ContentBox;
            case _: null;
        }
    }

}
