// Ported from taffy 0.15.0: src/style/grid.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * Axis as `Row` or `Column`
 */
enum abstract GridAreaAxis(Int) {

    /** The `Row` axis */
    var Row = 0;

    /** The `Column` axis */
    var Column = 1;

}

/**
 * Logical end (`Start` or `End`)
 */
enum abstract GridAreaEnd(Int) {

    /** The `Start` end */
    var Start = 0;

    /** The `End` end */
    var End = 1;

}
