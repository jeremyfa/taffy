// Ported from taffy 0.15.0: src/tree/traits.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

import taffy.style.Style;

/**
 * Extends `LayoutPartialTree` with getters for the styles required for Flexbox layout
 */
interface LayoutFlexboxContainer extends LayoutPartialTree {

    /** Get the container's styles */
    function getFlexboxContainerStyle(nodeId:NodeId):Style;

    /** Get the child's styles */
    function getFlexboxChildStyle(childNodeId:NodeId):Style;

}
