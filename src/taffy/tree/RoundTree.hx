// Ported from taffy 0.15.0: src/tree/traits.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

/**
 * Interface used by `Compute.roundLayout` which takes a tree of unrounded float-valued layouts and performs
 * rounding to snap the values to the pixel grid.
 */
interface RoundTree extends TraverseTree {

    /** Get the node's unrounded layout */
    function getUnroundedLayout(nodeId:NodeId):Layout;

    /** Set the node's final layout */
    function setFinalLayout(nodeId:NodeId, layout:Layout):Void;

    /**
     * Whether the node is an out-of-flow (absolute/fixed) box. Out-of-flow boxes are visited
     * via their containing block's hoisted child list.
     */
    function isOutOfFlow(nodeId:NodeId):Bool;

    /** The number of out-of-flow boxes whose containing block is `nodeId` */
    function hoistedChildCount(nodeId:NodeId):Int;

    /** Get the nth out-of-flow box whose containing block is `nodeId` */
    function getHoistedChildId(nodeId:NodeId, index:Int):NodeId;

}
