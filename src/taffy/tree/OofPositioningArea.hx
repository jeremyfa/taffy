// Ported from taffy 0.15.0: src/tree/layout.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

import taffy.geometry.Point;
import taffy.geometry.Size;

/**
 * The area of a container against which the insets of its out-of-flow (absolute/fixed) boxes
 * are resolved: the container's border box minus its borders and scrollbar gutters.
 */
@:structInit
class OofPositioningArea {

    /** The size of the area */
    public final size:Size;

    /** The offset of the area from the container's border box origin */
    public final offset:Point;

    public inline function new(size:Size, offset:Point) {
        this.size = size;
        this.offset = offset;
    }

}
