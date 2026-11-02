// Ported from taffy 0.15.0: src/tree/traits.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

import taffy.geometry.AbsoluteAxis;
import taffy.geometry.LineOf;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.AvailableSpace;
import taffy.style.Style;
import taffy.geometry.SizeOpt;
import taffy.geometry.SizeAvail;

/**
 * Any type that implements `LayoutPartialTree` can be laid out using Taffy's algorithms.
 *
 * Taffy's algorithm implementations have been designed such that they can be used for laying out a single
 * node that only has access to its immediate children.
 *
 * In Rust, the style accessors return associated types implementing the style traits.
 * In this port they return the concrete `Style` class.
 */
interface LayoutPartialTree extends TraversePartialTree {

    /**
     * Get core style. Only called for the node being laid out, never for its children
     * (those go through the `get*ChildStyle` methods).
     */
    function getCoreContainerStyle(nodeId:NodeId):Style;

    /** Set the node's unrounded layout */
    function setUnroundedLayout(nodeId:NodeId, layout:Layout):Void;

    /** Compute the specified node's size or full layout given the specified constraints */
    function computeChildLayout(nodeId:NodeId, inputs:LayoutInput):LayoutOutput;

}

/**
 * Convenience methods for `LayoutPartialTree` (Rust `LayoutPartialTreeExt`).
 * Use with `using taffy.tree.LayoutPartialTree;`.
 */
class LayoutPartialTreeExt {

    static final DEFINITE_BOTH:SizeOf<Bool> = new SizeOf<Bool>(true, true);

    /** Compute the size of the node given the specified constraints */
    public static function measureChildSize(
        tree:LayoutPartialTree,
        nodeId:NodeId,
        knownDimensions:SizeOpt,
        parentSize:SizeOpt,
        availableSpace:SizeAvail,
        sizingMode:SizingMode,
        axis:AbsoluteAxis,
        verticalMarginsAreCollapsible:LineOf<Bool>
    ):Float {
        final output = tree.computeChildLayout(nodeId, LayoutInput.acquire(ComputeSize, sizingMode, RequestedAxis.fromAbsoluteAxis(axis), knownDimensions, DEFINITE_BOTH, parentSize, availableSpace, verticalMarginsAreCollapsible));
        LayoutInput.release();
        return output.size.getAbs(axis);
    }

    /** Compute the size of the node given the specified constraints */
    public static function measureChildSizeBoth(
        tree:LayoutPartialTree,
        nodeId:NodeId,
        knownDimensions:SizeOpt,
        parentSize:SizeOpt,
        availableSpace:SizeAvail,
        sizingMode:SizingMode,
        verticalMarginsAreCollapsible:LineOf<Bool>
    ):Size {
        final output = tree.computeChildLayout(nodeId, LayoutInput.acquire(ComputeSize, sizingMode, Both, knownDimensions, DEFINITE_BOTH, parentSize, availableSpace, verticalMarginsAreCollapsible));
        LayoutInput.release();
        return output.size;
    }

    /** Perform a full layout on the node given the specified constraints */
    public static function performChildLayout(
        tree:LayoutPartialTree,
        nodeId:NodeId,
        knownDimensions:SizeOpt,
        parentSize:SizeOpt,
        availableSpace:SizeAvail,
        sizingMode:SizingMode,
        verticalMarginsAreCollapsible:LineOf<Bool>
    ):LayoutOutput {
        final output = tree.computeChildLayout(nodeId, LayoutInput.acquire(PerformLayout, sizingMode, Both, knownDimensions, DEFINITE_BOTH, parentSize, availableSpace, verticalMarginsAreCollapsible));
        LayoutInput.release();
        return output;
    }

}
