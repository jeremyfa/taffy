// Ported from taffy 0.15.0: src/geometry.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.geometry;

/**
 * The CSS abstract axis
 * https://www.w3.org/TR/css-writing-modes-3/#abstract-axes
 */
enum abstract AbstractAxis(Int) {

    /** The axis in the inline dimension, i.e. the horizontal axis in horizontal writing modes and the vertical axis in vertical writing modes. */
    var Inline = 0;

    /** The axis in the block dimension, i.e. the vertical axis in horizontal writing modes and the horizontal axis in vertical writing modes. */
    var Block = 1;

    /** Returns the other variant of the enum */
    public inline function other():AbstractAxis {
        return this == 0 ? Block : Inline;
    }

    /** Convert an `AbstractAxis` into an `AbsoluteAxis` naively assuming that the Inline axis is Horizontal */
    public inline function asAbsNaive():AbsoluteAxis {
        return this == 0 ? Horizontal : Vertical;
    }

}
