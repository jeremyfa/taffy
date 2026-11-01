// Ported from taffy 0.15.0: src/tree/layout.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

/**
 * The physical alignment of an out-of-flow box's margin box within its static-position area (per-axis).
 */
enum abstract AxisStaticEdge(Int) {

    /** Align the start (left/top) edge of the box's margin box to the start of the area */
    var Start = 0;

    /** Center the box within the area */
    var Center = 1;

    /** Align the end (right/bottom) edge of the box's margin box to the end of the area */
    var End = 2;

}
