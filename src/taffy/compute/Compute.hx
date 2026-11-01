// Ported from taffy 0.15.0: src/compute/mod.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute;

import taffy.geometry.Line;
import taffy.geometry.LineOf;
import taffy.geometry.Point;
import taffy.geometry.PointOf;
import taffy.geometry.Rect;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.AvailableSpace;
import taffy.style.BoxSizing;
import taffy.style.ContainingBlockClaims;
import taffy.style.Overflow;
import taffy.style.Position;
import taffy.tree.AxisStaticAlign;
import taffy.tree.AxisStaticEdge;
import taffy.tree.AxisStaticPosition;
import taffy.tree.CacheTree;
import taffy.tree.LayoutContainingBlockCacheTree;
import taffy.tree.LayoutPartialCacheTree;
import taffy.tree.Layout;
import taffy.tree.LayoutInput;
import taffy.tree.LayoutOutput;
import taffy.tree.NodeId;
import taffy.tree.OofCandidate;
import taffy.tree.OofCandidates;
import taffy.tree.RoundTree;
import taffy.util.Sys;
import taffy.geometry.SizeOpt;
import taffy.util.OptionalFloat;
import taffy.geometry.SizeAvail;

using taffy.geometry.SizeOf;
using taffy.style.AvailableSpace;
using taffy.util.MaybeMath;
using taffy.util.Resolve;

/**
 * Low-level access to the layout algorithms themselves. For a higher-level API, see `TaffyTree`.
 *
 * | Function                       | Purpose |
 * | ---                            | --- |
 * | `Flexbox.computeFlexboxLayout` | Layout a Flexbox container and its direct children |
 * | `Grid.computeGridLayout`       | Layout a CSS Grid container and its direct children |
 * | `Block.computeBlockLayout`     | Layout a Block container and its direct children |
 * | `Leaf.computeLeafLayout`       | Applies common properties like padding/border/aspect-ratio to a node before deferring to a measure function |
 * | `Compute.computeRootLayout`    | Layout the root node of a tree (regardless of its layout mode) |
 * | `Compute.computeHiddenLayout`  | Mark a node as hidden during layout (like `Display.None`) |
 * | `Compute.computeCachedLayout`  | Use a cached layout if available, else compute and cache it |
 * | `Compute.roundLayout`          | Round a tree of float-valued layouts to integer pixels |
 */
class Compute {

    static final FALSE_LINE:LineOf<Bool> = new LineOf<Bool>(false, false);
    static final TRUE_SIZE:SizeOf<Bool> = new SizeOf<Bool>(true, true);

    /**
     * Compute layout for the root node in the tree.
     *
     * The root's containing block is the initial containing block (ICB), which has the dimensions of the
     * viewport (`availableSpace`) and is anchored at the canvas origin.
     *
     * - A `position: absolute`/`fixed` root is laid out by the out-of-flow positioning routine, with its static
     *   position at the ICB origin. This requires a definite `availableSpace` in both axes.
     * - A `position: relative` root is laid out in flow and then offset by its insets.
     */
    public static function computeRootLayout(tree:LayoutContainingBlockCacheTree, root:NodeId, availableSpace:SizeAvail):Void {
        final style = tree.getCoreContainerStyle(root);
        final position = style.position;
        final direction = style.direction;

        final icbSize = availableSpace.intoOptions();
        final oofRoot = position.isOutOfFlow() && icbSize.width.isSome() && icbSize.height.isSome();

        // When the root's layout is served from the cache its layout algorithm does not run, so the
        // hoisted children it recorded on a previous run are still in place and must not be re-added.
        var rootIsCached = false;
        var layout:Layout;
        var candidates:OofCandidates;
        if (oofRoot) {
            final areaSize = new Size(icbSize.width.unwrap(), icbSize.height.unwrap());
            // The static position of the root places its margin box at the origin of the ICB
            final start = direction.isRtl() ? areaSize.width : 0.0;
            final candidate = new OofCandidate(
                root,
                0,
                position,
                new PointOf<AxisStaticPosition>(
                    new AxisStaticPosition(new Line(start, start), AxisStaticAlign.fromKeyword(direction.isRtl() ? AxisStaticEdge.End : AxisStaticEdge.Start)),
                    AxisStaticPosition.fromEdge(0.0, AxisStaticEdge.Start)
                )
            );
            final boxLayout = Oof.layoutOofBox(
                tree,
                candidate,
                areaSize,
                Point.ZERO,
                direction,
                // The initial containing block is not a scroll container
                new PointOf<Overflow>(Visible, Visible),
                null,
                (_, inputs) -> rootIsCached = tree.cacheGet(root, inputs) != null
            );
            layout = boxLayout.layout;
            candidates = boxLayout.surfaced;
        }
        else {
            final result = computeInFlowRootLayout(tree, root, availableSpace);
            layout = result.layout;
            candidates = result.candidates;
            rootIsCached = result.rootIsCached;
        }

        // Final positioning pass for out-of-flow boxes with no nearer containing block: the initial
        // containing block is the containing block for `position: fixed` boxes and for
        // `position: absolute` boxes with no positioned ancestor.
        if (!candidates.isEmpty()) {
            final overflow = tree.getCoreContainerStyle(root).overflow;
            // In an axis where the available space is indefinite, fall back to the root's padding box.
            final areaInset = layout.border.add(new Rect(0.0, layout.scrollbarSize.width, 0.0, layout.scrollbarSize.height));
            final rootPaddingBoxSize = layout.size.sub(new Size(areaInset.horizontalAxisSum(), areaInset.verticalAxisSum()));
            var areaWidth:Float;
            var areaX:Float;
            if (icbSize.width.isSome()) {
                areaWidth = Sys.f32Max(icbSize.width.unwrap() - layout.scrollbarSize.width, 0.0);
                areaX = -layout.location.x;
            }
            else {
                areaWidth = rootPaddingBoxSize.width;
                areaX = areaInset.left;
            }
            var areaHeight:Float;
            var areaY:Float;
            if (icbSize.height.isSome()) {
                areaHeight = Sys.f32Max(icbSize.height.unwrap() - layout.scrollbarSize.height, 0.0);
                areaY = -layout.location.y;
            }
            else {
                areaHeight = rootPaddingBoxSize.height;
                areaY = areaInset.top;
            }
            final hoisted:Array<NodeId> = [];
            final unclaimed = new OofCandidates();
            Oof.performOofLayout(
                tree,
                root,
                candidates.asArray(),
                new Size(areaWidth, areaHeight),
                new Point(areaX, areaY),
                direction,
                // The root is the initial containing block and claims all remaining candidates
                ContainingBlockClaims.ALL,
                overflow,
                hoisted,
                unclaimed
            );
            if (!rootIsCached) {
                tree.addHoistedChildren(root, hoisted);
            }
        }
    }

    /**
     * Lay out an in-flow (or `position: relative`) root node against the available space, store its layout
     * and return it along with the out-of-flow candidates bubbled up from its subtree.
     */
    static function computeInFlowRootLayout(tree:LayoutContainingBlockCacheTree, root:NodeId, availableSpace:SizeAvail):InFlowRootResult {
        var knownDimensions:SizeOpt = SizeOpt.NONE;

        // The available space passed to the root excludes the root's margins
        final rootAvailableSpace = {
            final style = tree.getCoreContainerStyle(root);
            final margin = style.margin.resolveOrZero(availableSpace.width.intoOption());
            availableSpace.maybeSubSize(margin.sumAxes()).maybeMaxSize(Size.ZERO);
        };

        {
            final parentSize = availableSpace.intoOptions();
            final style = tree.getCoreContainerStyle(root);
            if (style.isBlock()) {
                // Pull these out earlier to avoid borrowing issues
                final aspectRatio = style.aspectRatio;
                final padding = style.padding.resolveOrZero(parentSize.width);
                final border = style.border.resolveOrZero(parentSize.width);
                final paddingBorderSize = padding.add(border).sumAxes();
                final boxSizingAdjustment = style.boxSizing == ContentBox ? paddingBorderSize : Size.ZERO;

                final minSize = style.minSize.maybeResolve(parentSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);
                final maxSize = style.maxSize.maybeResolve(parentSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);
                final clampedStyleSize = style.size
                    .maybeResolve(parentSize)
                    .maybeApplyAspectRatio(aspectRatio)
                    .maybeAddSize(boxSizingAdjustment)
                    .maybeClamp(minSize, maxSize);

                // If both min and max in a given axis are set and max <= min then this determines the size in that axis
                final minMaxDefiniteSize = new SizeOpt(
                    (minSize.width.isSome() && maxSize.width.isSome() && maxSize.width.unwrap() <= minSize.width.unwrap()) ? minSize.width : OptionalFloat.NONE,
                    (minSize.height.isSome() && maxSize.height.isSome() && maxSize.height.unwrap() <= minSize.height.unwrap()) ? minSize.height : OptionalFloat.NONE
                );

                // Block nodes automatically stretch fit their width to fit available space if available space is definite
                final availableSpaceBasedSize = new SizeOpt(rootAvailableSpace.width.intoOption(), OptionalFloat.NONE);

                knownDimensions = knownDimensions
                    .or(minMaxDefiniteSize)
                    .or(clampedStyleSize)
                    .or(availableSpaceBasedSize)
                    .maybeMaxSize(paddingBorderSize);
            }
        }

        final inputs = new LayoutInput(
            PerformLayout,
            InherentSize,
            Both,
            knownDimensions,
            TRUE_SIZE,
            availableSpace.intoOptions(),
            rootAvailableSpace,
            FALSE_LINE
        );

        final rootIsCached = tree.cacheGet(root, inputs) != null;

        // Recursively compute node layout
        final output = tree.computeChildLayout(root, inputs);

        final style = tree.getCoreContainerStyle(root);
        final availableWidth = availableSpace.width.intoOption();
        final padding = style.padding.resolveOrZero(availableWidth);
        final border = style.border.resolveOrZero(availableWidth);
        final margin = style.margin.resolveOrZero(availableWidth);
        final scrollbarSize = new Size(
            style.overflow.y == Scroll ? style.scrollbarWidth : 0.0,
            style.overflow.x == Scroll ? style.scrollbarWidth : 0.0
        );
        final isRtl = style.direction.isRtl();

        // The root's margin box is placed at the origin of the initial containing block
        var locationX = (isRtl && availableWidth.isSome()) ? availableWidth.unwrap() - output.size.width - margin.right : margin.left;
        var locationY = margin.top;

        // A relatively positioned root is offset by its insets (resolved against the initial containing block)
        if (style.position == Relative) {
            final icbSize = availableSpace.intoOptions();
            final inset = style.inset;
            final left = inset.left.maybeResolve(icbSize.width);
            final right = inset.right.maybeResolve(icbSize.width);
            final top = inset.top.maybeResolve(icbSize.height);
            final bottom = inset.bottom.maybeResolve(icbSize.height);
            final negRight:OptionalFloat = right.isSome() ? OptionalFloat.some(-right.unwrap()) : OptionalFloat.NONE;
            final negBottom:OptionalFloat = bottom.isSome() ? OptionalFloat.some(-bottom.unwrap()) : OptionalFloat.NONE;
            locationX += isRtl ? negRight.or(left).unwrapOr(0.0) : left.or(negRight).unwrapOr(0.0);
            locationY += top.or(negBottom).unwrapOr(0.0);
        }

        final layout = new Layout(
            0,
            new Point(locationX, locationY),
            output.size,
            output.scrollableOverflowRect,
            scrollbarSize,
            border,
            padding,
            // TODO: support auto margins for root node?
            margin
        );

        tree.setUnroundedLayout(root, layout);

        return new InFlowRootResult(layout, output.oofCandidates.take(), rootIsCached);
    }

    /**
     * Attempts to find a cached layout for the specified node and layout inputs.
     *
     * Uses the provided function to compute the layout (and then stores the result in the cache) if no cached layout is found.
     */
    public static inline function computeCachedLayout<T:CacheTree>(tree:T, node:NodeId, inputs:LayoutInput, computeUncached:(T, NodeId, LayoutInput) -> LayoutOutput):LayoutOutput {
        // First we check if we have a cached result for the given input
        final cacheEntry = tree.cacheGet(node, inputs);
        if (cacheEntry != null) {
            return cacheEntry;
        }
        final computedSizeAndBaselines = computeUncached(tree, node, inputs);
        // Cache result
        tree.cacheStore(node, inputs, computedSizeAndBaselines);
        return computedSizeAndBaselines;
    }

    /**
     * Rounds the calculated layout to exact pixel values
     *
     * In order to ensure that no gaps in the layout are introduced we:
     *   - Always round based on the cumulative x/y coordinates (relative to the viewport) rather than
     *     parent-relative coordinates
     *   - Compute width/height by first rounding the top/bottom/left/right and then computing the difference
     *     rather than rounding the width/height directly
     *
     * In order to prevent innacuracies caused by rounding already-rounded values, we read from `unroundedLayout`
     * and write to `finalLayout`.
     */
    public static function roundLayout(tree:RoundTree, nodeId:NodeId):Void {
        roundLayoutInner(tree, nodeId, 0.0, 0.0);
    }

    /** Recursive function to apply rounding to all descendents */
    static function roundLayoutInner(tree:RoundTree, nodeId:NodeId, cumulativeX:Float, cumulativeY:Float):Void {
        final unrounded = tree.getUnroundedLayout(nodeId);
        final parentX = cumulativeX;
        final parentY = cumulativeY;
        final cumulativeX = cumulativeX + unrounded.location.x;
        final cumulativeY = cumulativeY + unrounded.location.y;

        final round = Sys.round;
        final location = new Point(round(cumulativeX) - round(parentX), round(cumulativeY) - round(parentY));
        final size = new Size(
            round(cumulativeX + unrounded.size.width) - round(cumulativeX),
            round(cumulativeY + unrounded.size.height) - round(cumulativeY)
        );
        final scrollbarSize = new Size(round(unrounded.scrollbarSize.width), round(unrounded.scrollbarSize.height));
        final border = new Rect(
            round(cumulativeX + unrounded.border.left) - round(cumulativeX),
            round(cumulativeX + unrounded.size.width) - round(cumulativeX + unrounded.size.width - unrounded.border.right),
            round(cumulativeY + unrounded.border.top) - round(cumulativeY),
            round(cumulativeY + unrounded.size.height) - round(cumulativeY + unrounded.size.height - unrounded.border.bottom)
        );
        final padding = new Rect(
            round(cumulativeX + unrounded.padding.left) - round(cumulativeX),
            round(cumulativeX + unrounded.size.width) - round(cumulativeX + unrounded.size.width - unrounded.padding.right),
            round(cumulativeY + unrounded.padding.top) - round(cumulativeY),
            round(cumulativeY + unrounded.size.height) - round(cumulativeY + unrounded.size.height - unrounded.padding.bottom)
        );
        final so = unrounded.scrollableOverflowRect;
        final scrollableOverflowRect = new Rect(
            round(cumulativeX + so.left) - round(cumulativeX),
            round(cumulativeX + so.right) - round(cumulativeX),
            round(cumulativeY + so.top) - round(cumulativeY),
            round(cumulativeY + so.bottom) - round(cumulativeY)
        );

        tree.setFinalLayout(nodeId, new Layout(unrounded.order, location, size, scrollableOverflowRect, scrollbarSize, border, padding, unrounded.margin));

        // Recurse into in-flow children. Out-of-flow (absolute/fixed) children are skipped here:
        // they are instead visited via their containing block's hoisted child list below.
        final childCount = tree.childCount(nodeId);
        for (index in 0...childCount) {
            final child = tree.getChildId(nodeId, index);
            if (!tree.isOutOfFlow(child)) {
                roundLayoutInner(tree, child, cumulativeX, cumulativeY);
            }
        }

        // Recurse into out-of-flow boxes for which this node is the containing block
        final hoistedCount = tree.hoistedChildCount(nodeId);
        for (index in 0...hoistedCount) {
            final child = tree.getHoistedChildId(nodeId, index);
            roundLayoutInner(tree, child, cumulativeX, cumulativeY);
        }
    }

    /**
     * Creates a layout for this node and its children, recursively.
     * Each hidden node has zero size and is placed at the origin
     */
    public static function computeHiddenLayout(tree:LayoutPartialCacheTree, node:NodeId):LayoutOutput {
        // Clear cache and set zeroed-out layout for the node
        tree.cacheClear(node);
        tree.setUnroundedLayout(node, Layout.ZERO);

        // Perform hidden layout on all children
        for (index in 0...tree.childCount(node)) {
            final childId = tree.getChildId(node, index);
            tree.computeChildLayout(childId, LayoutInput.HIDDEN);
        }

        return LayoutOutput.hidden();
    }

}

/**
 * The result of `Compute.computeInFlowRootLayout`
 */
private class InFlowRootResult {

    public final layout:Layout;

    public final candidates:OofCandidates;

    public final rootIsCached:Bool;

    public function new(layout:Layout, candidates:OofCandidates, rootIsCached:Bool) {
        this.layout = layout;
        this.candidates = candidates;
        this.rootIsCached = rootIsCached;
    }

}

