// New code for the Haxe port of taffy (no taffy origin). See LICENSE.

package taffy.tree;

import taffy.style.Style;

/**
 * The measure function of `TaffyTree.computeLayoutWithMeasure()` as an
 * object (`TaffyTree.computeLayoutWithMeasurer()`): a call through an
 * interface is typed, where a call through a function value passes its
 * arguments as `Dynamic` on hxcpp (the node id is boxed on every leaf).
 * `nodeContext` is null for a node without context (typed `NodeContext`,
 * not `Null<NodeContext>`: hxcs cannot implement a generic interface method
 * taking `Null<T>` with a concrete type).
 */
interface LayoutMeasurer<NodeContext> {

    function measureLeafNode(inputs:LayoutInput, nodeId:NodeId, nodeContext:NodeContext, style:Style):LayoutOutput;

}
