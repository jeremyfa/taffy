// Ported from taffy 0.15.0: src/style/float.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * The direction of a float (only the floated variants of `CssFloat`)
 */
enum abstract FloatDirection(Int) to Int {

    /** Floated to the left */
    var Left = 0;

    /** Floated to the right */
    var Right = 1;

}
