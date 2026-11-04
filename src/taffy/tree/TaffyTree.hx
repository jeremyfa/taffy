// Ported from taffy 0.15.0: src/tree/taffy_tree.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

import taffy.compute.BlockLayout;
import taffy.compute.Compute;
import taffy.compute.FlexboxLayout;
import taffy.compute.GridLayout;
import taffy.compute.Leaf;
import taffy.compute.Oof;
import taffy.compute.block.BlockContext;
import taffy.compute.grid.DetailedGridInfo;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.AvailableSpace;
import taffy.style.Display;
import taffy.style.Style;
import taffy.geometry.SizeOpt;
import taffy.geometry.SizeAvail;

/**
 * The function used by `TaffyTree.computeLayoutWithMeasure` to lay out leaf nodes:
 * `(inputs, nodeId, nodeContext, style) -> output`. `nodeContext` is null for nodes without context.
 * It usually calls `Leaf.computeLeafLayout`.
 */
typedef MeasureFunction<NodeContext> = (inputs:LayoutInput, nodeId:NodeId, nodeContext:Null<NodeContext>, style:Style) -> LayoutOutput;

/**
 * An error that occurs while trying to access or modify a node's children by index.
 */
enum TaffyError {

    /** The parent node does not have a child at `childIndex`. It only has `childCount` children */
    ChildIndexOutOfBounds(parent:NodeId, childIndex:Int, childCount:Int);

    /** The parent node was not found in the `TaffyTree` instance. */
    InvalidParentNode(parent:NodeId);

    /** The child node was not found in the `TaffyTree` instance. */
    InvalidChildNode(child:NodeId);

    /** The supplied node was not found in the `TaffyTree` instance. */
    InvalidInputNode(node:NodeId);

}

/**
 * Layout information for a given node, stored in a `TaffyTree`
 */
@:allow(taffy.tree.TaffyTree)
@:allow(taffy.tree.TaffyView)
class NodeData<NodeContext> {

    /** The layout strategy used by this node */
    public var style:Style;

    /** The always unrounded results of the layout computation. */
    public var unroundedLayout:Layout = Layout.ZERO;

    /** The final results of the layout computation (rounded if rounding is enabled). */
    public var finalLayout:Layout = Layout.ZERO;

    /** Whether the node has context data associated with it or not */
    public var hasContext:Bool = false;

    /** The context data of the node (when `hasContext` is true) */
    public var context:Null<NodeContext> = null;

    /** The out-of-flow (absolute/fixed) boxes whose containing block is this node */
    public var hoistedChildren:Array<NodeId> = [];

    /** The cached results of the layout computation */
    public final cache:Cache = new Cache();

    /** The detailed layout information (grid tracks...) */
    public var detailedLayoutInfo:DetailedLayoutInfo = DetailedLayoutInfo.None;

    /** The children of the node */
    public var children:Array<NodeId> = [];

    /** The parent of the node, or -1 */
    public var parent:Int = -1;

    public function new(style:Style) {
        this.style = style;
    }

    /** Marks a node and all of its ancestors as requiring relayout */
    public inline function markDirty():ClearState {
        return cache.clear();
    }

}

/**
 * An entire tree of UI nodes. The entry point to Taffy's high-level API.
 *
 * Allows you to build a tree of UI nodes, run Taffy's layout algorithms over that tree, and then access the resultant layout.
 *
 * `NodeContext` is the type of the data associated with leaf nodes (passed to the measure function).
 *
 * Node ids are indices into an internal array. Removed ids are reused: do not keep ids of removed nodes.
 * Errors are thrown as `TaffyError` values (Rust returns `TaffyResult`).
 */
@:allow(taffy.tree.TaffyView)
class TaffyTree<NodeContext> {

    /** The nodes in the tree (null for free slots) */
    var nodes:Array<NodeData<NodeContext>> = [];

    /** Free slots in `nodes` */
    var freeIds:Array<Int> = [];

    /** The number of nodes in the tree */
    var nodeCount:Int = 0;

    /** Whether layouts are rounded to whole pixels */
    var useRounding:Bool = true;

    /** The view used to run layout (reused between runs) */
    var view:Null<TaffyView<NodeContext>> = null;

    /** Creates a new `TaffyTree` */
    public function new() {}

    /** Enable rounding of layout values. Rounding is enabled by default. */
    public function enableRounding():Void {
        useRounding = true;
    }

    /** Disable rounding of layout values. Rounding is enabled by default. */
    public function disableRounding():Void {
        useRounding = false;
    }

    inline function node(id:NodeId):NodeData<NodeContext> {
        final n = nodes[id];
        if (n == null)
            throw InvalidInputNode(id);
        return n;
    }

    function insert(data:NodeData<NodeContext>):NodeId {
        nodeCount++;
        if (freeIds.length > 0) {
            // Not `pop()`: on hxcpp it returns the Int boxed (allocated above 255)
            final last = freeIds.length - 1;
            final id = freeIds[last];
            freeIds.resize(last);
            nodes[id] = data;
            return id;
        }
        nodes.push(data);
        return nodes.length - 1;
    }

    /** Creates and adds a new unattached leaf node to the tree, and returns the node of the new node */
    public function newLeaf(layout:Style):NodeId {
        return insert(new NodeData<NodeContext>(layout));
    }

    /**
     * Creates and adds a new unattached leaf node to the tree, and returns the `NodeId` of the new node.
     * Creates and associates a context with the node.
     */
    public function newLeafWithContext(layout:Style, context:NodeContext):NodeId {
        final data = new NodeData<NodeContext>(layout);
        data.hasContext = true;
        data.context = context;
        return insert(data);
    }

    /** Creates and adds a new node, which may have any number of `children` */
    public function newWithChildren(layout:Style, children:Array<NodeId>):NodeId {
        final data = new NodeData<NodeContext>(layout);
        final id = insert(data);
        for (child in children) {
            node(child).parent = id;
        }
        data.children = children.copy();
        return id;
    }

    /** Drops all nodes in the tree */
    public function clear():Void {
        nodes = [];
        freeIds = [];
        nodeCount = 0;
    }

    /**
     * Remove a specific node from the tree and drop it.
     * Returns the id of the node removed.
     */
    public function remove(nodeId:NodeId):NodeId {
        final data = node(nodeId);
        // Remove self from parent's children list
        if (data.parent != -1) {
            final parentData = nodes[data.parent];
            if (parentData != null) {
                parentData.children.remove(nodeId);
                markDirty(data.parent);
            }
        }
        // Remove "parent" references to a node when removing that node
        for (child in data.children) {
            final c = nodes[child];
            if (c != null)
                c.parent = -1;
        }
        nodes[nodeId] = null;
        freeIds.push(nodeId);
        nodeCount--;
        return nodeId;
    }

    /** Sets the context data associated with the node (null removes it) */
    public function setNodeContext(nodeId:NodeId, measure:Null<NodeContext>):Void {
        final data = node(nodeId);
        if (measure != null) {
            data.hasContext = true;
            data.context = measure;
        }
        else {
            data.hasContext = false;
            data.context = null;
        }
        markDirty(nodeId);
    }

    /** Gets the context data associated with the node */
    public function getNodeContext(nodeId:NodeId):Null<NodeContext> {
        final data = node(nodeId);
        return data.hasContext ? data.context : null;
    }

    /** Adds a `child` node under the supplied `parent` */
    public function addChild(parent:NodeId, child:NodeId):Void {
        node(child).parent = parent;
        node(parent).children.push(child);
        markDirty(parent);
    }

    /**
     * Inserts a `child` node at the given `childIndex` under the supplied `parent`, shifting all children after it to the right.
     */
    public function insertChildAtIndex(parent:NodeId, childIndex:Int, child:NodeId):Void {
        final parentData = node(parent);
        final childCount = parentData.children.length;
        if (childIndex > childCount)
            throw ChildIndexOutOfBounds(parent, childIndex, childCount);
        node(child).parent = parent;
        parentData.children.insert(childIndex, child);
        markDirty(parent);
    }

    /** Directly sets the `children` of the supplied `parent` */
    public function setChildren(parent:NodeId, children:Array<NodeId>):Void {
        final parentData = node(parent);
        // Remove node as parent from all its current children.
        for (child in parentData.children) {
            node(child).parent = -1;
        }
        // Build up relation node <-> child
        for (child in children) {
            // Remove child from previous parent
            final previousParent = node(child).parent;
            if (previousParent != -1) {
                removeChild(previousParent, child);
            }
            node(child).parent = parent;
        }
        parentData.children = children.copy();
        markDirty(parent);
    }

    /**
     * Removes the `child` of the parent `node`.
     * The child is not removed from the tree entirely, it is simply no longer attached to its previous parent.
     */
    public function removeChild(parent:NodeId, child:NodeId):NodeId {
        final index = node(parent).children.indexOf(child);
        if (index == -1)
            throw InvalidChildNode(child);
        return removeChildAtIndex(parent, index);
    }

    /**
     * Removes the child at the given `index` from the `parent`.
     * The child is not removed from the tree entirely, it is simply no longer attached to its previous parent.
     */
    public function removeChildAtIndex(parent:NodeId, childIndex:Int):NodeId {
        final parentData = node(parent);
        final childCount = parentData.children.length;
        if (childIndex >= childCount)
            throw ChildIndexOutOfBounds(parent, childIndex, childCount);
        final child = parentData.children.splice(childIndex, 1)[0];
        node(child).parent = -1;
        markDirty(parent);
        return child;
    }

    /**
     * Removes children at the given range from the `parent` (`start` inclusive, `end` exclusive).
     * Children are not removed from the tree entirely, they are simply no longer attached to their previous parent.
     */
    public function removeChildrenRange(parent:NodeId, start:Int, end:Int):Void {
        final parentData = node(parent);
        for (child in parentData.children.splice(start, end - start)) {
            node(child).parent = -1;
        }
        markDirty(parent);
    }

    /**
     * Replaces the child at the given `childIndex` from the `parent` node with the new `child` node.
     * The child is not removed from the tree entirely, it will simply no longer be attached to its previous parent.
     */
    public function replaceChildAtIndex(parent:NodeId, childIndex:Int, newChild:NodeId):NodeId {
        final parentData = node(parent);
        final childCount = parentData.children.length;
        if (childIndex >= childCount)
            throw ChildIndexOutOfBounds(parent, childIndex, childCount);
        node(newChild).parent = parent;
        final oldChild = parentData.children[childIndex];
        parentData.children[childIndex] = newChild;
        node(oldChild).parent = -1;
        markDirty(parent);
        return oldChild;
    }

    /** Returns the child node of the parent `node` at the provided `childIndex` */
    public function childAtIndex(parent:NodeId, childIndex:Int):NodeId {
        final parentData = node(parent);
        final childCount = parentData.children.length;
        if (childIndex >= childCount)
            throw ChildIndexOutOfBounds(parent, childIndex, childCount);
        return parentData.children[childIndex];
    }

    /** Returns the total number of nodes in the tree */
    public function totalNodeCount():Int {
        return nodeCount;
    }

    /** Returns the `NodeId` of the parent node of the specified node (if it exists) */
    public function parent(childId:NodeId):Null<NodeId> {
        final p = node(childId).parent;
        return p == -1 ? null : p;
    }

    /** Returns a list of children that belong to the parent node */
    public function children(parent:NodeId):Array<NodeId> {
        return node(parent).children.copy();
    }

    /** Returns the number of children of the parent node */
    public function childCount(parent:NodeId):Int {
        return node(parent).children.length;
    }

    /**
     * Returns the out-of-flow (absolute/fixed) boxes whose containing block is `nodeId`, as recorded by the most recent layout.
     * Do not modify the returned array.
     */
    public function hoistedChildren(nodeId:NodeId):Array<NodeId> {
        return node(nodeId).hoistedChildren;
    }

    /** Sets the `style` of the provided `node` */
    public function setStyle(nodeId:NodeId, style:Style):Void {
        node(nodeId).style = style;
        markDirty(nodeId);
    }

    /** Gets the `style` of the provided `node`. Do not mutate it: use `setStyle` with a clone */
    public function style(nodeId:NodeId):Style {
        return node(nodeId).style;
    }

    /** Return this node layout relative to its parent */
    public function layout(nodeId:NodeId):Layout {
        final data = node(nodeId);
        return useRounding ? data.finalLayout : data.unroundedLayout;
    }

    /** Returns this node layout with unrounded values relative to its parent. */
    public function unroundedLayout(nodeId:NodeId):Layout {
        return node(nodeId).unroundedLayout;
    }

    /** Get the final layout (the rounded layout if rounding is enabled) */
    public function getFinalLayout(nodeId:NodeId):Layout {
        return layout(nodeId);
    }

    /** Get the "detailed layout info" for a node (grid tracks...) */
    public function detailedLayoutInfo(nodeId:NodeId):DetailedLayoutInfo {
        return node(nodeId).detailedLayoutInfo;
    }

    /** Marks the layout of this node and its ancestors as outdated */
    public function markDirty(nodeId:NodeId):Void {
        var current:Int = nodeId;
        while (current != -1) {
            final data = nodes[current];
            if (data == null)
                return;
            switch data.markDirty() {
                case AlreadyEmpty:
                    // Node was already marked as dirty. No need to visit ancestors
                    // as they should be marked as dirty already.
                    return;
                case Cleared:
                    current = data.parent;
            }
        }
    }

    /** Indicates whether the layout of this node needs to be recomputed */
    public function dirty(nodeId:NodeId):Bool {
        return node(nodeId).cache.isEmpty();
    }

    /** Updates the stored layout of the provided `node` and its children, using the given measure function for leaves */
    public function computeLayoutWithMeasure(nodeId:NodeId, availableSpace:SizeAvail, measureFunction:MeasureFunction<NodeContext>):Void {
        node(nodeId);
        var taffyView = view;
        if (taffyView == null) {
            taffyView = new TaffyView<NodeContext>(this);
            view = taffyView;
        }
        taffyView.measureFunction = measureFunction;
        Compute.computeRootLayout(taffyView, nodeId, availableSpace);
        if (useRounding) {
            Compute.roundLayout(taffyView, nodeId);
        }
        taffyView.measureFunction = null;
    }

    /** Updates the stored layout of the provided `node` and its children (leaves are measured as zero size) */
    public function computeLayout(nodeId:NodeId, availableSpace:SizeAvail):Void {
        computeLayoutWithMeasure(nodeId, availableSpace, defaultMeasure);
    }

    static function defaultMeasure<T>(inputs:LayoutInput, nodeId:NodeId, context:Null<T>, style:Style):LayoutOutput {
        return Leaf.computeLeafLayout(inputs, style, zeroMeasure);
    }

    static function zeroMeasure(knownDimensions:SizeOpt, availableSpace:SizeAvail):Size {
        return Size.ZERO;
    }

    /** Prints a debug representation of the tree's layout */
    public function printTree(root:NodeId):Void {
        taffy.util.Print.printTree(new TaffyView<NodeContext>(this), root);
    }

}

/**
 * View over the `TaffyTree` that implements the layout interfaces, holding the measure function.
 */
@:allow(taffy.tree.TaffyTree)
class TaffyView<NodeContext>
    implements LayoutContainingBlockCacheTree
    implements LayoutFlexboxContainer
    implements LayoutGridContainer
    implements LayoutBlockContainer
    implements RoundTree
    implements PrintTree {

    /** A reference to the `TaffyTree` */
    final taffy:TaffyTree<NodeContext>;

    /** The measure function used to lay out leaves */
    var measureFunction:Null<MeasureFunction<NodeContext>> = null;

    public function new(taffy:TaffyTree<NodeContext>) {
        this.taffy = taffy;
    }

    inline function data(nodeId:NodeId):NodeData<NodeContext> {
        return taffy.nodes[nodeId];
    }

    // TraversePartialTree

    @:noDebug
    public function childIds(parentNodeId:NodeId):Array<NodeId> {
        return data(parentNodeId).children;
    }

    @:noDebug
    public function childCount(parentNodeId:NodeId):Int {
        return data(parentNodeId).children.length;
    }

    @:noDebug
    public function getChildId(parentNodeId:NodeId, childIndex:Int):NodeId {
        return data(parentNodeId).children[childIndex];
    }

    // LayoutPartialTree

    @:noDebug
    public function getCoreContainerStyle(nodeId:NodeId):Style {
        return data(nodeId).style;
    }

    @:noDebug
    public function setUnroundedLayout(nodeId:NodeId, layout:Layout):Void {
        data(nodeId).unroundedLayout = layout;
    }

    @:noDebug
    public function computeChildLayout(nodeId:NodeId, inputs:LayoutInput):LayoutOutput {
        return computeChildLayoutWithBlockContext(nodeId, inputs, null);
    }

    /** Compute the layout of a child, possibly sharing a block formatting context with its parent */
    function computeChildLayoutWithBlockContext(nodeId:NodeId, inputs:LayoutInput, blockCtx:Null<BlockContext>):LayoutOutput {
        // If RunMode is PerformHiddenLayout then this indicates that an ancestor node is `Display.None`
        // and thus that we should lay out this node using hidden layout regardless of its own display style.
        if (inputs.runMode == PerformHiddenLayout) {
            return Compute.computeHiddenLayout(this, nodeId);
        }

        // We run the following inside the cache lookup (Rust `compute_cached_layout`)
        final nodeData = data(nodeId);
        final cached = nodeData.cache.get(inputs);
        if (cached != null)
            return cached;

        final displayMode = nodeData.style.display;
        final hasChildren = nodeData.children.length > 0;

        final output:LayoutOutput = if (displayMode == Display.None) {
            Compute.computeHiddenLayout(this, nodeId);
        }
        else if (!hasChildren) {
            final style = nodeData.style;
            final nodeContext = nodeData.hasContext ? nodeData.context : null;
            measureFunction(inputs, nodeId, nodeContext, style);
        }
        else switch displayMode {
            case Block: BlockLayout.computeBlockLayout(this, nodeId, inputs, blockCtx);
            case FlowRoot: BlockLayout.computeBlockLayout(this, nodeId, inputs, null);
            case Flex: FlexboxLayout.computeFlexboxLayout(this, nodeId, inputs);
            case Grid: GridLayout.computeGridLayout(this, nodeId, inputs);
            case None: Compute.computeHiddenLayout(this, nodeId);
        }

        if (inputs.runMode == PerformLayout) {
            Oof.computeOofLayout(this, nodeId, output);
        }

        nodeData.cache.store(inputs, output);
        return output;
    }

    // LayoutContainingBlock

    @:noDebug
    public function getOofItemStyle(nodeId:NodeId):Style {
        return data(nodeId).style;
    }

    public function clearHoistedChildren(nodeId:NodeId):Void {
        final d = data(nodeId);
        if (d.hoistedChildren.length > 0)
            d.hoistedChildren = [];
    }

    public function addHoistedChildren(nodeId:NodeId, hoisted:Array<NodeId>):Void {
        final list = data(nodeId).hoistedChildren;
        for (h in hoisted)
            list.push(h);
    }

    @:noDebug
    public function getDetailedLayoutInfo(nodeId:NodeId):DetailedLayoutInfo {
        return data(nodeId).detailedLayoutInfo;
    }

    // CacheTree

    @:noDebug
    public function cacheGet(nodeId:NodeId, input:LayoutInput):Null<LayoutOutput> {
        return data(nodeId).cache.get(input);
    }

    @:noDebug
    public function cacheStore(nodeId:NodeId, input:LayoutInput, layoutOutput:LayoutOutput):Void {
        data(nodeId).cache.store(input, layoutOutput);
    }

    @:noDebug
    public function cacheClear(nodeId:NodeId):Void {
        data(nodeId).cache.clear();
    }

    // LayoutBlockContainer

    @:noDebug
    public function getBlockContainerStyle(nodeId:NodeId):Style {
        return data(nodeId).style;
    }

    @:noDebug
    public function getBlockChildStyle(childNodeId:NodeId):Style {
        return data(childNodeId).style;
    }

    @:noDebug
    public function computeBlockChildLayout(nodeId:NodeId, inputs:LayoutInput, blockCtx:Null<BlockContext>):LayoutOutput {
        return computeChildLayoutWithBlockContext(nodeId, inputs, blockCtx);
    }

    // LayoutFlexboxContainer

    @:noDebug
    public function getFlexboxContainerStyle(nodeId:NodeId):Style {
        return data(nodeId).style;
    }

    @:noDebug
    public function getFlexboxChildStyle(childNodeId:NodeId):Style {
        return data(childNodeId).style;
    }

    // LayoutGridContainer

    @:noDebug
    public function getGridContainerStyle(nodeId:NodeId):Style {
        return data(nodeId).style;
    }

    @:noDebug
    public function getGridChildStyle(childNodeId:NodeId):Style {
        return data(childNodeId).style;
    }

    public function setDetailedGridInfo(nodeId:NodeId, detailedGridInfo:DetailedGridInfo):Void {
        data(nodeId).detailedLayoutInfo = DetailedLayoutInfo.Grid(detailedGridInfo);
    }

    // RoundTree

    public function getUnroundedLayout(nodeId:NodeId):Layout {
        return data(nodeId).unroundedLayout;
    }

    public function setFinalLayout(nodeId:NodeId, layout:Layout):Void {
        data(nodeId).finalLayout = layout;
    }

    public function isOutOfFlow(nodeId:NodeId):Bool {
        final d = data(nodeId);
        return d.style.position.isOutOfFlow() && d.style.display != Display.None;
    }

    public function hoistedChildCount(nodeId:NodeId):Int {
        return data(nodeId).hoistedChildren.length;
    }

    public function getHoistedChildId(nodeId:NodeId, index:Int):NodeId {
        return data(nodeId).hoistedChildren[index];
    }

    // PrintTree

    public function getDebugLabel(nodeId:NodeId):String {
        final d = data(nodeId);
        final display = d.style.display;
        final numChildren = d.children.length;
        if (display == Display.None)
            return "NONE";
        if (numChildren == 0)
            return "LEAF";
        return switch display {
            case Block: "BLOCK";
            case FlowRoot: "FLOW-ROOT";
            case Flex: d.style.flexDirection.isRow() ? "FLEX ROW" : "FLEX COL";
            case Grid: "GRID";
            case None: "NONE";
        }
    }

    public function getFinalLayout(nodeId:NodeId):Layout {
        return taffy.layout(nodeId);
    }

}
