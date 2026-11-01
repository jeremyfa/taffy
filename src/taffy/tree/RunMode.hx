// Ported from taffy 0.15.0: src/tree/layout.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

/**
 * Whether we are performing a full layout, or we merely need to size the node
 */
enum abstract RunMode(Int) {

    /** A full layout for this node and all children should be computed */
    var PerformLayout = 0;

    /** The layout algorithm should be executed such that an accurate container size for the node can be determined. */
    var ComputeSize = 1;

    /** This node should have a null layout set as it has been hidden (i.e. using `Display.None`) */
    var PerformHiddenLayout = 2;

}
