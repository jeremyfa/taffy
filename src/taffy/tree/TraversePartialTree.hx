// Ported from taffy 0.15.0: src/tree/traits.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

/**
 * Taffy's abstraction for downward tree traversal.
 *
 * This interface does *not* require access to any node's other than a single container node's immediate children
 * unless you also intend to implement `TraverseTree`.
 */
interface TraversePartialTree {

    /** Get the list of children IDs for the given node (prefer `childCount` / `getChildId` in hot paths) */
    function childIds(parentNodeId:NodeId):Array<NodeId>;

    /** Get the number of children for the given node */
    function childCount(parentNodeId:NodeId):Int;

    /** Get a specific child of a node, where the index represents the nth child */
    function getChildId(parentNodeId:NodeId, childIndex:Int):NodeId;

}
