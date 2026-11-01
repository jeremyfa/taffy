// Ported from taffy 0.15.0: src/tree/layout.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

import taffy.geometry.AbsoluteAxis;

/**
 * An axis that layout algorithms can be requested to compute a size for
 */
enum abstract RequestedAxis(Int) {

    /** The horizontal axis */
    var Horizontal = 0;

    /** The vertical axis */
    var Vertical = 1;

    /** Both axes */
    var Both = 2;

    /** Swap the horizontal and vertical axes (`Both` is unchanged) */
    public inline function transpose():RequestedAxis {
        return this == 0 ? Vertical : (this == 1 ? Horizontal : Both);
    }

    /** Convert from an `AbsoluteAxis` */
    @:from public static inline function fromAbsoluteAxis(axis:AbsoluteAxis):RequestedAxis {
        return axis == AbsoluteAxis.Horizontal ? Horizontal : Vertical;
    }

}
