// Ported from taffy 0.15.0: src/tree/layout.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

import taffy.geometry.Line;
import taffy.style.AlignItems;
import taffy.style.AlignItemsKeyword;
import taffy.style.AlignmentSafety;

/**
 * The static position of an out-of-flow box in a single axis: the alignment container
 * (start/end coordinates) plus the alignment to apply to the box's margin box within it.
 *
 * Area coordinates are relative to the border box of the node currently holding the candidate.
 */
@:structInit
class AxisStaticPosition {

    /** The alignment container in this axis */
    public final area:Line;

    /** The alignment to apply to the box's margin box within `area` */
    public final align:AxisStaticAlign;

    public inline function new(area:Line, align:AxisStaticAlign) {
        this.area = area;
        this.align = align;
    }

    /** Create a `AxisStaticPosition` with a degenerate (zero-extent) area at `anchor` and no safe fallback */
    public static inline function fromEdge(anchor:Float, edge:AxisStaticEdge):AxisStaticPosition {
        return new AxisStaticPosition(new Line(anchor, anchor), AxisStaticAlign.fromKeyword(edge));
    }

    /**
     * Create a `AxisStaticPosition` which aligns the box within `area` according to its
     * self-alignment property in this axis. `normal` and `stretch` behave as `start`.
     *
     * `alignment` must already be resolved (no `auto`, no `self-start` / `self-end`).
     * `axisIsRtl` is whether this axis is the inline axis of a right-to-left static-position containing block.
     */
    public static function fromAlignment(alignment:AlignItems, area:Line, axisIsRtl:Bool):AxisStaticPosition {
        final fallback = alignment.safety == AlignmentSafety.Safe ? AlignItemsKeyword.Start : alignment.keyword;
        return new AxisStaticPosition(area, new AxisStaticAlign(edgeFor(alignment.keyword, axisIsRtl), alignment.safety, edgeFor(fallback, axisIsRtl)));
    }

    /** The edge of the static-position rectangle that a (resolved) alignment keyword aligns the box to */
    static function edgeFor(keyword:AlignItemsKeyword, axisIsRtl:Bool):AxisStaticEdge {
        final startPosition = !(keyword == AlignItemsKeyword.End || keyword == AlignItemsKeyword.FlexEnd) != axisIsRtl;
        if (keyword == AlignItemsKeyword.Center)
            return Center;
        return startPosition ? Start : End;
    }

    /** Return a copy translated by `offset` */
    public inline function translate(offset:Float):AxisStaticPosition {
        return new AxisStaticPosition(new Line(area.start + offset, area.end + offset), align);
    }

}
