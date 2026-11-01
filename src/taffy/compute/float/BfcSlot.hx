// Ported from taffy 0.15.0: src/compute/float.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.float;

/**
 * An empty "slot" that avoids floats that is suitable for a box that establishes
 * an independent formatting context (and therefore must not overlap floats) to be
 * laid out into. Unlike `ContentSlot`, this accounts for the box's own margins,
 * which are resolved against the containing block's edges (not float edges) and
 * may therefore overlap floats.
 */
class BfcSlot {

    /** The id of the segment that the slot starts in (-1 for none) */
    public var segmentId:Int;

    /** The x position of the start of the slot (border box edge) */
    public var x:Float;

    /** The y position of the start of the slot */
    public var y:Float;

    /**
     * The space available for the box's border box: the space between float edges
     * and the margin-inset containing block edges.
     */
    public var borderWidth:Float;

    /**
     * The width that an auto width resolves to (before applying min/max constraints and
     * the negative-margin lower bound).
     */
    public var stretchWidth:Float;

    public inline function new(segmentId:Int, x:Float, y:Float, borderWidth:Float, stretchWidth:Float) {
        this.segmentId = segmentId;
        this.x = x;
        this.y = y;
        this.borderWidth = borderWidth;
        this.stretchWidth = stretchWidth;
    }

}
