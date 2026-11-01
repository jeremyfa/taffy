// Ported from taffy 0.15.0: src/tree/traits.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

import taffy.style.Style;

/**
 * Extends `LayoutPartialTree` with the operations needed by the out-of-flow positioning pass
 * (`Oof.computeOofLayout`), which lays out the absolute/fixed boxes for which a node acts as the containing block.
 */
interface LayoutContainingBlock extends LayoutPartialTree {

    /** Get the style of an out-of-flow box being positioned by its containing block */
    function getOofItemStyle(nodeId:NodeId):Style;

    /**
     * Clear the list of out-of-flow boxes whose containing block is `nodeId`.
     * Called once for each node laid out with `PerformLayout`, before `addHoistedChildren`.
     */
    function clearHoistedChildren(nodeId:NodeId):Void;

    /** Append to the list of out-of-flow boxes whose containing block is `nodeId` */
    function addHoistedChildren(nodeId:NodeId, hoisted:Array<NodeId>):Void;

    /**
     * Read back the detailed layout information most recently recorded for `nodeId`.
     * Return `DetailedLayoutInfo.None` if not supported.
     */
    function getDetailedLayoutInfo(nodeId:NodeId):DetailedLayoutInfo;

}
