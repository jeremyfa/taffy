// Ported from taffy 0.15.0: src/tree/layout.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

import taffy.compute.grid.DetailedGridInfo;

/**
 * The additional information from layout algorithm
 */
enum DetailedLayoutInfo {

    /** Detailed information about a grid container */
    Grid(info:DetailedGridInfo);

    /** For node that hasn't had any detailed information yet */
    None;

}
