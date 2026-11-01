// Ported from taffy 0.15.0: src/tree/traits.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

import taffy.compute.block.BlockContext;
import taffy.style.Style;

/**
 * Extends `LayoutPartialTree` with getters for the styles required for CSS Block layout
 */
interface LayoutBlockContainer extends LayoutPartialTree {

    /** Get the container's styles */
    function getBlockContainerStyle(nodeId:NodeId):Style;

    /** Get the child's styles */
    function getBlockChildStyle(childNodeId:NodeId):Style;

    /**
     * Compute the specified node's size or full layout given the specified constraints.
     * Implementations that do not support block contexts can just call `computeChildLayout`.
     */
    function computeBlockChildLayout(nodeId:NodeId, inputs:LayoutInput, blockCtx:Null<BlockContext>):LayoutOutput;

}
