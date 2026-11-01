// Ported from taffy 0.15.0: src/style/mod.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * Sets the layout used for the children of this node.
 *
 * The default value is `Flex`.
 */
enum abstract Display(Int) {

    /** The children will follow the block layout algorithm */
    var Block = 0;

    /** The children will follow the block layout algorithm, and the node establishes a new block formatting context */
    var FlowRoot = 1;

    /** The children will follow the flexbox layout algorithm */
    var Flex = 2;

    /** The children will follow the CSS Grid layout algorithm */
    var Grid = 3;

    /** The node is hidden, and it's children will also be hidden */
    var None = 4;

    /** The default display mode */
    public static inline final DEFAULT:Display = Flex;

    /** Parse a CSS keyword, or return null */
    public static function parse(input:String):Null<Display> {
        return switch (StringTools.trim(input).toLowerCase()) {
            case "none": None;
            case "flex": Flex;
            case "grid": Grid;
            case "block": Block;
            case "flow-root": FlowRoot;
            case _: null;
        }
    }

    public function toString():String {
        return switch (cast this : Display) {
            case Block: "BLOCK";
            case FlowRoot: "FLOW-ROOT";
            case Flex: "FLEX";
            case Grid: "GRID";
            case None: "NONE";
        }
    }

}
