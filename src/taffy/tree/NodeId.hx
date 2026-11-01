// Ported from taffy 0.15.0: src/tree/node.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

/**
 * A type representing the id of a single node in a tree of nodes.
 *
 * Internally it is a wrapper around an `Int` (an index in `TaffyTree`).
 */
abstract NodeId(Int) from Int to Int {

    /** Create a new NodeId from an Int value */
    public inline function new(val:Int) {
        this = val;
    }

    public inline function toString():String {
        return 'NodeId($this)';
    }

}
