// Ported from taffy 0.15.0: src/geometry.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.geometry;

/**
 * The simple absolute horizontal and vertical axis
 */
enum abstract AbsoluteAxis(Int) {

    /** The horizontal axis */
    var Horizontal = 0;

    /** The vertical axis */
    var Vertical = 1;

    /** Returns the other variant of the enum */
    public inline function otherAxis():AbsoluteAxis {
        return this == 0 ? Vertical : Horizontal;
    }

}
