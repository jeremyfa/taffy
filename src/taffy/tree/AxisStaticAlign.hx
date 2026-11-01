// Ported from taffy 0.15.0: src/tree/layout.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

import taffy.style.AlignmentSafety;

/**
 * The alignment to apply to an out-of-flow box's margin box within its static-position area in a single axis.
 *
 * Keywords are physical: container-specific semantics are resolved by the emitting layout algorithm.
 */
@:structInit
class AxisStaticAlign {

    /** The physical alignment keyword */
    public final keyword:AxisStaticEdge;

    /** The `safe` overflow-position keyword: when `Safe`, `fallback` is used if the box's margin box overflows the area */
    public final safety:AlignmentSafety;

    /** The physical alignment keyword to fall back to when `safety` is `Safe` and the box overflows the area */
    public final fallback:AxisStaticEdge;

    public inline function new(keyword:AxisStaticEdge, safety:AlignmentSafety, fallback:AxisStaticEdge) {
        this.keyword = keyword;
        this.safety = safety;
        this.fallback = fallback;
    }

    /** Create a `AxisStaticAlign` from a keyword with no safe fallback */
    public static inline function fromKeyword(keyword:AxisStaticEdge):AxisStaticAlign {
        return new AxisStaticAlign(keyword, AlignmentSafety.Default, keyword);
    }

}
