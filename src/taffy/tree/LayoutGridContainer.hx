// Ported from taffy 0.15.0: src/tree/traits.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

import taffy.compute.grid.DetailedGridInfo;
import taffy.style.Style;

/**
 * Extends `LayoutPartialTree` with getters for the styles required for CSS Grid layout
 */
interface LayoutGridContainer extends LayoutPartialTree {

    /** Get the container's styles */
    function getGridContainerStyle(nodeId:NodeId):Style;

    /** Get the child's styles */
    function getGridChildStyle(childNodeId:NodeId):Style;

    /**
     * Set the node's detailed grid information. Implementing this method is optional
     * (an empty implementation is fine).
     */
    function setDetailedGridInfo(nodeId:NodeId, detailedGridInfo:DetailedGridInfo):Void;

}
