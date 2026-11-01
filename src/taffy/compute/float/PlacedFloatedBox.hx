// Ported from taffy 0.15.0: src/compute/float.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.float;

/**
 * A floated box
 */
class PlacedFloatedBox {

    /** The width of the box */
    public var width:Float;

    /** The height of the box */
    public var height:Float;

    /** Horizontal distance from the edge of the container that the box is floated towards */
    public var xInset:Float;

    /** Vertical distance from top edge of the container */
    public var y:Float;

    public inline function new(width:Float, height:Float, xInset:Float, y:Float) {
        this.width = width;
        this.height = height;
        this.xInset = xInset;
        this.y = y;
    }

}
