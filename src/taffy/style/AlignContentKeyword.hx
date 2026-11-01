// Ported from taffy 0.15.0: src/style/alignment.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * The positional or distributed keyword of an `align-content` / `justify-content` value
 */
enum abstract AlignContentKeyword(Int) to Int {

    /** Behaves differently depending on the layout mode */
    var Normal = 0;
    /** Items are packed toward the start of the axis */
    var Start = 1;
    /** Items are packed toward the end of the axis */
    var End = 2;
    /** Items are packed towards the flex-relative start of the axis */
    var FlexStart = 3;
    /** Items are packed towards the flex-relative end of the axis */
    var FlexEnd = 4;
    /** Items are centered around the middle of the axis */
    var Center = 5;
    /** Items are stretched to fill the container */
    var Stretch = 6;
    /** The first and last items are aligned flush with the edges of the container */
    var SpaceBetween = 7;
    /** The gap between items and edges is distributed evenly */
    var SpaceEvenly = 8;
    /** Each item has half sized gaps on the outsides */
    var SpaceAround = 9;

    /** Reverse the keyword (start and end are swapped, stretch becomes end) */
    public inline function reversed():AlignContentKeyword {
        return switch (cast this : AlignContentKeyword) {
            case Start: End;
            case End: Start;
            case FlexStart: FlexEnd;
            case FlexEnd: FlexStart;
            case Stretch: End;
            case other: other;
        }
    }

}
