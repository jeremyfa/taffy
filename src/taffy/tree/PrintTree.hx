// Ported from taffy 0.15.0: src/tree/traits.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

/**
 * Interface used by `PrintTree.printTree` which prints a debug representation.
 */
interface PrintTree extends TraverseTree {

    /** Get a debug label for the node (typically the type of node: flexbox, grid, text, image, etc) */
    function getDebugLabel(nodeId:NodeId):String;

    /** Get the node's final layout */
    function getFinalLayout(nodeId:NodeId):Layout;

}
