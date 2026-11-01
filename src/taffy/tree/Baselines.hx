// Ported from taffy 0.15.0: src/tree/layout.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

/**
 * The first and last baselines of a node in the horizontal axis (i.e. baselines for horizontal text,
 * measured as an offset from the top edge of the node's border box).
 */
@:structInit
class Baselines {

    /** A `Baselines` with neither a first nor a last baseline */
    public static final NONE:Baselines = new Baselines(null, null);

    /** The first baseline of the node, if any */
    public final first:Null<Float>;

    /** The last baseline of the node, if any */
    public final last:Null<Float>;

    public inline function new(first:Null<Float>, last:Null<Float>) {
        this.first = first;
        this.last = last;
    }

    /** Create a `Baselines` from just a first baseline */
    public static inline function fromFirst(first:Null<Float>):Baselines {
        return first == null ? NONE : new Baselines(first, null);
    }

}
