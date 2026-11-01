// Ported from taffy 0.15.0: src/compute/block.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.block;

import taffy.compute.float.BfcSlot;
import taffy.compute.float.ContentSlot;
import taffy.geometry.Point;
import taffy.geometry.Size;
import taffy.style.Clear;
import taffy.style.Direction;
import taffy.style.FloatDirection;
import taffy.util.Sys;
import taffy.util.OptionalFloat;

/**
 * Context for each individual Block within a Block Formatting Context.
 *
 * Contains a reference to the BlockFormattingContext + block-specific data
 */
class BlockContext {

    /** A reference to the root BlockFormattingContext that this BlockContext belongs to */
    final bfc:BlockFormattingContext;

    /**
     * The y-offset of the border-top of the block node, relative to the to the border-top of the
     * root node of the Block Formatting Context it belongs to.
     */
    final yOffset:Float;

    /** The x-insets of the border-box in from each side of the block node, relative to the root node of the BFC */
    final insets:Array<Float>;

    /** The x-insets of the content box */
    final contentBoxInsets:Array<Float>;

    /** The height that floats take up in the element (`-Infinity` if the element's subtree does not contain any floats) */
    var floatContentContribution:Float = Math.NEGATIVE_INFINITY;

    /** Whether the node is the root of the Block Formatting Context is belongs to. */
    final isRoot:Bool;

    /**
     * Whether a float has been placed (on each side) whose position adjoins the current
     * margin-collapse strut of this block. Such floats force clearance on cleared elements
     * whose margins adjoin the same strut.
     */
    final adjoiningFloats:Array<Bool>;

    /**
     * The value of `adjoiningFloats` frozen at the first point at which in-flow content was
     * committed within this block. Null if no in-flow content has been committed yet.
     */
    var topAdjoiningFloats:Null<Array<Bool>> = null;

    @:allow(taffy.compute.block.BlockFormattingContext)
    function new(bfc:BlockFormattingContext, yOffset:Float, insetLeft:Float, insetRight:Float, isRoot:Bool, adjoiningLeft:Bool, adjoiningRight:Bool) {
        this.bfc = bfc;
        this.yOffset = yOffset;
        this.insets = [insetLeft, insetRight];
        this.contentBoxInsets = [insetLeft, insetRight];
        this.isRoot = isRoot;
        this.adjoiningFloats = [adjoiningLeft, adjoiningRight];
    }

    /** Create a sub-`BlockContext` for a child block node */
    public function subContext(additionalYOffset:Float, insetLeft:Float, insetRight:Float):BlockContext {
        // Floats adjoining the parent's current strut also adjoin this block's top strut
        return new BlockContext(bfc, yOffset + additionalYOffset, insets[0] + insetLeft, insets[1] + insetRight, false, adjoiningFloats[0], adjoiningFloats[1]);
    }

    /** Returns whether this block is the root block of it's Block Formatting Context */
    public inline function isBfcRoot():Bool {
        return isRoot;
    }

    /**
     * Set the width of the overall Block Formatting Context. This is used to resolve positions
     * that are relative to the right of the context such as right-floated boxes.
     */
    public inline function setWidth(availableWidth:Float):Void {
        bfc.floatContext.setWidth(availableWidth);
    }

    /**
     * Set the x-axis content-box insets of the `BlockContext`. These are the difference between the border-box
     * and the content-box of the box (padding + border + scrollbar gutter).
     */
    public inline function applyContentBoxInset(left:Float, right:Float):Void {
        contentBoxInsets[0] = insets[0] + left;
        contentBoxInsets[1] = insets[1] + right;
    }

    /** Whether the float context contains any floats */
    public inline function hasFloats():Bool {
        return bfc.floatContext.hasFloats();
    }

    /** Whether the float context contains any floats that extend to or below minY */
    public inline function hasActiveFloats(minY:Float):Bool {
        return bfc.floatContext.hasActiveFloats(minY + yOffset);
    }

    /** Position a floated box with the context */
    public function placeFloatedBox(floatedBox:Size, minY:Float, direction:FloatDirection, clear:Clear, adjoinsUnresolvedStrut:Bool):Point {
        if (adjoinsUnresolvedStrut) {
            adjoiningFloats[(direction : Int)] = true;
        }
        final pos = bfc.floatContext.placeFloatedBox(floatedBox, minY + yOffset, contentBoxInsets, direction, clear);
        final y = pos.y - yOffset;
        final x = pos.x - insets[0];
        floatContentContribution = Sys.f32Max(floatContentContribution, y + floatedBox.height);
        return new Point(x, y);
    }

    /** Search a space suitable for laying out non-floated content into (`after` is a segment id or -1) */
    public function findContentSlot(minY:Float, clear:Clear, after:Int):ContentSlot {
        final slot = bfc.floatContext.findContentSlot(minY + yOffset, contentBoxInsets, clear, after);
        slot.y -= yOffset;
        slot.x -= insets[0];
        return slot;
    }

    /** Search for a space suitable for laying out a box that establishes an independent formatting context */
    public function findBfcSlot(minY:Float, marginLeft:Float, marginRight:Float, direction:Direction, clear:Clear, after:Int):BfcSlot {
        final slot = bfc.floatContext.findBfcSlot(minY + yOffset, contentBoxInsets, [marginLeft, marginRight], direction, clear, after);
        slot.y -= yOffset;
        slot.x -= insets[0];
        return slot;
    }

    /** Get the bottom of lowest relevant float for the specific clear property */
    public function clearedThreshold(clear:Clear):OptionalFloat {
        final threshold = bfc.floatContext.clearedThreshold(clear);
        return threshold.isSome() ? OptionalFloat.some(threshold.unwrap() - yOffset) : OptionalFloat.NONE;
    }

    /** Whether a float that is adjoining the current margin-collapse strut has been placed on the relevant side(s) */
    public function hasAdjoiningFloat(clear:Clear):Bool {
        return switch clear {
            case Clear.Left: adjoiningFloats[0];
            case Clear.Right: adjoiningFloats[1];
            case Clear.Both: adjoiningFloats[0] || adjoiningFloats[1];
            case Clear.None: false;
        }
    }

    /** Merge adjoining float flags propagated from a child block into this block's flags */
    public inline function mergeAdjoiningFloats(flags:Array<Bool>):Void {
        adjoiningFloats[0] = adjoiningFloats[0] || flags[0];
        adjoiningFloats[1] = adjoiningFloats[1] || flags[1];
    }

    /**
     * Record that in-flow content has been committed within this block, resolving the position of
     * the current margin-collapse strut. The flags for the block's top strut are frozen at the first commit.
     */
    public function commitStrut():Void {
        if (topAdjoiningFloats == null) {
            topAdjoiningFloats = [adjoiningFloats[0], adjoiningFloats[1]];
        }
        adjoiningFloats[0] = false;
        adjoiningFloats[1] = false;
    }

    /** The adjoining float flags for this block's top margin strut */
    public function getTopAdjoiningFloats():Array<Bool> {
        return topAdjoiningFloats != null ? topAdjoiningFloats : adjoiningFloats;
    }

    /** Update the height that descendent floats consume with the height that floats consume within a particular child */
    public inline function addChildFloatedContentHeightContribution(childContribution:Float):Void {
        floatContentContribution = Sys.f32Max(floatContentContribution, childContribution);
    }

    /** Returns the height that descendent floats consume */
    public inline function floatedContentHeightContribution():Float {
        return floatContentContribution;
    }

}
