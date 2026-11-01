// Ported from taffy 0.15.0: src/compute/float.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.float;

/**
 * An empty "slot" that avoids floats that is suitable for non-floated content to be laid out into
 */
class ContentSlot {

    /** The id of the segment that the slot starts in (-1 for none) */
    public var segmentId:Int;

    /** The x position of the start of the slot */
    public var x:Float;

    /** The y position of the start of the slot */
    public var y:Float;

    /** The width of the slot */
    public var width:Float;

    /** The height of the slot */
    public var height:Float;

    public inline function new(segmentId:Int, x:Float, y:Float, width:Float, height:Float) {
        this.segmentId = segmentId;
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
    }

}
