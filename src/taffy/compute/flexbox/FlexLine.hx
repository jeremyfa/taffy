// Ported from taffy 0.15.0: src/compute/flexbox.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.flexbox;

/**
 * A line of `FlexItem` used for intermediate computation
 */
class FlexLine {

    /** The items of this line (a contiguous run of the container's items, in document order) */
    public var items:Array<FlexItem>;

    /** The dimensions of the cross-axis */
    public var crossSize:Float = 0.0;

    /** The relative offset of the cross-axis */
    public var offsetCross:Float = 0.0;

    public inline function new(items:Array<FlexItem>) {
        this.items = items;
    }

}
