// Ported from taffy 0.15.0: src/tree/layout.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

/**
 * Whether styles should be taken into account when computing size
 */
enum abstract SizingMode(Int) {

    /** Only content contributions should be taken into account */
    var ContentSize = 0;

    /** Inherent size styles should be taken into account in addition to content contributions */
    var InherentSize = 1;

}
