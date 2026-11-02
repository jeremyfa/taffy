// Ported from taffy 0.15.0: src/compute/block.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute;

import taffy.compute.block.BlockContext;
import taffy.compute.block.BlockFormattingContext;
import taffy.compute.block.BlockItem;
import taffy.compute.common.Alignment;
import taffy.compute.common.ScrollableOverflow;
import taffy.compute.common.SizingKeyword;
import taffy.compute.float.FloatContext;
import taffy.compute.float.FloatIntrinsicWidthCalculator;
import taffy.geometry.Line;
import taffy.geometry.LineOf;
import taffy.geometry.Point;
import taffy.geometry.PointOf;
import taffy.geometry.Rect;
import taffy.geometry.RectOf;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.AlignContent;
import taffy.style.AlignContentKeyword;
import taffy.style.AlignItems;
import taffy.style.AlignItemsKeyword;
import taffy.style.AlignmentSafety;
import taffy.style.AvailableSpace;
import taffy.style.BoxGenerationMode;
import taffy.style.BoxSizing;
import taffy.style.CssFloat;
import taffy.style.Dimension;
import taffy.style.Direction;
import taffy.style.Overflow;
import taffy.style.Position;
import taffy.style.TextAlign;
import taffy.tree.AxisStaticPosition;
import taffy.tree.Baselines;
import taffy.tree.CollapsibleMarginSet;
import taffy.tree.Layout;
import taffy.tree.LayoutBlockContainer;
import taffy.tree.LayoutInput;
import taffy.tree.LayoutOutput;
import taffy.tree.LayoutPartialTree;
import taffy.tree.NodeId;
import taffy.tree.OofCandidate;
import taffy.tree.OofCandidates;
import taffy.tree.OofPositioningArea;
import taffy.tree.RunMode;
import taffy.util.Sys;
import taffy.geometry.SizeOpt;
import taffy.geometry.RectOpt;
import taffy.util.OptionalFloat;
import taffy.geometry.SizeAvail;
import taffy.style.AvailableSpace.Definite;

using taffy.geometry.SizeOf;
using taffy.style.AvailableSpace;
using taffy.tree.LayoutPartialTree;
using taffy.util.MaybeMath;
using taffy.util.Resolve;

/**
 * The results of `BlockLayout.performFinalLayoutOnInFlowChildren`
 */
private class InFlowResult {

    public final inflowOverflowRect:Rect;
    public final contentHeight:Float;
    public final firstChildTopMarginSet:CollapsibleMarginSet;
    public final lastChildBottomMarginSet:CollapsibleMarginSet;
    public final firstBaseline:OptionalFloat;

    public function new(inflowOverflowRect:Rect, contentHeight:Float, firstChildTopMarginSet:CollapsibleMarginSet, lastChildBottomMarginSet:CollapsibleMarginSet, firstBaseline:OptionalFloat) {
        this.inflowOverflowRect = inflowOverflowRect;
        this.contentHeight = contentHeight;
        this.firstChildTopMarginSet = firstChildTopMarginSet;
        this.lastChildBottomMarginSet = lastChildBottomMarginSet;
        this.firstBaseline = firstBaseline;
    }

}

/**
 * Computes the CSS block layout algorithm in the case that the block container being laid out contains only block-level boxes
 */
class BlockLayout {

    static final FALSE_LINE:LineOf<Bool> = new LineOf<Bool>(false, false);
    static final TRUE_LINE:LineOf<Bool> = new LineOf<Bool>(true, true);
    static final TRUE_SIZE:SizeOf<Bool> = new SizeOf<Bool>(true, true);

    /** The four values of a `LineOf<Bool>` (shared, never mutated) */
    static final START_LINE:LineOf<Bool> = new LineOf<Bool>(true, false);
    static final END_LINE:LineOf<Bool> = new LineOf<Bool>(false, true);

    static inline function boolLine(start:Bool, end:Bool):LineOf<Bool> {
        return start ? (end ? TRUE_LINE : START_LINE) : (end ? END_LINE : FALSE_LINE);
    }

    /**
     * Block formatting contexts reused between calls, as a stack: a block container that establishes
     * a new one takes it at `bfcPoolTop` and gives it back when it returns (nested ones take theirs
     * above). If a call throws, they are not given back and the next calls use fresh ones above.
     */
    static final bfcPool:Array<BlockFormattingContext> = [];

    static var bfcPoolTop:Int = 0;

    /** The block contexts of the same-BFC children being laid out, as a stack (like `bfcPool`) */
    static final subContextPool:Array<BlockContext> = [];

    static var subContextPoolTop:Int = 0;

    /** The items of the block containers being laid out, as a stack (like `bfcPool`) */
    static final itemPool:Array<BlockItem> = [];

    static var itemPoolTop:Int = 0;

    /** The item arrays of each nesting level of `computeInner` */
    static final itemArrays:Array<Array<BlockItem>> = [];

    static var itemArrayLevel:Int = 0;

    /**
     * Compute the block-axis offset that `align-content` applies to the in-flow content of a block
     * container, given the free space between the container's content box and its content.
     *
     * The entire stack of in-flow content is treated as a single alignment subject, so the
     * distribution keywords (`space-*`, `stretch`) invoke their single-subject fallbacks.
     */
    public static function computeBlockAlignContentOffset(alignContent:AlignContent, freeSpace:Float):Float {
        final keyword = Alignment.applyAlignmentFallback(freeSpace, 1, alignContent);
        return Alignment.computeAlignmentOffset(freeSpace, 1, 0.0, keyword, false, true);
    }

    /** Computes the layout of a `LayoutBlockContainer` according to the block layout algorithm */
    public static function computeBlockLayout(tree:LayoutBlockContainer, nodeId:NodeId, inputs:LayoutInput, blockCtx:Null<BlockContext>):LayoutOutput {
        final knownDimensions = inputs.knownDimensions;
        final parentSize = inputs.parentSize;
        final runMode = inputs.runMode;
        final style = tree.getBlockContainerStyle(nodeId);

        // Pull these out earlier to avoid borrowing issues
        final overflow = style.overflow;
        final isScrollContainer = overflow.x.isScrollContainer() || overflow.y.isScrollContainer();
        final contain = style.contain;
        // css-align-3 5.1.1: a non-`normal` `align-content` makes a block container establish an
        // independent formatting context. Layout and paint containment also establish an independent formatting context.
        final establishesNewBfc = isScrollContainer
            || style.alignContent.keyword != AlignContentKeyword.Normal
            || contain.establishesIndependentFormattingContext();
        final aspectRatio = style.aspectRatio;
        final padding = style.padding.resolveOrZero(parentSize.width);
        final border = style.border.resolveOrZero(parentSize.width);
        final paddingBorderSize = padding.add(border).sumAxes();
        final contentBox = style.boxSizing == ContentBox;
        final boxSizingAdjustment = new Size(contentBox ? paddingBorderSize.width : 0.0, contentBox ? paddingBorderSize.height : 0.0);
        final minSize = style.minSize.maybeResolve(parentSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);
        final maxSize = style.maxSize.maybeResolve(parentSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);
        // Under `InherentSize` only (one object, which does not escape)
        final inherentSize = inputs.sizingMode == InherentSize;
        final styleSize = style.size
            .maybeResolve(parentSize)
            .maybeApplyAspectRatio(aspectRatio)
            .maybeAddSize(boxSizingAdjustment)
            .maybeClamp(minSize, maxSize);
        final clampedStyleSize = new SizeOpt(
            inherentSize ? styleSize.width : OptionalFloat.NONE,
            inherentSize ? styleSize.height : OptionalFloat.NONE
        );

        // If both min and max in a given axis are set and max <= min then this determines the size in that axis
        final minMaxDefiniteSize = minMaxDefinite(minSize, maxSize);

        final styledKnown = knownDimensions.or(minMaxDefiniteSize).or(clampedStyleSize).maybeMaxSize(paddingBorderSize);
        final styledBasedKnownDimensions = SizeOpt.shared(styledKnown.width, styledKnown.height);

        // Short-circuit layout if the container's size is fully determined by the container's size and the run mode
        // is ComputeSize (and thus the container's size is all that we're interested in)
        if (runMode == ComputeSize) {
            final width = styledBasedKnownDimensions.width;
            final height = styledBasedKnownDimensions.height;
            if (width.isSome() && height.isSome()) {
                return LayoutOutput.fromOuterSize(new Size(width.unwrap(), height.unwrap()));
            }
            // We can also short-circuit if the width is known and only the width has been requested.
            if (inputs.axis == Horizontal && width.isSome()) {
                return LayoutOutput.fromOuterSize(new Size(width.unwrap(), 0.0));
            }
        }

        // Unwrap the block formatting context if one was passed, or else create a new one
        // (`inputs.withKnownDimensions(styledBasedKnownDimensions)`, reused)
        final innerInputs = LayoutInput.acquire(inputs.runMode, inputs.sizingMode, inputs.axis, styledBasedKnownDimensions,
            inputs.knownDimensionsAreDefinite, inputs.parentSize, inputs.availableSpace, inputs.verticalMarginsAreCollapsible);
        final output = if (blockCtx != null && !establishesNewBfc) {
            computeInner(tree, nodeId, innerInputs, blockCtx);
        }
        else {
            // A new `BlockFormattingContext` and its `rootBlockContext()`, reused
            final bfcIndex = bfcPoolTop++;
            if (bfcIndex == bfcPool.length)
                bfcPool.push(new BlockFormattingContext());
            final rootCtx = bfcPool[bfcIndex].reuse();
            final result = computeInner(tree, nodeId, innerInputs, rootCtx);
            bfcPoolTop = bfcIndex;
            result;
        }
        LayoutInput.release();

        // Layout containment suppresses the box's baseline for baseline-alignment purposes
        if (contain.suppressesBaseline()) {
            output.baselines = Baselines.NONE;
        }

        return output;
    }

    /** If both min and max in a given axis are set and max <= min then this determines the size in that axis */
    static inline function minMaxDefinite(minSize:SizeOpt, maxSize:SizeOpt):SizeOpt {
        return new SizeOpt(
            (minSize.width.isSome() && maxSize.width.isSome() && maxSize.width.unwrap() <= minSize.width.unwrap()) ? minSize.width : OptionalFloat.NONE,
            (minSize.height.isSome() && maxSize.height.isSome() && maxSize.height.unwrap() <= minSize.height.unwrap()) ? minSize.height : OptionalFloat.NONE
        );
    }

    /**
     * Computes the layout of a `LayoutBlockContainer` according to the block layout algorithm.
     *
     * Takes the item array of the current nesting level and the items above the pool top, and gives
     * them back on return (they do not outlive the call).
     */
    static function computeInner(tree:LayoutBlockContainer, nodeId:NodeId, inputs:LayoutInput, blockCtx:BlockContext):LayoutOutput {
        final level = itemArrayLevel;
        final itemMark = itemPoolTop;
        if (level == itemArrays.length)
            itemArrays.push([]);
        itemArrayLevel = level + 1;
        final output = computeInnerWith(tree, nodeId, inputs, blockCtx, itemArrays[level]);
        itemArrayLevel = level;
        itemPoolTop = itemMark;
        return output;
    }

    static function computeInnerWith(tree:LayoutBlockContainer, nodeId:NodeId, inputs:LayoutInput, blockCtx:BlockContext, itemArray:Array<BlockItem>):LayoutOutput {
        var knownDimensions = inputs.knownDimensions;
        final parentSize = inputs.parentSize;
        final availableSpace = inputs.availableSpace;
        final runMode = inputs.runMode;
        final verticalMarginsAreCollapsible = inputs.verticalMarginsAreCollapsible;

        final style = tree.getBlockContainerStyle(nodeId);
        final rawPadding = style.padding;
        final rawBorder = style.border;
        final rawMargin = style.margin;
        final aspectRatio = style.aspectRatio;
        final padding = rawPadding.resolveOrZero(parentSize.width);
        final border = rawBorder.resolveOrZero(parentSize.width);
        final direction = style.direction;

        // Scrollbar gutters are reserved when the `overflow` property is set to `Overflow.Scroll`.
        // However, the axis are switched (transposed) because a node that scrolls vertically needs
        // *horizontal* space to be reserved for a scrollbar
        final offsetX = style.overflow.y == Scroll ? style.scrollbarWidth : 0.0;
        final offsetY = style.overflow.x == Scroll ? style.scrollbarWidth : 0.0;
        final isLtr = direction == Ltr;
        final scrollbarGutter = new Rect(isLtr ? 0.0 : offsetX, isLtr ? offsetX : 0.0, 0.0, offsetY);

        final paddingBorder = padding.add(border);
        final paddingBorderSize = paddingBorder.sumAxes();
        final contentBoxInsetValue = paddingBorder.add(scrollbarGutter);
        final contentBoxInset = Rect.shared(contentBoxInsetValue.left, contentBoxInsetValue.right, contentBoxInsetValue.top, contentBoxInsetValue.bottom);

        // Apply content box inset
        blockCtx.applyContentBoxInset(contentBoxInset.left, contentBoxInset.right);

        final contentBox = style.boxSizing == ContentBox;
        final boxSizingAdjustment = new Size(contentBox ? paddingBorderSize.width : 0.0, contentBox ? paddingBorderSize.height : 0.0);
        final size = style.size.maybeResolve(parentSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);
        final minSize = style.minSize.maybeResolve(parentSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);
        final maxSize = style.maxSize.maybeResolve(parentSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);

        // css-sizing-4: a definite size in one axis transfers through `aspect-ratio`
        // to make the other definite. Only a newly-filled axis is adopted (and clamped).
        {
            final derived = knownDimensions.maybeApplyAspectRatio(aspectRatio).maybeClamp(minSize, maxSize);
            final width = knownDimensions.width.isSome() ? knownDimensions.width : derived.width;
            final height = knownDimensions.height.isSome() ? knownDimensions.height : derived.height;
            // Unchanged in the common case (no aspect ratio): keep the same object
            if (width != knownDimensions.width || height != knownDimensions.height)
                knownDimensions = new SizeOpt(width, height);
        }

        final percentageBasisDimensions = new SizeOpt(
            knownDimensions.width,
            inputs.knownDimensionsAreDefinite.height ? knownDimensions.height : OptionalFloat.NONE
        );
        final contentBoxSize = percentageBasisDimensions.maybeSubSize(contentBoxInset.sumAxes());
        final containerContentBoxSize = SizeOpt.shared(contentBoxSize.width, contentBoxSize.height);

        final overflow = style.overflow;
        final isScrollContainer = overflow.x.isScrollContainer() || overflow.y.isScrollContainer();
        final establishesNewBfc = isScrollContainer
            || style.alignContent.keyword != AlignContentKeyword.Normal
            || style.contain.establishesIndependentFormattingContext();

        // Determine margin collapsing behaviour
        //
        // Whether a child's margins could collapse through each of this box's block-axis edges: the
        // box does not establish a new BFC and has neither border nor padding on that side.
        final childrenMarginsAdjoinOwnEdges = boolLine(
            verticalMarginsAreCollapsible.start
                && !establishesNewBfc
                && !style.position.isOutOfFlow()
                && padding.top == 0.0
                && border.top == 0.0,
            verticalMarginsAreCollapsible.end
                && !establishesNewBfc
                && !style.position.isOutOfFlow()
                && padding.bottom == 0.0
                && border.bottom == 0.0
        );
        final ownMarginsCollapseWithChildren = boolLine(
            childrenMarginsAdjoinOwnEdges.start,
            childrenMarginsAdjoinOwnEdges.end && size.height.isNone()
        );
        final hasStylesPreventingBeingCollapsedThrough = !style.isBlock()
            || blockCtx.isBfcRoot()
            || establishesNewBfc
            || style.position.isOutOfFlow()
            || padding.top > 0.0
            || padding.bottom > 0.0
            || border.top > 0.0
            || border.bottom > 0.0;
        final textAlign = style.textAlign;
        final alignContent = style.alignContent;
        final justifyItems = style.justifyItems;

        // 1. Generate items
        final items = generateItemList(tree, nodeId, containerContentBoxSize, itemArray);

        // 2. Compute container width
        final containerOuterWidth:Float = if (knownDimensions.width.isSome()) {
            knownDimensions.width.unwrap();
        }
        else {
            final availableWidth = availableSpace.width.maybeSub(OptionalFloat.some(contentBoxInset.horizontalAxisSum()));
            final intrinsicWidth = determineContentBasedContainerWidth(tree, items, availableWidth) + contentBoxInset.horizontalAxisSum();
            intrinsicWidth.maybeClampF(minSize.width, maxSize.width).maybeMaxF(OptionalFloat.some(paddingBorderSize.width));
        }

        // Short-circuit if computing size and both dimensions known
        if (runMode == ComputeSize && knownDimensions.height.isSome()) {
            return LayoutOutput.fromOuterSize(new Size(containerOuterWidth, knownDimensions.height.unwrap()));
        }

        // We can also short-circuit if the width is known and only the width has been requested.
        if (runMode == ComputeSize && inputs.axis == Horizontal) {
            return LayoutOutput.fromOuterSize(new Size(containerOuterWidth, 0.0));
        }

        // Under `SizingMode.ContentSize` the container's own `height`/`min-height` are ignored,
        // so they cannot serve as the percentage basis for children either
        final containerPercentageResolutionHeight = percentageBasisDimensions.height
            .or(inputs.sizingMode == InherentSize ? size.height.maybeMax(minSize.height) : OptionalFloat.NONE);

        // 3. Perform final item layout and return content height
        //
        // Percentage padding and borders resolve against the *containing block's* width
        // (`parentSize`), not the box's own width. Fall back to the box's own width when the parent size is unknown.
        final percentageResolutionWidth = parentSize.width.unwrapOr(containerOuterWidth);
        final resolvedPadding = rawPadding.resolveOrZero(OptionalFloat.some(percentageResolutionWidth));
        final resolvedBorderValue = rawBorder.resolveOrZero(OptionalFloat.some(percentageResolutionWidth));
        final resolvedBorder = Rect.shared(resolvedBorderValue.left, resolvedBorderValue.right, resolvedBorderValue.top, resolvedBorderValue.bottom);
        final resolvedInset = resolvedPadding.add(resolvedBorder).add(scrollbarGutter);
        final resolvedContentBoxInset = Rect.shared(resolvedInset.left, resolvedInset.right, resolvedInset.top, resolvedInset.bottom);

        final result = performFinalLayoutOnInFlowChildren(
            tree,
            runMode,
            items,
            containerOuterWidth,
            containerPercentageResolutionHeight,
            contentBoxInset,
            resolvedContentBoxInset,
            resolvedBorder,
            textAlign,
            justifyItems,
            direction,
            ownMarginsCollapseWithChildren,
            childrenMarginsAdjoinOwnEdges,
            isScrollContainer,
            blockCtx
        );
        var inflowOverflowRect = result.inflowOverflowRect;
        var intrinsicOuterHeight = result.contentHeight;
        final firstChildTopMarginSet = result.firstChildTopMarginSet;
        final lastChildBottomMarginSet = result.lastChildBottomMarginSet;
        var firstBaseline = result.firstBaseline;

        // Root BFCs contain floats
        if (blockCtx.isBfcRoot() || establishesNewBfc) {
            intrinsicOuterHeight = Sys.f32Max(intrinsicOuterHeight, blockCtx.floatedContentHeightContribution());
        }

        final containerOuterHeight = (knownDimensions.height.isSome()
            ? knownDimensions.height.unwrap()
            : intrinsicOuterHeight.maybeClampF(minSize.height, maxSize.height)).maybeMaxF(OptionalFloat.some(paddingBorderSize.height));
        final finalOuterSize = new Size(containerOuterWidth, containerOuterHeight);

        // CSS2 8.3.1: the bottom margin of a block with `height: auto` collapses with its last
        // in-flow child's bottom margin only if the box's `min-height` is less than the box's used height.
        final minH = minSize.height;
        final heightConstrainedByMinHeight = minH.isSome() && minH.unwrap() > 0.0 && minH.unwrap() >= containerOuterHeight;
        final ownBottomMarginCollapsesWithChildren = ownMarginsCollapseWithChildren.end && !heightConstrainedByMinHeight;

        // Apply `align-content` to in-flow non-floated items if requested. For block layout the entire stack of
        // in-flow children is treated as a single alignment subject.
        if (alignContent.keyword != AlignContentKeyword.Normal) {
            final containerInnerHeight = containerOuterHeight - resolvedContentBoxInset.verticalAxisSum();
            final inflowContentHeight = intrinsicOuterHeight - resolvedContentBoxInset.verticalAxisSum();
            final freeSpace = containerInnerHeight - inflowContentHeight;
            final groupOffset = computeBlockAlignContentOffset(alignContent, freeSpace);
            if (firstBaseline.isSome())
                firstBaseline = OptionalFloat.some(firstBaseline.unwrap() + groupOffset);
            var anyInFlow = false;
            for (item in items) {
                final layout = item.finalLayout;
                if (layout != null) {
                    item.finalLayout = layout.withLocation(new Point(layout.location.x, layout.location.y + groupOffset));
                    anyInFlow = true;
                }
                // The static positions of out-of-flow children move with the in-flow content
                if (item.position.isOutOfFlow()) {
                    item.staticY = item.staticY + groupOffset;
                }
            }
            if (anyInFlow) {
                inflowOverflowRect = Rect.ZERO;
                for (item in items) {
                    final layout = item.finalLayout;
                    if (layout != null) {
                        final isRtlLocation = direction.isRtl();
                        final contributionLocation = new Point(isRtlLocation ? containerOuterWidth - (layout.location.x + layout.size.width) - resolvedBorder.right : layout.location.x - resolvedBorder.left, layout.location.y - resolvedBorder.top);
                        inflowOverflowRect = inflowOverflowRect.union(ScrollableOverflow.computeScrollableOverflowContribution(
                            contributionLocation,
                            layout.size,
                            layout.scrollableOverflowRect,
                            item.overflow,
                            item.contain,
                            isScrollContainer
                        ));
                    }
                }
            }
        }

        // Determine whether this node can be collapsed through
        var allInFlowChildrenCanBeCollapsedThrough = true;
        for (item in items) {
            if (item.float.isFloated())
                continue;
            if (!(item.position.isOutOfFlow() || item.canBeCollapsedThrough)) {
                allInFlowChildrenCanBeCollapsedThrough = false;
                break;
            }
        }
        // CSS2 8.3.1: a box's top and bottom margins collapse through it only if its *used* height is zero
        final canBeCollapsedThrough = !hasStylesPreventingBeingCollapsedThrough
            && containerOuterHeight == 0.0
            && allInFlowChildrenCanBeCollapsedThrough;

        final output = new LayoutOutput(
            finalOuterSize,
            Rect.ZERO,
            Baselines.fromFirst(firstBaseline),
            ownMarginsCollapseWithChildren.start
                ? firstChildTopMarginSet
                : CollapsibleMarginSet.fromMargin(rawMargin.top.resolveOrZero(parentSize.width)).share(),
            ownBottomMarginCollapsesWithChildren
                ? lastChildBottomMarginSet
                : CollapsibleMarginSet.fromMargin(rawMargin.bottom.resolveOrZero(parentSize.width)).share(),
            canBeCollapsedThrough
        );

        // Short-circuit if computing size.
        //
        // Note: it is important that we return the margin-collapsing related outputs here as Parent block containers
        // rely on the `topMargin`/`bottomMargin` of their children to compute their own intrinsic height.
        if (runMode == ComputeSize) {
            return output;
        }

        // Commit deferred child layouts to the tree.
        for (item in items) {
            final layout = item.finalLayout;
            if (layout != null) {
                tree.setUnroundedLayout(item.nodeId, layout);
            }
        }

        // 4. Collect out-of-flow candidates in document order (direct out-of-flow children plus
        // candidates bubbled from in-flow children's subtrees). These are laid out by the
        // out-of-flow positioning pass (`Oof.computeOofLayout`), which runs after this algorithm.
        final candidates = new OofCandidates();
        for (item in items) {
            if (item.position.isOutOfFlow()) {
                // The static-position rectangle of an out-of-flow child of a block container spans
                // the container's content box in the inline axis, and is a zero-height line at the
                // child's hypothetical position in the block axis.
                final inlineArea = new Line(resolvedContentBoxInset.left, containerOuterWidth - resolvedContentBoxInset.right);
                final blockArea = new Line(item.staticY, item.staticY);
                // A `justifySelf` of null takes the container's `justify-items`. Block containers have
                // no `align-items`, so an `alignSelf` of null behaves as `normal`.
                final justifySelf = (item.justifySelf != null ? (item.justifySelf : AlignItems) : justifyItems).resolveSelfRelative(item.direction, direction, true);
                final alignSelf = (item.alignSelf != null ? (item.alignSelf : AlignItems) : AlignItems.NORMAL).resolveSelfRelative(item.direction, direction, false);
                candidates.push(new OofCandidate(
                    item.nodeId,
                    item.order,
                    item.position,
                    new PointOf<AxisStaticPosition>(
                        AxisStaticPosition.fromAlignment(justifySelf, inlineArea, direction.isRtl()),
                        AxisStaticPosition.fromAlignment(alignSelf, blockArea, false)
                    )
                ));
            }
            else if (!item.oofCandidates.isEmpty()) {
                // Translate anchors from item-relative to container-relative coordinates
                final layout = item.finalLayout;
                if (layout != null) {
                    item.oofCandidates.translate(layout.location);
                }
                candidates.append(item.oofCandidates);
            }
        }

        final absolutePositionInset = resolvedBorder.add(scrollbarGutter);
        final absolutePositionArea = finalOuterSize.sub(absolutePositionInset.sumAxes());
        final absolutePositionOffset = new Point(absolutePositionInset.left, absolutePositionInset.top);
        output.oofCandidates = candidates;
        output.oofPositioningArea = new OofPositioningArea(absolutePositionArea, absolutePositionOffset);

        // A scroll container's own padding at the end of the content is part of its scrollable
        // overflow region, so it is included in the in-flow overflow rect.
        if (isScrollContainer) {
            inflowOverflowRect = new Rect(
                inflowOverflowRect.left,
                inflowOverflowRect.right + (direction.isRtl() ? resolvedPadding.left : resolvedPadding.right),
                inflowOverflowRect.top,
                inflowOverflowRect.bottom + resolvedPadding.bottom
            );
        }
        output.scrollableOverflowRect = inflowOverflowRect;

        // 5. Perform hidden layout on hidden children
        final len = tree.childCount(nodeId);
        for (order in 0...len) {
            final child = tree.getChildId(nodeId, order);
            final childStyle = tree.getBlockChildStyle(child);
            if (childStyle.boxGenerationMode() == BoxGenerationMode.None) {
                tree.setUnroundedLayout(child, Layout.withOrder(order));
                tree.performChildLayout(child, SizeOpt.NONE, SizeOpt.NONE, SizeAvail.MAX_CONTENT, InherentSize, FALSE_LINE);
            }
        }

        return output;
    }

    /** Create an array of `BlockItem` where each item represents a child of the current node */
    static function generateItemList(tree:LayoutBlockContainer, node:NodeId, nodeInnerSize:SizeOpt, items:Array<BlockItem>):Array<BlockItem> {
        items.resize(0);
        final count = tree.childCount(node);
        var order = 0;
        for (i in 0...count) {
            final childNodeId = tree.getChildId(node, i);
            final childStyle = tree.getBlockChildStyle(childNodeId);
            if (childStyle.boxGenerationMode() == BoxGenerationMode.None)
                continue;

            // The geometry stored in the item is shared when it is zero or absent (the common case);
            // intermediate values are inline and allocate nothing
            final aspectRatio = childStyle.aspectRatio;
            final padding = childStyle.padding.resolveOrZero(nodeInnerSize.width);
            final border = childStyle.border.resolveOrZero(nodeInnerSize.width);
            final pbSum = padding.add(border).sumAxes();
            final contentBox = childStyle.boxSizing == ContentBox;
            final boxSizingAdjustment = new Size(contentBox ? pbSum.width : 0.0, contentBox ? pbSum.height : 0.0);
            final position = childStyle.position;
            final overflow = childStyle.overflow;
            final float = childStyle.float;
            final isNotFloated = float == CssFloat.None;
            final isBlock = childStyle.isBlock();
            final isTable = childStyle.isTable();
            final isScrollContainer = overflow.x.isScrollContainer() || overflow.y.isScrollContainer();
            final contain = childStyle.contain;
            final isInSameBfc = isBlock
                && !isTable
                && !position.isOutOfFlow()
                && isNotFloated
                && !isScrollContainer
                && !contain.establishesIndependentFormattingContext()
                && childStyle.alignContent.keyword == AlignContentKeyword.Normal;

            final poolIndex = itemPoolTop++;
            if (poolIndex == itemPool.length)
                itemPool.push(new BlockItem());
            final item = itemPool[poolIndex];
            item.resetState();
            item.nodeId = childNodeId;
            item.order = order;
            item.isTable = isTable;
            item.isCompressibleReplaced = childStyle.isCompressibleReplaced();
            item.isInSameBfc = isInSameBfc;
            item.float = float;
            item.clear = childStyle.clear;
            item.sizeStyle = childStyle.size;
            final size = childStyle.size.maybeResolve(nodeInnerSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);
            final minSize = childStyle.minSize.maybeResolve(nodeInnerSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);
            final maxSize = childStyle.maxSize.maybeResolve(nodeInnerSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);
            item.size = SizeOpt.shared(size.width, size.height);
            item.minSize = SizeOpt.shared(minSize.width, minSize.height);
            item.maxSize = SizeOpt.shared(maxSize.width, maxSize.height);
            item.overflow = overflow;
            item.contain = contain;
            item.scrollbarWidth = childStyle.scrollbarWidth;
            item.position = position;
            item.direction = childStyle.direction;
            item.alignSelf = childStyle.alignSelf;
            item.justifySelf = childStyle.justifySelf;
            item.inset = childStyle.inset;
            item.margin = childStyle.margin;
            item.padding = Rect.shared(padding.left, padding.right, padding.top, padding.bottom);
            item.border = Rect.shared(border.left, border.right, border.top, border.bottom);
            item.paddingBorderSum = Size.shared(pbSum.width, pbSum.height);
            items.push(item);
            order++;
        }
        return items;
    }

    /**
     * Resolve the `stretch` sizing keyword for an item's height style. In the block axis the
     * intrinsic sizing keywords are all equal to the content size, which is what an auto height already
     * resolves to, so only `stretch` requires explicit resolution.
     *
     * Each of the item's block-axis margins is subtracted from the stretch size unless it is
     * flagged in `marginsTreatedAsZero`.
     */
    static inline function resolveStretchHeight(heightStyle:Dimension, containerInnerHeight:OptionalFloat, itemMargin:Rect, marginsTreatedAsZero:LineOf<Bool>):OptionalFloat {
        if (!heightStyle.isStretch() || containerInnerHeight.isNone())
            return OptionalFloat.NONE;
        var height:Float = containerInnerHeight.unwrap();
        if (!marginsTreatedAsZero.start)
            height -= itemMargin.top;
        if (!marginsTreatedAsZero.end)
            height -= itemMargin.bottom;
        return OptionalFloat.some(height);
    }

    /** Compute the content-based width in the case that the width of the container is not known */
    static function determineContentBasedContainerWidth(tree:LayoutPartialTree, items:Array<BlockItem>, availableWidth:AvailableSpace):Float {
        var maxChildWidth = 0.0;
        // Created at the first float (without floats its result is +0)
        var floatContribution:Null<FloatIntrinsicWidthCalculator> = null;
        for (item in items) {
            if (item.position.isOutOfFlow())
                continue;
            final clampedSize = item.size.maybeClamp(item.minSize, item.maxSize);
            final knownDimensions = SizeOpt.shared(clampedSize.width, clampedSize.height);
            final itemXMarginSum = item.margin.resolveOrZero(availableWidth.intoOption()).horizontalAxisSum();

            var width:Float;
            if (knownDimensions.width.isSome()) {
                width = knownDimensions.width.unwrap();
            }
            else {
                final itemAvailableWidth = switch SizingKeyword.resolveSizingKeyword(item.sizeStyle.width, OptionalFloat.NONE, OptionalFloat.NONE) {
                    case Measure(aw): aw;
                    case Exact(w): Definite(w);
                    case null: availableWidth.maybeSub(OptionalFloat.some(itemXMarginSum));
                }
                width = tree.measureChildSize(
                    item.nodeId,
                    knownDimensions,
                    SizeOpt.NONE,
                    new SizeAvail(itemAvailableWidth, MinContent),
                    InherentSize,
                    Horizontal,
                    // Must match the value passed when laying the item out (see `Cache`)
                    item.isInSameBfc ? TRUE_LINE : FALSE_LINE
                );
            }
            width = Sys.f32Max(width, item.paddingBorderSum.width) + itemXMarginSum;

            final floatDirection = item.float.floatDirection();
            if (floatDirection != null) {
                if (floatContribution == null)
                    floatContribution = new FloatIntrinsicWidthCalculator(availableWidth);
                floatContribution.addFloat(width, floatDirection, item.clear);
                continue;
            }

            maxChildWidth = Sys.f32Max(maxChildWidth, width);
        }

        maxChildWidth = Sys.f32Max(maxChildWidth, floatContribution != null ? floatContribution.result() : 0.0);

        return maxChildWidth;
    }

    /** Compute each child's final size and position */
    static function performFinalLayoutOnInFlowChildren(
        tree:LayoutBlockContainer,
        runMode:RunMode,
        items:Array<BlockItem>,
        containerOuterWidth:Float,
        containerPercentageResolutionHeight:OptionalFloat,
        contentBoxInset:Rect,
        resolvedContentBoxInset:Rect,
        resolvedBorder:Rect,
        textAlign:TextAlign,
        justifyItems:AlignItems,
        direction:Direction,
        ownMarginsCollapseWithChildren:LineOf<Bool>,
        childrenMarginsAdjoinOwnEdges:LineOf<Bool>,
        isScrollContainer:Bool,
        blockCtx:BlockContext
    ):InFlowResult {
        // Resolve containerInnerWidth for sizing child nodes using initial contentBoxInset
        final containerInnerWidth = Sys.f32Max(containerOuterWidth - resolvedContentBoxInset.horizontalAxisSum(), 0.0);
        final containerPercentageResolutionHeight = containerPercentageResolutionHeight.maybeSub(OptionalFloat.some(resolvedContentBoxInset.verticalAxisSum()));
        final parentSize = new SizeOpt(OptionalFloat.some(containerInnerWidth), containerPercentageResolutionHeight);

        // TODO: handle nested blocks with different widths
        if (blockCtx.isBfcRoot()) {
            blockCtx.setWidth(containerOuterWidth);
            blockCtx.applyContentBoxInset(resolvedContentBoxInset.left, resolvedContentBoxInset.right);
        }

        // If this block's top margin does not collapse with its children's then the position of its
        // top margin strut is resolved relative to it, and floats adjoining ancestor struts do not
        // adjoin this block's strut.
        if (!ownMarginsCollapseWithChildren.start) {
            blockCtx.commitStrut();
        }

        // The in-flow overflow rect (`Rect`, starting at zero), as four values until it is returned
        var overflowLeft = 0.0;
        var overflowRight = 0.0;
        var overflowTop = 0.0;
        var overflowBottom = 0.0;
        var committedYOffset = resolvedContentBoxInset.top;
        var yOffsetForAbsolute = resolvedContentBoxInset.top;
        var firstChildTopMarginSet = CollapsibleMarginSet.ZERO;
        var activeCollapsibleMarginSet = CollapsibleMarginSet.ZERO;
        var isCollapsingWithFirstMarginSet = true;
        var firstBaseline:OptionalFloat = OptionalFloat.NONE;
        // Whether the active margin set contains the margins of a self-collapsing element with
        // clearance. Such margins collapse with the margins of following siblings but the resulting
        // margin does not collapse with the bottom margin of the parent block.
        var activeMarginSetHasClearance = false;

        var hasActiveFloats = blockCtx.hasActiveFloats(committedYOffset);

        for (item in items) {
            if (item.position.isOutOfFlow()) {
                item.staticY = yOffsetForAbsolute;
                continue;
            }

            final m = item.margin;
            final itemMargin = new RectOpt(
                m.left.resolveToOption(containerInnerWidth),
                m.right.resolveToOption(containerInnerWidth),
                m.top.resolveToOption(containerInnerWidth),
                m.bottom.resolveToOption(containerInnerWidth)
            );
            final itemNonAutoMargin = new Rect(
                itemMargin.left.unwrapOr(0.0),
                itemMargin.right.unwrapOr(0.0),
                itemMargin.top.unwrapOr(0.0),
                itemMargin.bottom.unwrapOr(0.0)
            );
            final itemNonAutoXMarginSum = itemNonAutoMargin.horizontalAxisSum();

            final scrollbarSize = Size.shared(
                item.overflow.y == Scroll ? item.scrollbarWidth : 0.0,
                item.overflow.x == Scroll ? item.scrollbarWidth : 0.0
            );

            // Handle floated boxes
            final floatDirection = item.float.floatDirection();
            if (floatDirection != null) {
                hasActiveFloats = true;

                // A float with `width: auto` is shrink-to-fit (fit-content) sized: the available
                // space clamped between its min-content and max-content sizes.
                final availableWidth = Sys.f32Max(containerInnerWidth - itemNonAutoXMarginSum, 0.0);
                var itemKnownWidth:OptionalFloat = OptionalFloat.NONE;
                var itemAvailableWidth:AvailableSpace;
                switch SizingKeyword.resolveSizingKeyword(item.sizeStyle.width, OptionalFloat.some(availableWidth), OptionalFloat.some(containerInnerWidth)) {
                    case Measure(available):
                        itemAvailableWidth = available;
                    case Exact(width):
                        itemKnownWidth = OptionalFloat.some(width);
                        itemAvailableWidth = Definite(width);
                    case null:
                        itemAvailableWidth = Definite(availableWidth);
                }
                final itemKnownHeight = resolveStretchHeight(
                    item.sizeStyle.height,
                    containerPercentageResolutionHeight,
                    itemNonAutoMargin,
                    // The margins of a float never collapse
                    FALSE_LINE
                );
                final itemLayout = tree.performChildLayout(
                    item.nodeId,
                    new SizeOpt(itemKnownWidth, itemKnownHeight),
                    parentSize,
                    new SizeAvail(itemAvailableWidth, MaxContent),
                    InherentSize,
                    // A float establishes a new block formatting context: its margins do not
                    // collapse with the margins of its children
                    FALSE_LINE
                );
                item.oofCandidates = itemLayout.oofCandidates.take();
                final marginBox = itemLayout.size.add(itemNonAutoMargin.sumAxes());

                // Floats that occur between collapsing margins are positioned as if they had an otherwise
                // empty anonymous block parent taking part in the flow, so the pending collapsible margins
                // contribute to the float's minimum y position (unless those margins collapse with the
                // container's own top margin, in which case they are applied outside the container).
                final adjoinsUnresolvedStrut = isCollapsingWithFirstMarginSet && ownMarginsCollapseWithChildren.start;
                final yOffsetForFloat = adjoinsUnresolvedStrut
                    ? committedYOffset
                    : committedYOffset + activeCollapsibleMarginSet.resolve();
                final placed = blockCtx.placeFloatedBox(marginBox, yOffsetForFloat, floatDirection, item.clear, adjoinsUnresolvedStrut);

                // Convert the margin-box location returned by float placement into a border-box location for the output Layout
                final location = new Point(placed.x + itemNonAutoMargin.left, placed.y + itemNonAutoMargin.top);

                // Deferred to the post-loop pass in `computeInner` (like in-flow items) so that
                // `align-content` can shift `location.y` before the layout is committed.
                item.finalLayout = new Layout(
                    item.order,
                    location,
                    itemLayout.size,
                    itemLayout.scrollableOverflowRect,
                    scrollbarSize,
                    item.border,
                    item.padding,
                    // A copy: `itemNonAutoMargin` itself stays inline (allocates nothing)
                    Rect.shared(itemNonAutoMargin.left, itemNonAutoMargin.right, itemNonAutoMargin.top, itemNonAutoMargin.bottom)
                );

                // TODO: Should the overflow of floated boxes count as "inflowOverflowRect" or should it be counted separately?
                final isRtlLocation = direction.isRtl();
                final contributionLocation = new Point(isRtlLocation ? containerOuterWidth - (location.x + itemLayout.size.width) - resolvedBorder.right : location.x - resolvedBorder.left, location.y - resolvedBorder.top);
                final contribution = ScrollableOverflow.computeScrollableOverflowContribution(
                    contributionLocation,
                    itemLayout.size,
                    itemLayout.scrollableOverflowRect,
                    item.overflow,
                    item.contain,
                    isScrollContainer
                );
                overflowLeft = Sys.f32Min(overflowLeft, contribution.left);
                overflowRight = Sys.f32Max(overflowRight, contribution.right);
                overflowTop = Sys.f32Min(overflowTop, contribution.top);
                overflowBottom = Sys.f32Max(overflowBottom, contribution.bottom);
                continue;
            }

            // Handle non-floated boxes

            var yMarginOffset:Float = 0.0;
            var itemAvoidsFloats = false;
            var itemPushedBelowFloat = false;

            var stretchWidth:Float;
            var floatAvoidingPositionX:Float;
            var floatAvoidingPositionY:Float;
            var floatAvoidingWidth:Float;
            if (item.isInSameBfc) {
                stretchWidth = Sys.f32Max(containerInnerWidth - itemNonAutoXMarginSum, 0.0);
                floatAvoidingPositionX = 0.0;
                floatAvoidingPositionY = 0.0;
                floatAvoidingWidth = 0.0;
            }
            else {
                // Set yMarginOffset (different bfc child)
                if (!isCollapsingWithFirstMarginSet || !ownMarginsCollapseWithChildren.start) {
                    yMarginOffset = activeCollapsibleMarginSet.collapseWithMargin(itemNonAutoMargin.top).resolve();
                }

                final minY = committedYOffset + yMarginOffset;

                // In addition to the running flag, check the float context directly:
                // floats placed by the subtree of a preceding in-flow sibling (in the same
                // BFC) are not reflected in the flag
                if (hasActiveFloats || blockCtx.hasActiveFloats(minY)) {
                    // An auto width resolves to at least the negation of the margin sum
                    final minAutoWidth = -itemNonAutoXMarginSum;

                    // Find the highest slot (at or below `minY`) with enough horizontal space
                    // for the item's border box, which must not overlap any float
                    var slot = blockCtx.findBfcSlot(minY, itemNonAutoMargin.left, itemNonAutoMargin.right, direction, item.clear, -1);
                    while (slot.segmentId != -1) {
                        final w = item.size.width.isSome()
                            ? item.size.width.unwrap()
                            : Sys.f32Max(Sys.f32Max(slot.stretchWidth, minAutoWidth), 0.0);
                        final width = w.maybeClampF(item.minSize.width, item.maxSize.width);
                        if (width <= slot.borderWidth + FloatContext.FIT_TOLERANCE)
                            break;
                        slot = blockCtx.findBfcSlot(minY, itemNonAutoMargin.left, itemNonAutoMargin.right, direction, item.clear, slot.segmentId);
                    }

                    // If the item had to move down to avoid floats then it "separates from the
                    // float": similarly to clearance, its top margin no longer collapses with the parent's margins.
                    if (slot.y > minY) {
                        itemPushedBelowFloat = true;
                    }

                    hasActiveFloats = slot.segmentId != -1;
                    itemAvoidsFloats = true;
                    stretchWidth = Sys.f32Max(Sys.f32Max(slot.stretchWidth, minAutoWidth), 0.0);
                    floatAvoidingPositionX = slot.x;
                    floatAvoidingPositionY = slot.y;
                    floatAvoidingWidth = slot.borderWidth;
                }
                else {
                    stretchWidth = Sys.f32Max(containerInnerWidth - itemNonAutoXMarginSum, 0.0);
                    floatAvoidingPositionX = resolvedContentBoxInset.left;
                    floatAvoidingPositionY = minY;
                    floatAvoidingWidth = containerInnerWidth;
                }
            }

            // `justify-self` on an in-flow block-level box (css-align-3 6.1.1). Null takes the
            // container's `justify-items`, and `normal` lays the box out according to the default
            // block layout rules. `stretch` does too.
            final justifySelf = (item.justifySelf != null ? (item.justifySelf : AlignItems) : justifyItems).resolveSelfRelative(item.direction, direction, true);
            final isStretch = justifySelf.keyword == AlignItemsKeyword.Stretch;
            // Whether the (resolved) `justify-self` is neither `normal` nor `stretch`
            final hasNonStretchJustifySelf = !(justifySelf.keyword == AlignItemsKeyword.Normal || justifySelf.keyword == AlignItemsKeyword.Stretch);

            // Unless stretched, tables and compressible replaced elements resolve their own width
            var knownDimensions:SizeOpt;
            if ((item.isTable || item.isCompressibleReplaced) && !isStretch) {
                knownDimensions = SizeOpt.NONE;
            }
            else {
                // The automatic width of a block-level box whose `justify-self` is neither `normal` nor `stretch`
                // is equivalent to `fit-content` rather than `stretch`
                final widthStyle = (hasNonStretchJustifySelf && item.sizeStyle.width.isAuto()) ? Dimension.fitContent() : item.sizeStyle.width;

                // Items with a sizing keyword width resolve their width either directly or by measuring
                // the item under the corresponding available space constraint
                final keywordWidth:OptionalFloat = switch SizingKeyword.resolveSizingKeyword(widthStyle, OptionalFloat.some(stretchWidth), OptionalFloat.some(containerInnerWidth)) {
                    case Exact(width): OptionalFloat.some(width);
                    case Measure(itemAvailableWidth):
                        OptionalFloat.some(tree.measureChildSize(
                            item.nodeId,
                            SizeOpt.NONE,
                            parentSize,
                            new SizeAvail(itemAvailableWidth, MaxContent),
                            InherentSize,
                            Horizontal,
                            // Must match the value passed when laying the item out (see `Cache`)
                            item.isInSameBfc ? TRUE_LINE : FALSE_LINE
                        ));
                    case null: OptionalFloat.NONE;
                }
                final keywordHeight = resolveStretchHeight(
                    item.sizeStyle.height,
                    containerPercentageResolutionHeight,
                    itemNonAutoMargin,
                    childrenMarginsAdjoinOwnEdges
                );
                final w:Float = item.size.width.isSome() ? item.size.width.unwrap() : (keywordWidth.isSome() ? keywordWidth.unwrap() : stretchWidth);
                knownDimensions = new SizeOpt(
                    OptionalFloat.some(w.maybeClampF(item.minSize.width, item.maxSize.width)),
                    item.size.height.isSome() ? item.size.height : keywordHeight
                ).maybeClamp(item.minSize, item.maxSize);
            }

            final inputs = LayoutInput.acquire(
                runMode,
                InherentSize,
                Both,
                knownDimensions,
                TRUE_SIZE,
                parentSize,
                // Vertical available space in block flow is indefinite (MaxContent), not a min-content constraint
                new SizeAvail(Definite(stretchWidth), MaxContent),
                item.isInSameBfc ? TRUE_LINE : FALSE_LINE
            );

            final clearThreshold = blockCtx.clearedThreshold(item.clear);
            final clearPos:Float = clearThreshold.isSome() ? clearThreshold.unwrap() : Math.NEGATIVE_INFINITY;

            // The height consumed by floats within a same-BFC child, relative to the child's
            // border-top. Added to the parent's contribution once the child's position is known.
            var childFloatContribution = Math.NEGATIVE_INFINITY;

            final itemLayout:LayoutOutput = if (item.isInSameBfc) {
                // Replaced elements may not have a known width (they are sized by their
                // measure function rather than stretch-sized)
                final width = Sys.f32Max(knownDimensions.width.unwrapOr(stretchWidth), item.paddingBorderSum.width);
                // TODO: account for auto margins
                final insetLeft = itemNonAutoMargin.left + contentBoxInset.left;
                final insetRight = containerOuterWidth - width - insetLeft;

                // Compute child layout. The child's position is estimated from its top margin collapsed with
                // the preceding margins (the child's own collapsed-through margins are not yet known).
                final estimatedY = committedYOffset + activeCollapsibleMarginSet.collapseWithMargin(itemNonAutoMargin.top).resolve();
                // `blockCtx.subContext(...)`, reused: the child context does not outlive this block
                final subIndex = subContextPoolTop++;
                final childBlockCtx = if (subIndex == subContextPool.length) {
                    final created = blockCtx.subContext(Sys.f32Max(estimatedY, clearPos), insetLeft, insetRight);
                    subContextPool.push(created);
                    created;
                }
                else {
                    blockCtx.subContextInto(subContextPool[subIndex], Sys.f32Max(estimatedY, clearPos), insetLeft, insetRight);
                }
                final output = tree.computeBlockChildLayout(item.nodeId, inputs, childBlockCtx);

                // Extract float contribution from child block context
                childFloatContribution = childBlockCtx.floatedContentHeightContribution();
                // Floats placed while the position of the child's top margin strut was unresolved
                // also adjoin this block's current strut
                blockCtx.mergeAdjoiningFloats(childBlockCtx.getTopAdjoiningFloats());
                subContextPoolTop = subIndex;

                output;
            }
            else {
                tree.computeChildLayout(item.nodeId, inputs);
            }
            LayoutInput.release();
            item.oofCandidates = itemLayout.oofCandidates.take();
            final finalSize = itemLayout.size;

            final topMarginSet = itemLayout.topMargin.collapseWithMargin(itemMargin.top.unwrapOr(0.0)).share();
            final bottomMarginSet = itemLayout.bottomMargin.collapseWithMargin(itemMargin.bottom.unwrapOr(0.0)).share();

            // Expand auto margins to fill available space
            // Note: Vertical auto-margins for relatively positioned block items simply resolve to 0.
            final freeXSpace = Sys.f32Max(0.0, stretchWidth - finalSize.width);
            final autoMarginCount = (itemMargin.left.isNone() ? 1 : 0) + (itemMargin.right.isNone() ? 1 : 0);
            final xAxisAutoMarginSize = autoMarginCount > 0 ? freeXSpace / autoMarginCount : 0.0;
            // The resolved margin (`Rect`), as four values until it is stored in the layout
            var resolvedMarginLeft:Float = itemMargin.left.unwrapOr(xAxisAutoMarginSize);
            var resolvedMarginRight:Float = itemMargin.right.unwrapOr(xAxisAutoMarginSize);
            final resolvedMarginTop:Float = itemMargin.top.unwrapOr(0.0);
            final resolvedMarginBottom:Float = itemMargin.bottom.unwrapOr(0.0);

            // Resolve item inset
            final insetPercentageBasis = new SizeOpt(OptionalFloat.some(containerInnerWidth), containerPercentageResolutionHeight);
            final inset = item.inset.maybeResolveBySize(insetPercentageBasis);
            var insetOffsetX = 0.0;
            var insetOffsetY = 0.0;
            if (item.position == Relative) {
                final negRight:OptionalFloat = inset.right.isSome() ? OptionalFloat.some(-inset.right.unwrap()) : OptionalFloat.NONE;
                final negBottom:OptionalFloat = inset.bottom.isSome() ? OptionalFloat.some(-inset.bottom.unwrap()) : OptionalFloat.NONE;
                insetOffsetX = direction.isRtl() ? negRight.or(inset.left).unwrapOr(0.0) : inset.left.or(negRight).unwrapOr(0.0);
                insetOffsetY = inset.top.or(negBottom).unwrapOr(0.0);
            }

            // Set yMarginOffset (same bfc child)
            if (item.isInSameBfc && (!isCollapsingWithFirstMarginSet || !ownMarginsCollapseWithChildren.start)) {
                yMarginOffset = activeCollapsibleMarginSet.collapseWithSet(topMarginSet).resolve();
            }

            // Compute clearance (CSS2.2 9.5.2). Clearance is introduced if the hypothetical position of the
            // item's top border edge (the position it would have with normal margin collapsing) is not past
            // the bottom of the relevant floats. When clearance is introduced the item's border edge is
            // placed at `max(float bottom, hypothetical position)`.
            var hasClearance = false;
            if (item.isInSameBfc && clearThreshold.isSome()) {
                final threshold:Float = clearThreshold.unwrap();
                // The hypothetical position always includes the item's collapsed top margin set, even
                // when those margins collapse with the container's own top margin.
                final hypotheticalY = committedYOffset + activeCollapsibleMarginSet.collapseWithSet(topMarginSet).resolve();
                // Clearance is forced (regardless of the hypothetical position) if a relevant float is
                // adjoining the margin-collapse strut that the item's top margin would collapse into.
                final forcedClearance = blockCtx.hasAdjoiningFloat(item.clear);
                if (forcedClearance || hypotheticalY < threshold) {
                    hasClearance = true;
                    // Clearance stops the item's top margin collapsing with preceding margins. If those
                    // preceding margins collapse with the container's own top margin they are applied
                    // outside the container (moving it down), so the item's cleared position within the
                    // container must be reduced by that amount to keep its absolute position correct.
                    final escapedMargin = (isCollapsingWithFirstMarginSet && ownMarginsCollapseWithChildren.start)
                        ? activeCollapsibleMarginSet.resolve()
                        : 0.0;
                    yMarginOffset = threshold - committedYOffset - escapedMargin;
                }
            }

            item.computedSize = itemLayout.size;
            item.canBeCollapsedThrough = itemLayout.marginsCanCollapseThrough && !hasClearance;
            if (item.isInSameBfc) {
                final unclearedY = committedYOffset + activeCollapsibleMarginSet.resolve();
                item.staticY = Sys.f32Max(unclearedY, clearPos);
            }
            else {
                // TODO: handle inset and margins
                item.staticY = floatAvoidingPositionY;
            }

            var locationX:Float;
            var locationY:Float;
            if (item.isInSameBfc) {
                locationX = direction == Ltr
                    ? resolvedContentBoxInset.left + insetOffsetX + resolvedMarginLeft
                    : containerOuterWidth - resolvedContentBoxInset.right - finalSize.width - resolvedMarginRight + insetOffsetX;
                locationY = committedYOffset + yMarginOffset + insetOffsetY;
            }
            else {
                // When the item avoids floats, its non-auto margins are already accounted for in the
                // slot's border-box position/width (margins may overlap floats), so only the auto
                // portion of the resolved margin is added here.
                final extraMarginLeft = itemAvoidsFloats ? resolvedMarginLeft - itemNonAutoMargin.left : resolvedMarginLeft;
                final extraMarginRight = itemAvoidsFloats ? resolvedMarginRight - itemNonAutoMargin.right : resolvedMarginRight;
                // TODO: handle inset and margins
                locationX = direction == Ltr
                    ? floatAvoidingPositionX + extraMarginLeft + insetOffsetX
                    : floatAvoidingPositionX + floatAvoidingWidth - finalSize.width - extraMarginRight + insetOffsetX;
                locationY = floatAvoidingPositionY + insetOffsetY;
            }

            // Floats within the child are positioned relative to the child's border-top, so the
            // child's (margin-collapsed) position, rather than its relative offset, is added.
            if (item.isInSameBfc) {
                blockCtx.addChildFloatedContentHeightContribution(locationY - insetOffsetY + childFloatContribution);
            }

            // Apply alignment. `justify-self` aligns the item's margin box within its alignment
            // container and takes precedence over legacy `text-align`, but auto margins (which have
            // already absorbed the free space) take precedence over `justify-self`.
            final hasAutoXMargin = itemMargin.left.isNone() || itemMargin.right.isNone();
            final itemOuterWidth = itemLayout.size.width + (resolvedMarginLeft + resolvedMarginRight);
            if (hasNonStretchJustifySelf && !hasAutoXMargin) {
                // The alignment container is the containing block, except that a BFC-establishing
                // box placed next to a float aligns within the space left over by the float.
                var containerStart:Float;
                var freeSpace:Float;
                if (itemAvoidsFloats) {
                    containerStart = floatAvoidingPositionX - resolvedMarginLeft;
                    freeSpace = floatAvoidingWidth - itemLayout.size.width;
                }
                else {
                    containerStart = resolvedContentBoxInset.left;
                    freeSpace = containerInnerWidth - itemOuterWidth;
                }
                final keyword = (justifySelf.safety == AlignmentSafety.Safe && freeSpace < 0.0) ? AlignItemsKeyword.Start : justifySelf.keyword;
                final offset = switch keyword {
                    case AlignItemsKeyword.Center: freeSpace / 2.0;
                    case AlignItemsKeyword.End | AlignItemsKeyword.FlexEnd | AlignItemsKeyword.SelfEnd:
                        !direction.isRtl() ? freeSpace : 0.0;
                    case _:
                        direction.isRtl() ? freeSpace : 0.0;
                }
                locationX = containerStart + resolvedMarginLeft + insetOffsetX + offset;
            }
            else if (!hasNonStretchJustifySelf && itemOuterWidth < containerInnerWidth) {
                final freeSpace = containerInnerWidth - itemOuterWidth;
                switch textAlign {
                    case TextAlign.Auto:
                        // Do nothing
                    case TextAlign.LegacyLeft:
                        // Left aligned by default in LTR
                        if (direction == Rtl)
                            locationX -= freeSpace;
                    case TextAlign.LegacyRight:
                        // Right aligned by default in RTL
                        if (direction == Ltr)
                            locationX += freeSpace;
                    case TextAlign.LegacyCenter:
                        if (direction == Ltr)
                            locationX += freeSpace / 2.0;
                        else
                            locationX -= freeSpace / 2.0;
                }
            }

            // A block container's first baseline is the first baseline of its first in-flow child that has one.
            //
            // Scroll containers' baselines are determined from their content as if scrolled to the
            // initial position, but are additionally clamped to their border box. A scroll container
            // with no baseline synthesizes one from its border-box bottom edge.
            if (firstBaseline.isNone()) {
                var childBaseline:OptionalFloat;
                if (item.overflow.y.isScrollContainer()) {
                    final b = itemLayout.baselines.first;
                    childBaseline = OptionalFloat.some(Sys.f32Max(Sys.f32Min(b.isSome() ? b.unwrap() : itemLayout.size.height, itemLayout.size.height), 0.0));
                }
                else {
                    childBaseline = itemLayout.baselines.first;
                }
                firstBaseline = childBaseline.isSome() ? OptionalFloat.some(locationY + childBaseline.unwrap()) : OptionalFloat.NONE;
            }

            // Used auto margins include float-avoidance offsets, unlike the alignment margins above.
            if (itemAvoidsFloats) {
                if (itemMargin.left.isNone()) {
                    resolvedMarginLeft = resolvedMarginLeft + floatAvoidingPositionX - resolvedContentBoxInset.left;
                }
                if (itemMargin.right.isNone()) {
                    resolvedMarginRight = resolvedMarginRight + containerOuterWidth - resolvedContentBoxInset.right - floatAvoidingPositionX - floatAvoidingWidth;
                }
            }

            final location = new Point(locationX, locationY);

            // Defer `setUnroundedLayout` to the post-loop pass in `computeInner` so that
            // `align-content` can shift `location.y` before the layout is committed to the tree.
            item.finalLayout = new Layout(
                item.order,
                location,
                itemLayout.size,
                itemLayout.scrollableOverflowRect,
                scrollbarSize,
                item.border,
                item.padding,
                Rect.shared(resolvedMarginLeft, resolvedMarginRight, resolvedMarginTop, resolvedMarginBottom)
            );

            final isRtlLocation = direction.isRtl();
            final contributionLocation = new Point(isRtlLocation ? containerOuterWidth - (location.x + finalSize.width) - resolvedBorder.right : location.x - resolvedBorder.left, location.y - resolvedBorder.top);
            final contribution = ScrollableOverflow.computeScrollableOverflowContribution(
                contributionLocation,
                finalSize,
                itemLayout.scrollableOverflowRect,
                item.overflow,
                item.contain,
                isScrollContainer
            );
                overflowLeft = Sys.f32Min(overflowLeft, contribution.left);
                overflowRight = Sys.f32Max(overflowRight, contribution.right);
                overflowTop = Sys.f32Min(overflowTop, contribution.top);
                overflowBottom = Sys.f32Max(overflowBottom, contribution.bottom);

            // Update firstChildTopMarginSet
            //
            // The top margin of an item with clearance does not collapse with the container's top margin,
            // so clearance terminates collapsing without contributing the item's own margins.
            if (isCollapsingWithFirstMarginSet && itemPushedBelowFloat) {
                // The item's top margin "separated from the float" and must not propagate to the parent
                isCollapsingWithFirstMarginSet = false;
            }
            if (isCollapsingWithFirstMarginSet && hasClearance) {
                isCollapsingWithFirstMarginSet = false;
            }
            else if (isCollapsingWithFirstMarginSet) {
                if (item.canBeCollapsedThrough) {
                    firstChildTopMarginSet = firstChildTopMarginSet.collapseWithSet(topMarginSet).collapseWithSet(bottomMarginSet).share();
                }
                else {
                    firstChildTopMarginSet = firstChildTopMarginSet.collapseWithSet(topMarginSet).share();
                    isCollapsingWithFirstMarginSet = false;
                }
            }

            // Update activeCollapsibleMarginSet
            if (item.canBeCollapsedThrough) {
                activeCollapsibleMarginSet = activeCollapsibleMarginSet.collapseWithSet(topMarginSet).collapseWithSet(bottomMarginSet).share();
                yOffsetForAbsolute = committedYOffset + itemLayout.size.height + yMarginOffset;
            }
            else {
                committedYOffset = location.y - insetOffsetY + itemLayout.size.height;
                // A self-collapsing item with clearance is not collapsed through (its margins do not collapse
                // with margins of preceding siblings), but its top and bottom margins still collapse with each
                // other and with the margins of following siblings.
                if (hasClearance && itemLayout.marginsCanCollapseThrough) {
                    // The element's border edge stays at the cleared position, but its collapsed margin
                    // extends below it.
                    committedYOffset -= topMarginSet.resolve();
                    activeCollapsibleMarginSet = topMarginSet.collapseWithSet(bottomMarginSet).share();
                    activeMarginSetHasClearance = true;
                }
                else {
                    activeCollapsibleMarginSet = bottomMarginSet;
                    activeMarginSetHasClearance = false;
                }
                yOffsetForAbsolute = committedYOffset + activeCollapsibleMarginSet.resolve();
                // Committing in-flow content resolves the position of the current margin-collapse strut,
                // so floats placed before this point no longer force clearance
                blockCtx.commitStrut();
            }
        }

        // The margins of a self-collapsing element with clearance do not collapse with the bottom
        // margin of the parent block: they extend the parent's content height instead of escaping it
        final lastChildBottomMarginSet = activeMarginSetHasClearance ? CollapsibleMarginSet.ZERO : activeCollapsibleMarginSet;
        final bottomYMarginOffset = if (activeMarginSetHasClearance) {
            activeCollapsibleMarginSet.resolve();
        }
        else if (ownMarginsCollapseWithChildren.end) {
            0.0;
        }
        else {
            lastChildBottomMarginSet.resolve();
        }

        committedYOffset += resolvedContentBoxInset.bottom + bottomYMarginOffset;
        final contentHeight = Sys.f32Max(0.0, committedYOffset);
        return new InFlowResult(Rect.shared(overflowLeft, overflowRight, overflowTop, overflowBottom), contentHeight, firstChildTopMarginSet, lastChildBottomMarginSet, firstBaseline);
    }

}
