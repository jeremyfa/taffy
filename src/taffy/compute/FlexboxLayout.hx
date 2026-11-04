// Ported from taffy 0.15.0: src/compute/flexbox.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute;

import taffy.compute.common.Alignment;
import taffy.compute.common.ScrollableOverflow;
import taffy.compute.common.SizingKeyword;
import taffy.compute.flexbox.AlgoConstants;
import taffy.compute.flexbox.FlexBalance;
import taffy.compute.flexbox.FlexItem;
import taffy.compute.flexbox.FlexLine;
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
import taffy.style.AvailableSpace;
import taffy.style.BoxGenerationMode;
import taffy.style.BoxSizing;
import taffy.style.Direction;
import taffy.style.FlexDirection;
import taffy.style.Overflow;
import taffy.style.Position;
import taffy.style.Style;
import taffy.tree.AxisStaticAlign;
import taffy.tree.AxisStaticEdge;
import taffy.tree.AxisStaticPosition;
import taffy.tree.Baselines;
import taffy.tree.Layout;
import taffy.tree.LayoutFlexboxContainer;
import taffy.tree.LayoutInput;
import taffy.tree.LayoutOutput;
import taffy.tree.NodeId;
import taffy.tree.OofCandidate;
import taffy.tree.OofCandidates;
import taffy.tree.OofPositioningArea;
import taffy.tree.RequestedAxis;
import taffy.tree.RunMode;
import taffy.tree.SizingMode;
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
 * Mutable state of the final layout pass (Rust passes these as `&mut` parameters)
 */
private class FinalPassState {

    /** The cross offset of the current line */
    public var totalOffsetCross:Float = 0.0;

    /** The main offset of the current item */
    public var totalOffsetMain:Float = 0.0;

    /** The accumulated scrollable overflow rect */
    public var overflowRect:Rect = Rect.ZERO;

    public inline function new() {}

}

/**
 * Per call objects of the flexbox algorithm, reused between calls. Containers nest (an item is
 * measured while its container's items are alive), so there is one scratch per nesting level
 * (see `FlexboxLayout.computePreliminary`). Nothing in it outlives the call that uses it.
 */
private class FlexScratch {

    /** The flex items of the container */
    public final items:Array<FlexItem> = [];

    /** The algorithm constants of the container */
    public final constants:AlgoConstants = new AlgoConstants();

    /** The line of a single-line container */
    public final singleLine:FlexLine = new FlexLine(null);

    /** The lines of a single-line container (`[singleLine]`) */
    public final singleLineArray:Array<FlexLine> = [];

    public function new() {
        singleLineArray.push(singleLine);
    }

    /** `[new FlexLine(items)]`, reusing the line */
    public inline function singleLineOf(items:Array<FlexItem>):Array<FlexLine> {
        singleLine.items = items;
        singleLine.crossSize = 0.0;
        singleLine.offsetCross = 0.0;
        return singleLineArray;
    }

}

/**
 * Computes the [flexbox](https://css-tricks.com/snippets/css/a-guide-to-flexbox/) layout algorithm
 * according to the [spec](https://www.w3.org/TR/css-flexbox-1/)
 */
class FlexboxLayout {

    static final FALSE_LINE:LineOf<Bool> = new LineOf<Bool>(false, false);

    /** The scratch objects of each nesting level (see `computePreliminary`) */
    static final scratches:Array<FlexScratch> = [];

    /** The nesting level of the next `computePreliminary` call */
    static var scratchLevel:Int = 0;

    /**
     * The flex items of every container being laid out, as a stack: a container takes its items
     * from `itemPoolTop` and gives them back when it returns (nested containers take theirs above).
     */
    static final itemPool:Array<FlexItem> = [];

    static var itemPoolTop:Int = 0;

    /** The `marginIsAuto` of the items without auto margins (shared, it is never mutated) */
    static final NO_AUTO_MARGINS:RectOf<Bool> = new RectOf<Bool>(false, false, false, false);

    /** Computes the layout of a box according to the flexbox algorithm */
    public static function computeFlexboxLayout(tree:LayoutFlexboxContainer, node:NodeId, inputs:LayoutInput):LayoutOutput {
        final knownDimensions = inputs.knownDimensions;
        final parentSize = inputs.parentSize;
        final runMode = inputs.runMode;
        final style = tree.getFlexboxContainerStyle(node);

        // Pull these out earlier to avoid borrowing issues
        final contain = style.contain;
        final aspectRatio = style.aspectRatio;
        final padding = style.padding.resolveOrZero(parentSize.width);
        final border = style.border.resolveOrZero(parentSize.width);
        final paddingBorderSum = padding.sumAxes().add(border.sumAxes());
        final contentBox = style.boxSizing == BoxSizing.ContentBox;
        final boxSizingAdjustment = new Size(contentBox ? paddingBorderSum.width : 0.0, contentBox ? paddingBorderSum.height : 0.0);

        final minSize = style.minSize.maybeResolve(parentSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);
        final maxSize = style.maxSize.maybeResolve(parentSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);
        // Under `InherentSize` only (one object, which does not escape)
        final inherentSize = inputs.sizingMode == SizingMode.InherentSize;
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
        final minMaxDefiniteSize = new SizeOpt(
            minMaxDefinite(minSize.width, maxSize.width),
            minMaxDefinite(minSize.height, maxSize.height)
        );

        // The size of the container should be floored by the padding and border
        final styledKnown = knownDimensions.or(minMaxDefiniteSize.or(clampedStyleSize).maybeMaxSize(paddingBorderSum));
        final styledBasedKnownDimensions = SizeOpt.shared(styledKnown.width, styledKnown.height);

        // Short-circuit layout if the container's size is fully determined by the container's size and the run mode
        // is ComputeSize (and thus the container's size is all that we're interested in)
        if (runMode == RunMode.ComputeSize) {
            final w = styledBasedKnownDimensions.width;
            final h = styledBasedKnownDimensions.height;
            if (w.isSome() && h.isSome()) {
                return LayoutOutput.fromOuterSize(new Size(w.unwrap(), h.unwrap()));
            }

            // We can also short-circuit if the width is known and only the width has been requested.
            if (inputs.axis == RequestedAxis.Horizontal) {
                if (w.isSome()) {
                    return LayoutOutput.fromOuterSize(new Size(w.unwrap(), 0.0));
                }
            }
        }

        // Normalize the definiteness flags: they only apply to dimensions which were passed in as known
        // by the parent. Dimensions resolved from the node's own style are always definite.
        final knownDimensionsAreDefinite = boolSize(
            inputs.knownDimensionsAreDefinite.width || knownDimensions.width.isNone(),
            inputs.knownDimensionsAreDefinite.height || knownDimensions.height.isNone()
        );

        final output = computePreliminary(tree, node, LayoutInput.acquire(
            inputs.runMode,
            inputs.sizingMode,
            inputs.axis,
            styledBasedKnownDimensions,
            knownDimensionsAreDefinite,
            inputs.parentSize,
            inputs.availableSpace,
            inputs.verticalMarginsAreCollapsible
        ));
        LayoutInput.release();

        // Layout containment suppresses the box's baseline for baseline-alignment purposes
        if (contain.suppressesBaseline()) {
            output.baselines = Baselines.NONE;
        }

        return output;
    }

    static inline function minMaxDefinite(min:OptionalFloat, max:OptionalFloat):OptionalFloat {
        return (min.isSome() && max.isSome() && max.unwrap() <= min.unwrap()) ? min : OptionalFloat.NONE;
    }

    /**
     * Compute a preliminary size for an item.
     *
     * Takes the scratch objects of the current nesting level and the items above the pool top, and
     * gives them back on return. If a call throws, they are not given back: the next calls use
     * fresh levels and items above them, which stays correct.
     */
    static function computePreliminary(tree:LayoutFlexboxContainer, node:NodeId, inputs:LayoutInput):LayoutOutput {
        final level = scratchLevel;
        final itemMark = itemPoolTop;
        if (level == scratches.length)
            scratches.push(new FlexScratch());
        scratchLevel = level + 1;
        final output = computePreliminaryWith(tree, node, inputs, scratches[level]);
        scratchLevel = level;
        itemPoolTop = itemMark;
        return output;
    }

    static function computePreliminaryWith(tree:LayoutFlexboxContainer, node:NodeId, inputs:LayoutInput, scratch:FlexScratch):LayoutOutput {
        final knownDimensions = inputs.knownDimensions;
        final parentSize = inputs.parentSize;
        final runMode = inputs.runMode;

        // Define some general constants we will need for the remainder of the algorithm.
        final constants = computeConstants(
            scratch.constants,
            tree.getFlexboxContainerStyle(node),
            knownDimensions,
            inputs.knownDimensionsAreDefinite,
            parentSize,
            inputs.availableSpace
        );

        // 9. Flex Layout Algorithm

        // 9.1. Initial Setup

        // 1. Generate anonymous flex items as described in §4 Flex Items.
        final flexItems = generateAnonymousFlexItems(tree, node, constants, scratch.items);

        // 9.2. Line Length Determination

        // 2. Determine the available main and cross space for the flex items
        final availableSpace = determineAvailableSpace(knownDimensions, inputs.availableSpace, constants);

        // 3. Determine the flex base size and hypothetical main size of each item.
        determineFlexBaseSize(tree, constants, availableSpace, flexItems);

        // 4. Determine the main size of the flex container
        // This has already been done as part of computeConstants. The inner size is exposed as constants.nodeInnerSize.

        // 9.3. Main Size Determination

        // 5. Collect flex items into flex lines.
        final flexLines = if (constants.isBalance) {
            collectBalancedFlexLines(constants, availableSpace, flexItems);
        }
        else {
            collectFlexLines(constants, availableSpace, flexItems, scratch);
        }

        // If container size is undefined, determine the container's main size
        // and then re-resolve gaps based on newly determined size
        final innerMain = constants.nodeInnerSize.main(constants.dir);
        if (innerMain.isSome()) {
            final innerMainSize:Float = innerMain.unwrap();
            final outerMainSize = innerMainSize + constants.contentBoxInset.mainAxisSum(constants.dir);
            constants.innerContainerSize.setMain(constants.dir, innerMainSize);
            constants.containerSize.setMain(constants.dir, outerMainSize);
        }
        else {
            // Sets constants.containerSize and constants.outerContainerSize
            determineContainerMainSize(tree, availableSpace, flexLines, constants);
            constants.setNodeInnerMain(OptionalFloat.some(constants.innerContainerSize.main(constants.dir)));
            constants.setNodeOuterMain(OptionalFloat.some(constants.containerSize.main(constants.dir)));

            // Re-resolve percentage gaps
            final style = tree.getFlexboxContainerStyle(node);
            final innerContainerSize = constants.innerContainerSize.main(constants.dir);
            final newGap = style.gap.main(constants.dir).maybeResolve(OptionalFloat.some(innerContainerSize)).unwrapOr(0.0);
            constants.gap = constants.gap.withMain(constants.dir, newGap);
        }

        // If only the container's main size has been requested then we are done, as nothing below changes it. This
        // avoids measuring the cross size of every item.
        if (runMode == RunMode.ComputeSize) {
            final mainAxisIsRequestedAxis = switch inputs.axis {
                case RequestedAxis.Horizontal: constants.dir.isRow();
                case RequestedAxis.Vertical: constants.dir.isColumn();
                case _: false;
            }
            if (mainAxisIsRequestedAxis) {
                final size = Size.ZERO.withMain(constants.dir, constants.containerSize.main(constants.dir));
                return LayoutOutput.fromOuterSize(size);
            }
        }

        // 6. Resolve the flexible lengths of all the flex items to find their used main size.
        for (line in flexLines) {
            resolveFlexibleLengths(line, constants);
        }

        // 9.4. Cross Size Determination

        // 7. Determine the hypothetical cross size of each item.
        for (line in flexLines) {
            determineHypotheticalCrossSize(tree, line, constants, availableSpace);
        }

        // Calculate child baselines. This function is internally smart and only computes child baselines
        // if they are necessary.
        calculateChildrenBaseLines(tree, knownDimensions, availableSpace, flexLines, constants);

        // 8. Calculate the cross size of each flex line.
        calculateCrossSize(flexLines, knownDimensions, constants);

        // 9. Handle 'align-content: stretch'.
        handleAlignContentStretch(flexLines, knownDimensions, constants);

        // 10. Collapse visibility:collapse items. (Not supported: TODO implement once (if ever) we support visibility:collapse)

        // 11. Determine the used cross size of each flex item.
        determineUsedCrossSize(tree, flexLines, constants);

        // 9.5. Main-Axis Alignment

        // 12. Distribute any remaining free space.
        distributeRemainingFreeSpace(flexLines, constants);

        // 9.6. Cross-Axis Alignment

        // 13. Resolve cross-axis auto margins (also includes 14).
        resolveCrossAxisAutoMargins(flexLines, constants);

        // 15. Determine the flex container's used cross size.
        final totalLineCrossSize = determineContainerCrossSize(flexLines, knownDimensions, constants);

        // We have the container size.
        // If our caller does not care about performing layout we are done now.
        if (runMode == RunMode.ComputeSize) {
            return LayoutOutput.fromOuterSize(constants.containerSize.toSize());
        }

        // 16. Align all flex lines per align-content.
        alignFlexLinesPerAlignContent(flexLines, constants, totalLineCrossSize);

        // Do a final layout pass and gather the resulting layouts
        final inflowOverflowRect = finalLayoutPass(tree, flexLines, constants);

        // Collect out-of-flow candidates in document order (direct out-of-flow children interleaved
        // with candidates bubbled from in-flow children's subtrees). These are laid out by the
        // out-of-flow positioning pass (`computeOofLayout`), which runs after this algorithm.
        final candidates = collectOofCandidates(tree, node, constants, flexItems);

        final len = tree.childCount(node);
        for (order in 0...len) {
            final child = tree.getChildId(node, order);
            if (tree.getFlexboxChildStyle(child).boxGenerationMode() == BoxGenerationMode.None) {
                tree.setUnroundedLayout(child, Layout.withOrder(order));
                tree.performChildLayout(
                    child,
                    SizeOpt.NONE,
                    SizeOpt.NONE,
                    SizeAvail.MAX_CONTENT,
                    SizingMode.ContentSize,
                    FALSE_LINE
                );
            }
        }

        // 8.5. Flex Container Baselines: calculate the flex container's first baseline
        // See https://www.w3.org/TR/css-flexbox-1/#flex-baselines
        // The baselines are generated from the startmost flex line, where "startmost" refers to the
        // line's visual position: for wrap-reverse containers the cross axis is flipped, so the
        // startmost line is the last line in flex-line order rather than the first.
        var firstVerticalBaseline:OptionalFloat = OptionalFloat.NONE;
        if (flexLines.length > 0) {
            final firstLine = constants.isWrapReverse ? flexLines[flexLines.length - 1] : flexLines[0];
            final items = firstLine.items;
            if (items.length > 0) {
                if (constants.isColumn) {
                    // For column containers the baseline is generated from the startmost item in the line,
                    // which for reverse-direction containers is the last item in flex order.
                    final item = constants.dir.isReverse() ? items[items.length - 1] : items[0];
                    firstVerticalBaseline = OptionalFloat.some(item.baseline);
                }
                else {
                    var found:FlexItem = null;
                    for (item in items) {
                        if (item.participatesInBaselineAlignment(constants.dir)) {
                            found = item;
                            break;
                        }
                    }
                    if (found == null)
                        found = items[0];
                    firstVerticalBaseline = OptionalFloat.some(found.baseline);
                }
            }
        }

        final output = LayoutOutput.fromSizesAndBaselines(
            constants.containerSize.toSize(),
            inflowOverflowRect,
            Baselines.fromFirst(firstVerticalBaseline)
        );
        output.oofCandidates = candidates;
        output.oofPositioningArea = if (candidates.isEmpty()) {
            OofPositioningArea.UNUSED;
        }
        else {
            final isRtl = constants.layoutDirection.isRtl();
            final absolutePositionInset = constants.border.add(new Rect(
                isRtl ? constants.scrollbarGutter.x : 0.0,
                isRtl ? 0.0 : constants.scrollbarGutter.x,
                0.0,
                constants.scrollbarGutter.y
            ));
            final absolutePositionArea = constants.containerSize.toSize().sub(absolutePositionInset.sumAxes());
            final absolutePositionOffset = new Point(absolutePositionInset.left, absolutePositionInset.top);
            new OofPositioningArea(absolutePositionArea, absolutePositionOffset);
        };
        return output;
    }

    /**
     * Resolve the `normal` alignment keyword, which behaves as `stretch` for flex items.
     * https://www.w3.org/TR/css-align-3/#align-flex
     */
    static inline function resolveNormalAlignment(alignment:AlignItems):AlignItems {
        return alignment.keyword == AlignItemsKeyword.Normal ? AlignItems.STRETCH : alignment;
    }

    /** Compute constants that can be reused during the flexbox algorithm. */
    static function computeConstants(
        c:AlgoConstants,
        style:Style,
        knownDimensions:SizeOpt,
        knownDimensionsAreDefinite:SizeOf<Bool>,
        parentSize:SizeOpt,
        availableSpace:SizeAvail
    ):AlgoConstants {
        final dir = style.flexDirection;
        final isRow = dir.isRow();
        final isColumn = dir.isColumn();
        final flexWrap = style.flexWrap;
        final isWrap = flexWrap.isMultiLine();
        final isWrapReverse = flexWrap.isReverse();
        final isBalance = flexWrap.isBalance();
        final lineCount:Null<Int> = isWrap ? Sys.imax(style.flexLineCount, 1) : null;

        // The values stored in the constants are shared when zero or absent (the common case);
        // intermediate values are inline and allocate nothing
        final aspectRatio = style.aspectRatio;
        final padding = style.padding.resolveOrZero(parentSize.width);
        final border = style.border.resolveOrZero(parentSize.width);
        final paddingBorderSum = padding.sumAxes().add(border.sumAxes());
        final contentBox = style.boxSizing == BoxSizing.ContentBox;
        final boxSizingAdjustment = new Size(contentBox ? paddingBorderSum.width : 0.0, contentBox ? paddingBorderSum.height : 0.0);

        // `normal` behaves as `stretch` for flex items. This is resolved once here so that
        // items with an `align_self` of `None`, which defer to this value, are also resolved.
        final alignItems = resolveNormalAlignment(style.alignItems);
        // `normal` behaves as `stretch` for flex containers. In the main axis `stretch` behaves as
        // `flex-start`, so a `normal` justify-content is resolved straight to `flex-start`.
        // https://www.w3.org/TR/css-align-3/#distribution-flex
        final alignContent = style.alignContent.keyword == AlignContentKeyword.Normal ? AlignContent.STRETCH : style.alignContent;
        final justifyContent = style.justifyContent.keyword == AlignContentKeyword.Normal ? AlignContent.FLEX_START : style.justifyContent;
        final layoutDirection = style.direction;

        // Scrollbar gutters are reserved when the `overflow` property is set to `Overflow::Scroll`.
        // However, the axis are switched (transposed) because a node that scrolls vertically needs
        // *horizontal* space to be reserved for a scrollbar
        final overflow = style.overflow;
        final gutterX = overflow.y == Overflow.Scroll ? style.scrollbarWidth : 0.0;
        final gutterY = overflow.x == Overflow.Scroll ? style.scrollbarWidth : 0.0;
        final scrollbarGutter = (Size.isPositiveZero(gutterX) && Size.isPositiveZero(gutterY)) ? Point.ZERO : new Point(gutterX, gutterY);
        final isScrollContainer = overflow.x.isScrollContainer() || overflow.y.isScrollContainer();
        // `padding + border`, with the gutter added to the bottom and to the end side
        final paddingBorder = padding.add(border);
        final isLtr = layoutDirection == Direction.Ltr;
        final insetLeft = isLtr ? paddingBorder.left : paddingBorder.left + gutterX;
        final insetRight = isLtr ? paddingBorder.right + gutterX : paddingBorder.right;
        final insetTop = paddingBorder.top;
        final insetBottom = paddingBorder.bottom + gutterY;
        final contentBoxInset = c.sharedContentBoxInset(insetLeft, insetRight, insetTop, insetBottom);

        final nodeOuterSize = knownDimensions;
        final innerSize = nodeOuterSize.maybeSubSize(new Size(insetLeft + insetRight, insetTop + insetBottom));
        final nodeInnerSize = c.sharedNodeInnerSize(innerSize.width, innerSize.height);
        final knownMainSizeIsDefinite = knownDimensionsAreDefinite.main(dir);
        final hasDefiniteMainSize = knownMainSizeIsDefinite && knownDimensions.main(dir).isSome();
        final hasDefiniteCrossSize = knownDimensionsAreDefinite.cross(dir) && knownDimensions.cross(dir).isSome();
        final crossAxisAvailableSpaceIsDefinite = hasDefiniteCrossSize || availableSpace.cross(dir).isDefinite();
        final gapContext = new SizeOpt(
            nodeInnerSize.width.isSome() ? nodeInnerSize.width : OptionalFloat.some(0.0),
            nodeInnerSize.height.isSome() ? nodeInnerSize.height : OptionalFloat.some(0.0)
        );
        final resolvedGap = style.gap.resolveOrZero(gapContext);
        final gap = c.sharedGap(resolvedGap.width, resolvedGap.height);
        final minSize = style.minSize.maybeResolve(parentSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);
        final maxSize = style.maxSize.maybeResolve(parentSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);

        // Every field is set (the constants object is reused)
        c.dir = dir;
        c.layoutDirection = layoutDirection;
        c.isRow = isRow;
        c.isColumn = isColumn;
        c.isWrap = isWrap;
        c.isWrapReverse = isWrapReverse;
        c.isBalance = isBalance;
        c.lineCount = lineCount;
        c.minSize = c.sharedMinSize(minSize.width, minSize.height);
        c.maxSize = c.sharedMaxSize(maxSize.width, maxSize.height);
        c.border = c.sharedBorder(border.left, border.right, border.top, border.bottom);
        c.gap = gap;
        c.contentBoxInset = contentBoxInset;
        c.scrollbarGutter = scrollbarGutter;
        c.isScrollContainer = isScrollContainer;
        c.alignItems = alignItems;
        c.alignContent = alignContent;
        c.justifyContent = justifyContent;
        c.nodeOuterSize = nodeOuterSize;
        c.nodeInnerSize = nodeInnerSize;
        c.knownMainSizeIsDefinite = knownMainSizeIsDefinite;
        c.hasDefiniteMainSize = hasDefiniteMainSize;
        c.hasDefiniteCrossSize = hasDefiniteCrossSize;
        c.crossAxisAvailableSpaceIsDefinite = crossAxisAvailableSpaceIsDefinite;
        c.containerSize.clear();
        c.innerContainerSize.clear();
        return c;
    }

    /**
     * Resolve a `position: relative` item's inset to a single offset in the container's flex axes,
     * accounting for flex direction and writing direction.
     */
    static inline function resolveRelativeInset(inset:RectOpt, constants:AlgoConstants):Size {
        final direction = constants.dir;
        final isRtlRow = direction.isRow() && constants.layoutDirection.isRtl();
        final isRtlColumn = direction.isColumn() && constants.layoutDirection.isRtl();
        final mainStart = inset.mainStart(direction);
        final mainEnd = inset.mainEnd(direction);
        final crossStart = inset.crossStart(direction);
        final crossEnd = inset.crossEnd(direction);
        final main:Float = if (isRtlRow) {
            mainEnd.isSome() ? mainEnd.unwrap() : (mainStart.isSome() ? -mainStart.unwrap() : 0.0);
        }
        else {
            mainStart.isSome() ? mainStart.unwrap() : (mainEnd.isSome() ? -mainEnd.unwrap() : 0.0);
        };
        final cross:Float = if (isRtlColumn) {
            crossEnd.isSome() ? -crossEnd.unwrap() : (crossStart.isSome() ? crossStart.unwrap() : 0.0);
        }
        else {
            crossStart.isSome() ? crossStart.unwrap() : (crossEnd.isSome() ? -crossEnd.unwrap() : 0.0);
        };
        // `Size.ZERO.withMain(direction, main).withCross(direction, cross)`, shared when zero
        final isRow = direction.isRow();
        return Size.shared(isRow ? main : cross, isRow ? cross : main);
    }

    /**
     * Generate anonymous flex items.
     *
     * # [9.1. Initial Setup](https://www.w3.org/TR/css-flexbox-1/#box-manip)
     *
     * - [**Generate anonymous flex items**](https://www.w3.org/TR/css-flexbox-1/#algo-anon-box) as described in [§4 Flex Items](https://www.w3.org/TR/css-flexbox-1/#flex-items).
     */
    static function generateAnonymousFlexItems(tree:LayoutFlexboxContainer, node:NodeId, constants:AlgoConstants, items:Array<FlexItem>):Array<FlexItem> {
        // Percentage sizes of items resolve against the container's inner size, but only if that size
        // is definite. A known main size which is derived from the container's own content is treated
        // as indefinite here.
        final percentResolutionSize = constants.knownMainSizeIsDefinite
            ? constants.nodeInnerSize
            : constants.nodeInnerSize.withMain(constants.dir, OptionalFloat.NONE);

        items.resize(0);
        final count = tree.childCount(node);
        for (index in 0...count) {
            final child = tree.getChildId(node, index);
            final childStyle = tree.getFlexboxChildStyle(child);
            if (childStyle.position.isOutOfFlow())
                continue;
            if (childStyle.boxGenerationMode() == BoxGenerationMode.None)
                continue;

            // The geometry stored in the item is shared when it is zero or absent (the common case);
            // intermediate values are inline and allocate nothing
            final aspectRatio = childStyle.aspectRatio;
            final innerWidth = constants.nodeInnerSize.width;
            final p = childStyle.padding.resolveOrZero(innerWidth);
            final b = childStyle.border.resolveOrZero(innerWidth);
            final pbSum = p.add(b).sumAxes();
            final contentBox = childStyle.boxSizing == BoxSizing.ContentBox;
            final boxSizingAdjustment = new Size(contentBox ? pbSum.width : 0.0, contentBox ? pbSum.height : 0.0);

            final relativeInset = if (childStyle.position == Position.Relative) {
                final inset = childStyle.inset.maybeResolveBySize(constants.nodeInnerSize);
                resolveRelativeInset(inset, constants);
            }
            else {
                Size.ZERO;
            };

            final m = childStyle.margin;
            final size = childStyle.size.maybeResolve(percentResolutionSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);
            final minSize = childStyle.minSize.maybeResolve(percentResolutionSize).maybeAddSize(boxSizingAdjustment);
            final maxSize = childStyle.maxSize.maybeResolve(percentResolutionSize).maybeAddSize(boxSizingAdjustment);
            final margin = m.resolveOrZero(innerWidth);
            final leftAuto = m.left.isAuto();
            final rightAuto = m.right.isAuto();
            final topAuto = m.top.isAuto();
            final bottomAuto = m.bottom.isAuto();
            final poolIndex = itemPoolTop++;
            if (poolIndex == itemPool.length)
                itemPool.push(new FlexItem());
            // The item's own sizes, set in place (nothing allocated per item and layout)
            final pooled = itemPool[poolIndex];
            final item = pooled.reset(
                child,
                index,
                pooled.ownedSize(0, size.width, size.height),
                childStyle.size,
                pooled.ownedSize(1, minSize.width, minSize.height),
                pooled.ownedSize(2, maxSize.width, maxSize.height),
                aspectRatio,
                relativeInset,
                Rect.shared(margin.left, margin.right, margin.top, margin.bottom),
                (leftAuto || rightAuto || topAuto || bottomAuto) ? new RectOf<Bool>(leftAuto, rightAuto, topAuto, bottomAuto) : NO_AUTO_MARGINS,
                Rect.shared(p.left, p.right, p.top, p.bottom),
                Rect.shared(b.left, b.right, b.top, b.bottom),
                resolveNormalAlignment(childStyle.alignSelf != null ? (childStyle.alignSelf : AlignItems) : constants.alignItems)
                    .resolveSelfRelative(childStyle.direction, constants.layoutDirection, constants.isColumn),
                childStyle.overflow,
                childStyle.contain,
                childStyle.scrollbarWidth,
                childStyle.flexGrow,
                childStyle.flexShrink
            );
            items.push(item);
        }
        return items;
    }

    /**
     * Determine the available main and cross space for the flex items.
     *
     * # [9.2. Line Length Determination](https://www.w3.org/TR/css-flexbox-1/#line-sizing)
     *
     * - [**Determine the available main and cross space for the flex items**](https://www.w3.org/TR/css-flexbox-1/#algo-available).
     *
     * For each dimension, if that dimension of the flex container's content box is a definite size, use that;
     * if that dimension of the flex container is being sized under a min or max-content constraint, the available space in that dimension is that constraint;
     * otherwise, subtract the flex container's margin, border, and padding from the space available to the flex container in that dimension and use that value.
     * **This might result in an infinite value**.
     *
     * Note: the flex container's margins have already been subtracted from `outerAvailableSpace` by its parent.
     */
    static function determineAvailableSpace(
        knownDimensions:SizeOpt,
        outerAvailableSpace:SizeAvail,
        constants:AlgoConstants
    ):SizeAvail {
        // Note: min/max/preferred size styles have already been applied to knownDimensions in the `compute` function above
        final kw = knownDimensions.width;
        final width = if (kw.isSome()) {
            Definite(Sys.f32Max(kw.unwrap() - constants.contentBoxInset.horizontalAxisSum(), 0.0));
        }
        else {
            outerAvailableSpace.width.maybeSub(OptionalFloat.some(constants.contentBoxInset.horizontalAxisSum())).maybeMax(OptionalFloat.some(0.0));
        };

        final kh = knownDimensions.height;
        final height = if (kh.isSome()) {
            Definite(Sys.f32Max(kh.unwrap() - constants.contentBoxInset.verticalAxisSum(), 0.0));
        }
        else {
            outerAvailableSpace.height.maybeSub(OptionalFloat.some(constants.contentBoxInset.verticalAxisSum())).maybeMax(OptionalFloat.some(0.0));
        };

        // Owned by the constants (no allocation per container)
        return constants.availableSpaceOf(width, height);
    }

    /**
     * Determine the flex base size and hypothetical main size of each item.
     *
     * # [9.2. Line Length Determination](https://www.w3.org/TR/css-flexbox-1/#line-sizing)
     *
     * - [**Determine the flex base size and hypothetical main size of each item:**](https://www.w3.org/TR/css-flexbox-1/#algo-main-item)
     *
     *     - A. If the item has a definite used flex basis, that's the flex base size.
     *
     *     - B. If the flex item has an intrinsic aspect ratio, a used flex basis of content, and a definite cross size,
     *       then the flex base size is calculated from its inner cross size and the flex item's intrinsic aspect ratio.
     *
     *     - C. If the used flex basis is content or depends on its available space, and the flex container is being sized under a min-content
     *       or max-content constraint (e.g. when performing automatic table layout [CSS21]), size the item under that constraint.
     *       The flex base size is the item's resulting main size.
     *
     *     - E. Otherwise, size the item into the available space using its used flex basis in place of its main size, treating a value of content as max-content.
     *       If a cross size is needed to determine the main size (e.g. when the flex item's main size is in its block axis) and the flex item's cross size is auto and not definite,
     *       in this calculation use fit-content as the flex item's cross size. The flex base size is the item's resulting main size.
     *
     *   When determining the flex base size, the item's min and max main sizes are ignored (no clamping occurs).
     *   Furthermore, the sizing calculations that floor the content box size at zero when applying box-sizing are also ignored.
     *   (For example, an item with a specified size of zero, positive padding, and box-sizing: border-box will have an outer flex base size of zero, and hence a negative inner flex base size.)
     */
    static function determineFlexBaseSize(
        tree:LayoutFlexboxContainer,
        constants:AlgoConstants,
        availableSpace:SizeAvail,
        flexItems:Array<FlexItem>
    ):Void {
        final dir = constants.dir;

        // Parent size for child sizing (the same for every child): `SizeOpt.fromCross(dir, crossAxisParentSize)`
        // as two values (the child calls take values, no size object)
        final crossAxisParentSize = constants.nodeInnerSize.cross(dir);
        final childParentWidth = dir.isRow() ? OptionalFloat.NONE : crossAxisParentSize;
        final childParentHeight = dir.isRow() ? crossAxisParentSize : OptionalFloat.NONE;

        for (child in flexItems) {
            final childStyle = tree.getFlexboxChildStyle(child.node);

            // Available space for child sizing (excluding the child's margins)
            // Min/max sizes transferred through the aspect ratio are taken into account here
            // https://github.com/w3c/csswg-drafts/issues/10997
            final transferredMinSize = child.minSize.maybeApplyAspectRatio(child.aspectRatio);
            final transferredMaxSize = child.maxSize.maybeApplyAspectRatio(child.aspectRatio);
            final childMinCross = transferredMinSize.cross(dir);
            final childMaxCross = transferredMaxSize.cross(dir);

            // Clamp available space by min- and max- size
            final crossAxisAvailableSpace:AvailableSpace = switch availableSpace.cross(dir) {
                case MinContent:
                    childMinCross.isSome() ? Definite(childMinCross.unwrap()) : MinContent;
                case MaxContent:
                    childMaxCross.isSome() ? Definite(childMaxCross.unwrap()) : MaxContent;
                case definite:
                    final val = definite.definiteValue();
                    Definite(
                        Sys.f32Max(constants.dividedCrossSpace(crossAxisParentSize.unwrapOr(val)) - child.margin.crossAxisSum(dir), 0.0)
                            .maybeClampF(childMinCross, childMaxCross)
                    );
            }

            // Known dimensions for child sizing: the main size is unknown, and the definite cross size is
            // clamped by the cross min/max sizes so that sizes transferred through an intrinsic aspect ratio
            // (e.g. for replaced elements) are based on the used cross size.
            // (Computed as one value, then one object: `child.size.withMain(dir, None).withCross(...)`.)
            var childCrossSizeIsDefinite = child.size.cross(dir).isSome();
            var childKnownCross = child.size.cross(dir).maybeClamp(transferredMinSize.cross(dir), transferredMaxSize.cross(dir));
            if (child.alignSelf == AlignItems.STRETCH
                && !child.marginIsAuto.crossStart(constants.dir)
                && !child.marginIsAuto.crossEnd(constants.dir)
                && childKnownCross.isNone()) {
                childKnownCross = crossAxisAvailableSpace.intoOption();
                // The cross size of a stretched item is definite if the container has a definite
                // cross size (https://www.w3.org/TR/css-flexbox-1/#definite-sizes)
                childCrossSizeIsDefinite = !constants.isWrap && constants.hasDefiniteCrossSize && crossAxisParentSize.isSome();
            }
            // `SizeOpt.fromCross(dir, childKnownCross)` as two values (both absent when the cross size is)
            final childKnownWidth = dir.isRow() ? OptionalFloat.NONE : childKnownCross;
            final childKnownHeight = dir.isRow() ? childKnownCross : OptionalFloat.NONE;

            // Percentage padding and border resolve against the container's inline size (its width),
            // whichever axis is the main axis
            final containerWidth = constants.nodeInnerSize.width;
            final boxSizingAdjustment:Float = if (childStyle.boxSizing == BoxSizing.ContentBox) {
                final padding = childStyle.padding.resolveOrZero(containerWidth);
                final border = childStyle.border.resolveOrZero(containerWidth);
                padding.add(border).sumAxes().main(dir);
            }
            else {
                0.0;
            };
            // Percentage flex basis values resolve against the container's inner main size, but only
            // if that size is definite. A known main size which is derived from the container's own
            // content is treated as indefinite here.
            final percentResolutionMainSize:OptionalFloat = constants.knownMainSizeIsDefinite ? constants.nodeInnerSize.main(dir) : OptionalFloat.NONE;
            final flexBasisStyle = childStyle.flexBasis;
            final flexBasis = flexBasisStyle.maybeResolve(percentResolutionMainSize).maybeAdd(OptionalFloat.some(boxSizingAdjustment));

            child.flexBasis = computeItemFlexBasis(
                tree,
                child,
                constants,
                availableSpace,
                flexBasisStyle,
                flexBasis,
                percentResolutionMainSize,
                childCrossSizeIsDefinite,
                childKnownWidth,
                childKnownHeight,
                childParentWidth,
                childParentHeight,
                crossAxisAvailableSpace
            );

            // Floor flex-basis by the padding_border_sum (floors inner_flex_basis at zero)
            // This seems to be in violation of the spec which explicitly states that the content box should not be floored at zero
            // (like it usually is) when calculating the flex-basis. But including this matches both Chrome and Firefox's behaviour.
            //
            // TODO: resolve spec violation
            // Spec: https://www.w3.org/TR/css-flexbox-1/#intrinsic-item-contributions
            // Spec: https://www.w3.org/TR/css-flexbox-1/#change-2016-max-contribution
            final paddingBorderSum = child.padding.mainAxisSum(constants.dir) + child.border.mainAxisSum(constants.dir);
            child.flexBasis = Sys.f32Max(child.flexBasis, paddingBorderSum);

            // The hypothetical main size is the item's flex base size clamped according to its
            // used min and max main sizes (and flooring the content box size at zero).

            child.innerFlexBasis = child.flexBasis - child.padding.mainAxisSum(constants.dir) - child.border.mainAxisSum(constants.dir);

            final paddingBorderAxesSums = child.padding.add(child.border).sumAxes();

            // Note that it is important that the `parent_size` parameter in the main axis is not set for this
            // function call as it used for resolving percentages, and percentage size in an axis should not contribute
            // to a min-content contribution in that same axis. However the `parent_size` and `available_space` *should*
            // be set to their usual values in the cross axis so that wrapping content can wrap correctly.
            //
            // See https://drafts.csswg.org/css-sizing-3/#min-percentage-contribution
            final overflowMin:OptionalFloat = dir.isRow() ? child.overflow.x.maybeIntoAutomaticMinSize() : child.overflow.y.maybeIntoAutomaticMinSize();
            final styleMinMainSize = child.minSize.main(dir).or(overflowMin);

            child.resolvedMinimumMainSize = if (styleMinMainSize.isSome()) {
                styleMinMainSize.unwrap();
            }
            else {
                final minContentMainSize = {
                    final childAvailableSpace = SizeAvail.MIN_CONTENT.withCross(dir, crossAxisAvailableSpace);

                    tree.measureChildSizeParts(
                        child.node,
                        childKnownWidth,
                        childKnownHeight,
                        childParentWidth,
                        childParentHeight,
                        childAvailableSpace.width,
                        childAvailableSpace.height,
                        SizingMode.ContentSize,
                        dir.mainAxis(),
                        FALSE_LINE
                    );
                };

                // 4.5. Automatic Minimum Size of Flex Items
                // https://www.w3.org/TR/css-flexbox-1/#min-size-auto
                final clampedMinContentSize = minContentMainSize.maybeMinF(child.size.main(dir)).maybeMinF(transferredMaxSize.main(dir));
                Sys.f32Max(clampedMinContentSize, paddingBorderAxesSums.main(dir));
            };

            // Sizes transferred through the aspect ratio clamp the hypothetical main size,
            // but do not participate in resolving flexible lengths or clamping the final size.
            // https://github.com/w3c/csswg-drafts/issues/10997
            final hypotheticalInnerMinMain = Sys.f32Max(
                child.resolvedMinimumMainSize.maybeMaxF(transferredMinSize.main(constants.dir)),
                paddingBorderAxesSums.main(constants.dir)
            );
            final hypotheticalInnerSize = child.flexBasis.maybeClampF(OptionalFloat.some(hypotheticalInnerMinMain), transferredMaxSize.main(constants.dir));
            final hypotheticalOuterSize = hypotheticalInnerSize + child.margin.mainAxisSum(constants.dir);

            child.hypotheticalInnerSize.setMain(constants.dir, hypotheticalInnerSize);
            child.hypotheticalOuterSize.setMain(constants.dir, hypotheticalOuterSize);
        }
    }

    /** The `'flex_basis` labeled block of `determine_flex_base_size` */
    static function computeItemFlexBasis(
        tree:LayoutFlexboxContainer,
        child:FlexItem,
        constants:AlgoConstants,
        availableSpace:SizeAvail,
        flexBasisStyle:taffy.style.Dimension,
        flexBasis:OptionalFloat,
        percentResolutionMainSize:OptionalFloat,
        childCrossSizeIsDefinite:Bool,
        childKnownWidth:OptionalFloat,
        childKnownHeight:OptionalFloat,
        childParentWidth:OptionalFloat,
        childParentHeight:OptionalFloat,
        crossAxisAvailableSpace:AvailableSpace
    ):Float {
        final dir = constants.dir;

        // A. If the item has a definite used flex basis, that's the flex base size.

        // B. If the flex item has an intrinsic aspect ratio,
        //    a used flex basis of content, and a definite cross size,
        //    then the flex base size is calculated from its inner
        //    cross size and the flex item's intrinsic aspect ratio.

        final mainSize = child.size.main(dir);
        final mainStretchSize = percentResolutionMainSize.maybeSub(OptionalFloat.some(child.margin.mainAxisSum(dir))).maybeMax(OptionalFloat.some(0.0));

        // A flex basis that is a sizing keyword (min-content, max-content, fit-content,
        // fit-content(...), stretch) is used in place of the main size property: `stretch`
        // resolves to an exact (definite) size while the other keywords determine the
        // available space constraint the item is measured under. A keyword that cannot be
        // resolved in the current context behaves as `content`.
        var hasKeywordMainAvailableSpace = false;
        var keywordMainAvailableSpace:AvailableSpace = MaxContent;
        if (flexBasisStyle.isContent()) {
            // A flex basis of `content` indicates an automatic size based on the item's
            // content: the item is measured (ignoring its main size property) under the
            // default constraint below
            hasKeywordMainAvailableSpace = false;
        }
        else if (flexBasisStyle.isSizingKeyword()) {
            final resolution = SizingKeyword.resolveSizingKeyword(flexBasisStyle, mainStretchSize, percentResolutionMainSize);
            if (resolution != null) {
                switch resolution {
                    case Exact(size):
                        child.flexBasisIsDefinite = true;
                        return size;
                    case Measure(available):
                        hasKeywordMainAvailableSpace = true;
                        keywordMainAvailableSpace = available;
                }
            }
        }
        else {
            final basis:OptionalFloat = flexBasis.isSome() ? flexBasis : (flexBasisStyle.isAuto() ? mainSize : OptionalFloat.NONE);
            if (basis.isSome()) {
                child.flexBasisIsDefinite = true;
                return basis.unwrap();
            }

            // A main size that is a sizing keyword either resolves to an exact size or
            // determines the available space constraint the item is measured under
            if (flexBasisStyle.isAuto()) {
                final resolution = SizingKeyword.resolveSizingKeyword(child.sizeStyle.main(dir), mainStretchSize, percentResolutionMainSize);
                if (resolution != null) {
                    switch resolution {
                        case Exact(size):
                            child.flexBasisIsDefinite = true;
                            return size;
                        case Measure(available):
                            hasKeywordMainAvailableSpace = true;
                            keywordMainAvailableSpace = available;
                    }
                }
            }
        }

        // C. If the used flex basis is content or depends on its available space,
        //    and the flex container is being sized under a min-content or max-content
        //    constraint (e.g. when performing automatic table layout [CSS21]),
        //    size the item under that constraint. The flex base size is the item's
        //    resulting main size.

        // This is covered by the implementation of E below, which passes the available_space constraint
        // through to the child size computation. It may need a separate implementation if/when D is implemented.

        // D. Otherwise, if the used flex basis is content or depends on its
        //    available space, the available main size is infinite, and the flex item's
        //    inline axis is parallel to the main axis, lay the item out using the rules
        //    for a box in an orthogonal flow [CSS3-WRITING-MODES]. The flex base size
        //    is the item's max-content main size.

        // TODO if/when vertical writing modes are supported

        // If the item has an aspect ratio and a definite cross size then the flex base size
        // is calculated by transferring that cross size through the aspect ratio (case B
        // above), and is therefore definite.
        if (childCrossSizeIsDefinite) {
            final ratio = child.aspectRatio;
            final cross = dir.isRow() ? childKnownHeight : childKnownWidth;
            if (ratio.isSome() && cross.isSome()) {
                child.flexBasisIsDefinite = true;
                return dir.isRow() ? cross.unwrap() * ratio.unwrap() : cross.unwrap() / ratio.unwrap();
            }
        }

        // E. Otherwise, size the item into the available space using its used flex basis
        //    in place of its main size, treating a value of content as max-content.
        //    If a cross size is needed to determine the main size (e.g. when the
        //    flex item's main size is in its block axis) and the flex item's cross size
        //    is auto and not definite, in this calculation use fit-content as the
        //    flex item's cross size. The flex base size is the item's resulting main size.

        final mainAvailable:AvailableSpace = if (hasKeywordMainAvailableSpace) {
            keywordMainAvailableSpace;
        }
        else {
            // Map AvailableSpace::Definite to AvailableSpace::MaxContent
            switch availableSpace.main(dir) {
                case MinContent: MinContent;
                case _: MaxContent;
            }
        };
        final childAvailableSpace = SizeAvail.MAX_CONTENT.withMain(dir, mainAvailable).withCross(dir, crossAxisAvailableSpace);

        return tree.measureChildSizeParts(
            child.node,
            childKnownWidth,
            childKnownHeight,
            childParentWidth,
            childParentHeight,
            childAvailableSpace.width,
            childAvailableSpace.height,
            SizingMode.ContentSize,
            dir.mainAxis(),
            FALSE_LINE
        );
    }

    /**
     * Collect flex items into flex lines.
     *
     * # [9.3. Main Size Determination](https://www.w3.org/TR/css-flexbox-1/#main-sizing)
     *
     * - [**Collect flex items into flex lines**](https://www.w3.org/TR/css-flexbox-1/#algo-line-break):
     *
     *     - If the flex container is single-line, collect all the flex items into a single flex line.
     *
     *     - Otherwise, starting from the first uncollected item, collect consecutive items one by one until the first time that the next collected item would not fit into the flex container's inner main size
     *       (or until a forced break is encountered, see [§10 Fragmenting Flex Layout](https://www.w3.org/TR/css-flexbox-1/#pagination)).
     *       If the very first uncollected item wouldn't fit, collect just it into the line.
     *
     *       For this step, the size of a flex item is its outer hypothetical main size. (**Note: This can be negative**.)
     *
     *       Repeat until all flex items have been collected into flex lines.
     *
     *       **Note that the "collect as many" line will collect zero-sized flex items onto the end of the previous line even if the last non-zero item exactly "filled up" the line**.
     */
    static function collectFlexLines(constants:AlgoConstants, availableSpace:SizeAvail, flexItems:Array<FlexItem>, scratch:FlexScratch):Array<FlexLine> {
        // Wrapping into multiple lines requires a definite main size. If the container's known main size
        // is derived from its own content (and is thus indefinite) then all items are collected into a
        // single flex line, matching how the container was sized under a min/max-content constraint.
        if (!constants.isWrap || !constants.knownMainSizeIsDefinite) {
            return scratch.singleLineOf(flexItems);
        }

        final mainAxisAvailableSpace = wrapMainAxisAvailableSpace(constants, availableSpace);

        switch mainAxisAvailableSpace {
            // If we're sizing under a max-content constraint then the flex items will never wrap
            // (at least for now - future extensions to the CSS spec may add provisions for forced wrap points)
            case MaxContent:
                return scratch.singleLineOf(flexItems);

            // If flex-wrap is Wrap and we're sizing under a min-content constraint, then we take every possible wrapping opportunity
            // and place each item in it's own line
            case MinContent:
                return oneItemPerLine(flexItems);

            case definite:
                final mainAxisAvailable = definite.definiteValue();
                final lines:Array<FlexLine> = [];
                final mainAxisGap = constants.gap.main(constants.dir);
                final total = flexItems.length;
                var start = 0;

                while (start < total) {
                    // Find index of the first item in the next line
                    // (or the last item if all remaining items are in the current line)
                    var lineLength = 0.0;
                    var index = total - start;
                    for (idx in 0...total - start) {
                        final child = flexItems[start + idx];
                        // Gaps only occur between items (not before the first one or after the last one)
                        // So first item in the line does not contribute a gap to the line length
                        final gapContribution = idx == 0 ? 0.0 : mainAxisGap;
                        lineLength += child.hypotheticalOuterSize.main(constants.dir) + gapContribution;
                        if (lineLength > mainAxisAvailable && idx != 0) {
                            index = idx;
                            break;
                        }
                    }

                    lines.push(new FlexLine(flexItems.slice(start, start + index)));
                    start += index;
                }
                return lines;
        }
    }

    /** The main axis available space that items wrap against (shared by greedy and balanced line collection) */
    static function wrapMainAxisAvailableSpace(constants:AlgoConstants, availableSpace:SizeAvail):AvailableSpace {
        final maxMain = constants.maxSize.main(constants.dir);
        if (maxMain.isSome()) {
            final maxSize:Float = maxMain.unwrap();
            var available = availableSpace.main(constants.dir).unwrapOr(maxSize);
            // If the container's main size is not definite then it is at most the max main size,
            // so the max size (and not the available space) is the limit that items wrap against.
            if (!constants.hasDefiniteMainSize)
                available = Sys.f32Min(available, maxSize);
            return Definite(available.maybeMaxF(constants.minSize.main(constants.dir)));
        }
        // A column container's automatic main size is content-based, so definite available space
        // handed down by an ancestor does not constrain where its lines wrap. Automatic widths
        // resolve against available space, so rows do wrap against it.
        if (!constants.dir.isRow() && !constants.hasDefiniteMainSize && availableSpace.main(constants.dir).isDefinite()) {
            return MaxContent;
        }
        return availableSpace.main(constants.dir);
    }

    /** Put each item in a line of its own */
    static function oneItemPerLine(flexItems:Array<FlexItem>):Array<FlexLine> {
        final lines:Array<FlexLine> = [];
        for (item in flexItems)
            lines.push(new FlexLine([item]));
        return lines;
    }

    /**
     * Collect flex items into balanced flex lines (`flex-wrap: balance`), such that the largest
     * line is as small as possible.
     *
     * See https://drafts.csswg.org/css-flexbox-2/#balance-values
     */
    static function collectBalancedFlexLines(constants:AlgoConstants, availableSpace:SizeAvail, flexItems:Array<FlexItem>):Array<FlexLine> {
        if (flexItems.length == 0) {
            return [];
        }

        // If the container's known main size is derived from its own content (and is thus indefinite)
        // then items are balanced without a size limit, matching how the container was sized under a
        // min/max-content constraint.
        final mainAxisAvailableSpace = constants.knownMainSizeIsDefinite ? wrapMainAxisAvailableSpace(constants, availableSpace) : MaxContent;

        // If we're sizing under a min-content constraint then we take every possible wrapping
        // opportunity and place each item in its own line, the same as greedy wrapping (the
        // min-content main size of a multi-line container is the size of its largest item)
        if (mainAxisAvailableSpace == MinContent) {
            return oneItemPerLine(flexItems);
        }

        final lineBreakSize = mainAxisAvailableSpace.unwrapOr(Math.POSITIVE_INFINITY);
        final minLineCount:Int = constants.lineCount != null ? (constants.lineCount : Int) : 1;
        final sizes:Array<Float> = [];
        for (item in flexItems)
            sizes.push(item.hypotheticalOuterSize.main(constants.dir));
        final itemCounts = FlexBalance.balancedLineItemCounts(sizes, lineBreakSize, constants.gap.main(constants.dir), minLineCount);

        final lines:Array<FlexLine> = [];
        var start = 0;
        for (count in itemCounts) {
            lines.push(new FlexLine(flexItems.slice(start, start + count)));
            start += count;
        }
        return lines;
    }

    /**
     * Compute whether each of an item's known dimensions should be treated as definite when performing
     * layout on the item. An item's post-flexing main size is only treated as definite if the container
     * has a definite main size or the item's used flex basis is definite.
     * See https://www.w3.org/TR/css-flexbox-1/#definite-sizes
     */
    static function itemKnownDimensionDefiniteness(constants:AlgoConstants, item:FlexItem):SizeOf<Bool> {
        final dir = constants.dir;
        final mainIsDefinite = constants.hasDefiniteMainSize || item.flexBasisIsDefinite;

        // An item's cross size is definite if it is stretched (it stretches to the flex line, whose
        // size is known by the time the item's final layout is performed), or if its cross size style
        // resolved to a definite size. Additionally, a non-stretched item's cross *width* is fit-content
        // sized, and a size resolved by fit-content sizing against definite available space is itself
        // definite (https://www.w3.org/TR/css-sizing-3/#definite). The same does not apply to cross
        // heights, which are content-based and therefore indefinite when not stretched.

        final hasCrossAutoMargins = item.marginIsAuto.crossStart(dir) || item.marginIsAuto.crossEnd(dir);
        final crossSize = item.sizeStyle.cross(dir);
        final isStretched = !hasCrossAutoMargins && (crossSize.isStretch() || (item.alignSelf == AlignItems.STRETCH && crossSize.isAuto()));
        final crossIsDefinite = isStretched || item.size.cross(dir).isSome() || (!dir.isRow() && constants.crossAxisAvailableSpaceIsDefinite);

        return dir.isRow() ? boolSize(mainIsDefinite, crossIsDefinite) : boolSize(crossIsDefinite, mainIsDefinite);
    }

    /** The four values of a `SizeOf<Bool>` (shared, never mutated) */
    static final BOOL_SIZE_FF:SizeOf<Bool> = new SizeOf<Bool>(false, false);
    static final BOOL_SIZE_FT:SizeOf<Bool> = new SizeOf<Bool>(false, true);
    static final BOOL_SIZE_TF:SizeOf<Bool> = new SizeOf<Bool>(true, false);
    static final BOOL_SIZE_TT:SizeOf<Bool> = new SizeOf<Bool>(true, true);

    /** `new SizeOf<Bool>(width, height)`, shared */
    static inline function boolSize(width:Bool, height:Bool):SizeOf<Bool> {
        return width ? (height ? BOOL_SIZE_TT : BOOL_SIZE_TF) : (height ? BOOL_SIZE_FT : BOOL_SIZE_FF);
    }

    /** The main length an item contributes to the line it is in, for the purpose of sizing the container */
    static inline function itemMainLength(child:FlexItem, dir:FlexDirection):Float {
        final paddingBorderSum = child.padding.add(child.border).mainAxisSum(dir);
        return Sys.f32Max(child.flexBasis.maybeMaxF(child.minSize.main(dir)) + child.margin.mainAxisSum(dir), paddingBorderSum);
    }

    /** The longest line length (sum of item main lengths plus gaps), or 0 if there are no lines */
    static function longestLineLength(lines:Array<FlexLine>, constants:AlgoConstants):Float {
        final mainAxisGap = constants.gap.main(constants.dir);
        var longest = 0.0;
        var first = true;
        for (line in lines) {
            final lineMainAxisGap = sumAxisGaps(mainAxisGap, line.items.length);
            var totalTargetSize = 0.0;
            for (child in line.items)
                totalTargetSize += itemMainLength(child, constants.dir);
            final length = totalTargetSize + lineMainAxisGap;
            if (first || length > longest) {
                longest = length;
                first = false;
            }
        }
        return longest;
    }

    /** Determine the container's main size (if not already known) */
    static function determineContainerMainSize(
        tree:LayoutFlexboxContainer,
        availableSpace:SizeAvail,
        lines:Array<FlexLine>,
        constants:AlgoConstants
    ):Void {
        final mainContentBoxInset = constants.contentBoxInset.mainAxisSum(constants.dir);

        final knownOuter = constants.nodeOuterSize.main(constants.dir);
        var outerMainSize:Float = knownOuter.isSome() ? knownOuter.unwrap() : computeOuterMainSize(tree, availableSpace, lines, constants, mainContentBoxInset);

        outerMainSize = Sys.f32Max(
            outerMainSize.maybeClampF(constants.minSize.main(constants.dir), constants.maxSize.main(constants.dir)),
            mainContentBoxInset - constants.scrollbarGutter.main(constants.dir)
        );

        final innerMainSize = Sys.f32Max(outerMainSize - mainContentBoxInset, 0.0);
        constants.containerSize.setMain(constants.dir, outerMainSize);
        constants.innerContainerSize.setMain(constants.dir, innerMainSize);
        constants.setNodeInnerMain(OptionalFloat.some(innerMainSize));
    }

    /** The `unwrap_or_else` closure of `determine_container_main_size` */
    static function computeOuterMainSize(
        tree:LayoutFlexboxContainer,
        availableSpace:SizeAvail,
        lines:Array<FlexLine>,
        constants:AlgoConstants,
        mainContentBoxInset:Float
    ):Float {
        final dir = constants.dir;
        switch availableSpace.main(dir) {
            case definite if (definite.isDefinite()):
                final mainAxisAvailableSpace = definite.definiteValue();
                final mainAxisGap = constants.gap.main(constants.dir);
                final longest = longestLineLength(lines, constants);
                final size = longest + mainContentBoxInset;

                // A balanced container can produce multiple lines that all fit within the
                // available space (via `flex-line-count`), in which case fit-content sizing
                // uses its max-content size: the longest line when items are balanced across
                // the minimum line count without a size limit.
                if (constants.isBalance) {
                    final minLineCount:Int = constants.lineCount != null ? (constants.lineCount : Int) : 1;
                    final itemLengths:Array<Float> = [];
                    for (line in lines) {
                        for (child in line.items)
                            itemLengths.push(itemMainLength(child, constants.dir));
                    }
                    if (itemLengths.length == 0) {
                        return size;
                    }
                    final itemCounts = FlexBalance.balancedLineItemCounts(itemLengths, Math.POSITIVE_INFINITY, mainAxisGap, Sys.imax(minLineCount, 1));
                    var widestLineLength = 0.0;
                    var index = 0;
                    for (count in itemCounts) {
                        var lineLength = 0.0;
                        for (i in index...index + count)
                            lineLength += itemLengths[i];
                        lineLength += sumAxisGaps(mainAxisGap, count);
                        widestLineLength = Sys.f32Max(widestLineLength, lineLength);
                        index += count;
                    }
                    final maxContentSize = widestLineLength + mainContentBoxInset;
                    return Sys.f32Max(size, Sys.f32Min(maxContentSize, mainAxisAvailableSpace));
                }

                if (lines.length > 1) {
                    return Sys.f32Max(size, mainAxisAvailableSpace);
                }
                else {
                    return size;
                }

            case MinContent if (constants.isWrap):
                return longestLineLength(lines, constants) + mainContentBoxInset;

            case _:
                // Define a base main_size variable. This is mutated once for iteration over the outer
                // loop over the flex lines as:
                //   "The flex container's max-content size is the largest sum of the afore-calculated sizes of all items within a single line."
                var mainSize = 0.0;

                for (line in lines) {
                    for (item in line.items) {
                        final styleMin = item.minSize.main(constants.dir);
                        final stylePreferred = item.size.main(constants.dir);
                        final styleMax = item.maxSize.main(constants.dir);

                        // The spec seems a bit unclear on this point (my initial reading was that the `.maybe_max(style_preferred)` should
                        // not be included here), however for row containers this matches both Chrome and Firefox as of 9th March 2023.
                        // For column containers the flex base size alone is the clamping basis (as the spec says): a column item's
                        // `height` must not inflate the container's max-content size beyond the item's flex-basis.
                        //
                        // Spec: https://www.w3.org/TR/css-flexbox-1/#intrinsic-item-contributions
                        // Spec modification: https://www.w3.org/TR/css-flexbox-1/#change-2016-max-contribution
                        // Issue: https://github.com/w3c/csswg-drafts/issues/1435
                        // Gentest: padding_border_overrides_size_flex_basis_0.html
                        // Gentest: blockflex_min_content_ignores_own_height_as_percentage_basis.html
                        final clampingBasis:Float = constants.isRow ? item.flexBasis.maybeMaxF(stylePreferred) : item.flexBasis;
                        final flexBasisMin:OptionalFloat = item.flexShrink == 0.0 ? OptionalFloat.some(clampingBasis) : OptionalFloat.NONE;
                        final flexBasisMax:OptionalFloat = item.flexGrow == 0.0 ? OptionalFloat.some(clampingBasis) : OptionalFloat.NONE;

                        final minMainSize = Sys.f32Max(
                            styleMin.maybeMax(flexBasisMin).or(flexBasisMin).unwrapOr(item.resolvedMinimumMainSize),
                            item.resolvedMinimumMainSize
                        );
                        final maxMainSize = styleMax.maybeMin(flexBasisMax).or(flexBasisMax).unwrapOr(Math.POSITIVE_INFINITY);

                        final marginMainSum = item.margin.mainAxisSum(constants.dir);
                        final contentContribution:Float = if (stylePreferred.isSome() && (maxMainSize <= minMainSize || maxMainSize <= stylePreferred.unwrap())) {
                            // If the clamping values are such that max <= min, then we can avoid the expensive step of computing the content size
                            // as we know that the clamping values will override it anyway
                            Sys.f32Max(Sys.f32Min(stylePreferred.unwrap(), maxMainSize), minMainSize) + marginMainSum;
                        }
                        else if (maxMainSize <= minMainSize) {
                            minMainSize + marginMainSum;
                        }
                        else if (item.isScrollContainer()) {
                            // Else compute the min- or -max content size and apply the full formula for computing the
                            // min- or max- content contribution
                            item.flexBasis + marginMainSum;
                        }
                        else if (stylePreferred.isSome()) {
                            // If the item has a definite preferred main size then that is its content
                            // contribution (an inherent-size measure of the item would return it), floored
                            // by the item's main-axis padding+border, so measuring the item can be skipped.
                            // Min/max clamping is applied in the same way as for measured contributions.
                            final itemPbMain = item.padding.mainAxisSum(constants.dir) + item.border.mainAxisSum(constants.dir);
                            final innerMainSize = Sys.f32Max(stylePreferred.unwrap(), itemPbMain);
                            if (constants.isRow) {
                                (innerMainSize + marginMainSum).maybeClampF(styleMin, styleMax);
                            }
                            else {
                                (Sys.f32Max(innerMainSize, item.flexBasis) + marginMainSum).maybeClampF(styleMin, styleMax);
                            }
                        }
                        else {
                            measureIntrinsicMainContribution(tree, item, availableSpace, constants, styleMin, styleMax);
                        };

                        item.contentFlexFraction = {
                            final diff = contentContribution - item.flexBasis;
                            if (diff > 0.0) {
                                diff / Sys.f32Max(1.0, item.flexGrow);
                            }
                            else if (diff < 0.0) {
                                final scaledShrinkFactor = Sys.f32Max(1.0, item.flexShrink) * item.innerFlexBasis;
                                diff / scaledShrinkFactor;
                            }
                            else {
                                // We are assuming that diff is 0.0 here and that we haven't accidentally introduced a NaN
                                0.0;
                            }
                        };
                    }

                    // TODO Spec says to scale everything by the line's max flex fraction. But neither Chrome nor firefox implement this
                    // so we don't either.

                    // Add each item's flex base size to the product of:
                    //   - its flex grow factor (or scaled flex shrink factor,if the chosen max-content flex fraction was negative)
                    //   - the chosen max-content flex fraction
                    // then clamp that result by the max main size floored by the min main size.
                    //
                    // The flex container's max-content size is the largest sum of the afore-calculated sizes of all items within a single line.
                    var itemMainSizeSum = 0.0;
                    for (item in line.items) {
                        final flexFraction = item.contentFlexFraction;

                        final flexContribution = if (item.contentFlexFraction > 0.0) {
                            Sys.f32Max(1.0, item.flexGrow) * flexFraction;
                        }
                        else if (item.contentFlexFraction < 0.0) {
                            final scaledShrinkFactor = Sys.f32Max(1.0, item.flexShrink) * item.innerFlexBasis;
                            if (scaledShrinkFactor == 0.0) {
                                0.0;
                            }
                            else {
                                scaledShrinkFactor * flexFraction;
                            }
                        }
                        else {
                            0.0;
                        };
                        final size = item.flexBasis + flexContribution;
                        item.outerTargetSize.setMain(constants.dir, size);
                        item.targetSize.setMain(constants.dir, size);
                        itemMainSizeSum += size;
                    }

                    final gapSum = sumAxisGaps(constants.gap.main(constants.dir), line.items.length);
                    mainSize = Sys.f32Max(mainSize, itemMainSizeSum + gapSum);
                }

                return mainSize + mainContentBoxInset;
        }
    }

    /** Measure the min- or max- content contribution of an item (last arm of the content contribution match) */
    static function measureIntrinsicMainContribution(
        tree:LayoutFlexboxContainer,
        item:FlexItem,
        availableSpace:SizeAvail,
        constants:AlgoConstants,
        styleMin:OptionalFloat,
        styleMax:OptionalFloat
    ):Float {
        final dir = constants.dir;

        // Parent size for child sizing
        final crossAxisParentSize = constants.nodeInnerSize.cross(dir);

        // Available space for child sizing (excluding the child's margins)
        final childMinCross = item.minSize.cross(dir);
        final childMaxCross = item.maxSize.cross(dir);
        final crossSpace = availableSpace.cross(dir);
        final crossAxisAvailableSpace:AvailableSpace = (crossSpace.isDefinite()
            ? Definite(Sys.f32Max(constants.dividedCrossSpace(crossAxisParentSize.unwrapOr(crossSpace.definiteValue())) - item.margin.crossAxisSum(dir), 0.0))
            : crossSpace).maybeClamp(childMinCross, childMaxCross);

        final childAvailableSpace = availableSpace.withCross(dir, crossAxisAvailableSpace);

        // Known dimensions for child sizing: `item.size.withMain(dir, None)` with its cross size
        // clamped, as values (no size object for the child call)
        // Clamp the definite cross size by the cross min/max sizes, as
        // `determine_flex_base_size` does: an item measured wider than its
        // max-width wraps onto fewer lines and under-reports its height.
        final transferredMinSize = item.minSize.maybeApplyAspectRatio(item.aspectRatio);
        final transferredMaxSize = item.maxSize.maybeApplyAspectRatio(item.aspectRatio);
        var childKnownCross = item.size.cross(dir).maybeClamp(transferredMinSize.cross(dir), transferredMaxSize.cross(dir));
        if (item.alignSelf == AlignItems.STRETCH && childKnownCross.isNone()) {
            childKnownCross = crossAxisAvailableSpace.intoOption();
        }
        final childKnownWidth = dir.isRow() ? OptionalFloat.NONE : childKnownCross;
        final childKnownHeight = dir.isRow() ? childKnownCross : OptionalFloat.NONE;

        // Either the min- or max- content size depending on which constraint we are sizing under.
        // TODO: Optimise by using already computed values where available
        final parentSize = constants.nodeInnerSize;
        final measuredMainSize = tree.measureChildSizeParts(
            item.node,
            childKnownWidth,
            childKnownHeight,
            parentSize.width,
            parentSize.height,
            childAvailableSpace.width,
            childAvailableSpace.height,
            SizingMode.ContentSize,
            dir.mainAxis(),
            FALSE_LINE
        );

        // A known cross size is transferred through the item's aspect-ratio
        // and floors the measured content size
        final ratio = item.aspectRatio;
        final knownCross = childKnownCross;
        final transferredMainSize:OptionalFloat = (ratio.isSome() && knownCross.isSome())
            ? (constants.isRow ? OptionalFloat.some(knownCross.unwrap() * ratio.unwrap()) : OptionalFloat.some(knownCross.unwrap() / ratio.unwrap()))
            : OptionalFloat.NONE;

        final innerMainSize = measuredMainSize.maybeMaxF(transferredMainSize);

        // This is somewhat bizarre in that it's asymmetrical depending whether the flex container is a column or a row.
        //
        // I *think* this might relate to https://drafts.csswg.org/css-flexbox-1/#algo-main-container:
        //
        //    "The automatic block size of a block-level flex container is its max-content size."
        //
        // Which could suggest that flex-basis defining a vertical size does not shrink because it is in the block axis, and the automatic size
        // in the block axis is a MAX content size. Whereas a flex-basis defining a horizontal size does shrink because the automatic size in
        // inline axis is MIN content size (although I don't have a reference for that).
        //
        // Ultimately, this was not found by reading the spec, but by trial and error fixing tests to align with Webkit/Firefox output.
        // (see the `flex_basis_unconstraint_row` and `flex_basis_uncontraint_column` generated tests which demonstrate this)
        if (constants.isRow) {
            return (innerMainSize + item.margin.mainAxisSum(constants.dir)).maybeClampF(styleMin, styleMax);
        }
        else {
            return (Sys.f32Max(innerMainSize, item.flexBasis) + item.margin.mainAxisSum(constants.dir)).maybeClampF(styleMin, styleMax);
        }
    }

    /** Rust `f32::is_normal`: neither zero, infinite, subnormal, nor NaN */
    static inline function isNormal(v:Float):Bool {
        final a = Sys.abs(v);
        return a >= 1.17549435e-38 && a != Math.POSITIVE_INFINITY;
    }

    /** Sum of the outer sizes of the items of a line (outer target size for frozen items, outer flex base size otherwise) */
    static inline function lineUsedSpace(line:FlexLine, constants:AlgoConstants, totalMainAxisGap:Float):Float {
        var sum = 0.0;
        for (child in line.items) {
            if (child.frozen) {
                sum += child.outerTargetSize.main(constants.dir);
            }
            else {
                sum += child.flexBasis + child.margin.mainAxisSum(constants.dir);
            }
        }
        return totalMainAxisGap + sum;
    }

    /**
     * Resolve the flexible lengths of the items within a flex line.
     * Sets the `main` component of each item's `targetSize` and `outerTargetSize`
     *
     * # [9.7. Resolving Flexible Lengths](https://www.w3.org/TR/css-flexbox-1/#resolve-flexible-lengths)
     */
    static function resolveFlexibleLengths(line:FlexLine, constants:AlgoConstants):Void {
        final dir = constants.dir;
        final totalMainAxisGap = sumAxisGaps(constants.gap.main(dir), line.items.length);

        // 1. Determine the used flex factor. Sum the outer hypothetical main sizes of all
        //    items on the line. If the sum is less than the flex container's inner main size,
        //    use the flex grow factor for the rest of this algorithm; otherwise, use the
        //    flex shrink factor.

        var totalHypotheticalOuterMainSize = 0.0;
        for (child in line.items)
            totalHypotheticalOuterMainSize += child.hypotheticalOuterSize.main(dir);
        final usedFlexFactor:Float = totalMainAxisGap + totalHypotheticalOuterMainSize;
        final nodeInnerMain = constants.nodeInnerSize.main(dir);
        final growing = usedFlexFactor < nodeInnerMain.unwrapOr(0.0);
        final shrinking = usedFlexFactor > nodeInnerMain.unwrapOr(0.0);
        final exactlySized = !growing && !shrinking;

        // 2. Size inflexible items. Freeze, setting its target main size to its hypothetical main size
        //    - Any item that has a flex factor of zero
        //    - If using the flex grow factor: any item that has a flex base size
        //      greater than its hypothetical main size
        //    - If using the flex shrink factor: any item that has a flex base size
        //      smaller than its hypothetical main size

        for (child in line.items) {
            final innerTargetSize = child.hypotheticalInnerSize.main(dir);
            child.targetSize.setMain(dir, innerTargetSize);

            if (exactlySized
                || (child.flexGrow == 0.0 && child.flexShrink == 0.0)
                || (growing && child.flexBasis > child.hypotheticalInnerSize.main(dir))
                || (shrinking && child.flexBasis < child.hypotheticalInnerSize.main(dir))) {
                child.frozen = true;
                final outerTargetSize = innerTargetSize + child.margin.mainAxisSum(dir);
                child.outerTargetSize.setMain(dir, outerTargetSize);
            }
        }

        if (exactlySized) {
            return;
        }

        // 3. Calculate initial free space. Sum the outer sizes of all items on the line,
        //    and subtract this from the flex container's inner main size. For frozen items,
        //    use their outer target main size; for other items, use their outer flex base size.

        final initialUsedSpace = lineUsedSpace(line, constants, totalMainAxisGap);
        final initialFreeSpace = nodeInnerMain.maybeSub(OptionalFloat.some(initialUsedSpace)).unwrapOr(0.0);

        // 4. Loop

        // Scratch list (this computation makes no child call, so it is never nested)
        final unfrozen = unfrozenScratch;
        unfrozen.resize(0);
        while (true) {
            // a. Check for flexible items. If all the flex items on the line are frozen,
            //    free space has been distributed; exit this loop.

            var allFrozen = true;
            for (child in line.items) {
                if (!child.frozen) {
                    allFrozen = false;
                    break;
                }
            }
            if (allFrozen) {
                break;
            }

            // b. Calculate the remaining free space as for initial free space, above.
            //    If the sum of the unfrozen flex items' flex factors is less than one,
            //    multiply the initial free space by this sum. If the magnitude of this
            //    value is less than the magnitude of the remaining free space, use this
            //    as the remaining free space.

            final usedSpace = lineUsedSpace(line, constants, totalMainAxisGap);

            unfrozen.resize(0);
            var sumFlexGrow = 0.0;
            var sumFlexShrink = 0.0;
            for (child in line.items) {
                if (!child.frozen) {
                    unfrozen.push(child);
                    sumFlexGrow += child.flexGrow;
                    sumFlexShrink += child.flexShrink;
                }
            }

            final freeSpace:Float = if (growing && sumFlexGrow < 1.0) {
                (initialFreeSpace * sumFlexGrow - totalMainAxisGap).maybeMinF(nodeInnerMain.maybeSub(OptionalFloat.some(usedSpace)));
            }
            else if (shrinking && sumFlexShrink < 1.0) {
                (initialFreeSpace * sumFlexShrink - totalMainAxisGap).maybeMaxF(nodeInnerMain.maybeSub(OptionalFloat.some(usedSpace)));
            }
            else {
                nodeInnerMain.maybeSub(OptionalFloat.some(usedSpace)).unwrapOr(usedFlexFactor - usedSpace);
            };

            // c. Distribute free space proportional to the flex factors.
            //    - If the remaining free space is zero
            //        Do Nothing
            //    - If using the flex grow factor
            //        Find the ratio of the item's flex grow factor to the sum of the
            //        flex grow factors of all unfrozen items on the line. Set the item's
            //        target main size to its flex base size plus a fraction of the remaining
            //        free space proportional to the ratio.
            //    - If using the flex shrink factor
            //        For every unfrozen item on the line, multiply its flex shrink factor by
            //        its inner flex base size, and note this as its scaled flex shrink factor.
            //        Find the ratio of the item's scaled flex shrink factor to the sum of the
            //        scaled flex shrink factors of all unfrozen items on the line. Set the item's
            //        target main size to its flex base size minus a fraction of the absolute value
            //        of the remaining free space proportional to the ratio. Note this may result
            //        in a negative inner main size; it will be corrected in the next step.
            //    - Otherwise
            //        Do Nothing

            if (isNormal(freeSpace)) {
                if (growing && sumFlexGrow > 0.0) {
                    for (child in unfrozen) {
                        child.targetSize.setMain(dir, child.flexBasis + freeSpace * (child.flexGrow / sumFlexGrow));
                    }
                }
                else if (shrinking && sumFlexShrink > 0.0) {
                    var sumScaledShrinkFactor = 0.0;
                    for (child in unfrozen)
                        sumScaledShrinkFactor += child.innerFlexBasis * child.flexShrink;

                    if (sumScaledShrinkFactor > 0.0) {
                        for (child in unfrozen) {
                            final scaledShrinkFactor = child.innerFlexBasis * child.flexShrink;
                            child.targetSize.setMain(dir, child.flexBasis + freeSpace * (scaledShrinkFactor / sumScaledShrinkFactor));
                        }
                    }
                }
            }

            // d. Fix min/max violations. Clamp each non-frozen item's target main size by its
            //    used min and max main sizes and floor its content-box size at zero. If the
            //    item's target main size was made smaller by this, it's a max violation.
            //    If the item's target main size was made larger by this, it's a min violation.

            var totalViolation = 0.0;
            for (child in unfrozen) {
                final resolvedMinMain:OptionalFloat = OptionalFloat.some(child.resolvedMinimumMainSize);
                final maxMain = child.maxSize.main(dir);
                final clamped = Sys.f32Max(child.targetSize.main(dir).maybeClampF(resolvedMinMain, maxMain), 0.0);
                child.violation = clamped - child.targetSize.main(dir);
                child.targetSize.setMain(dir, clamped);
                child.outerTargetSize.setMain(dir, child.targetSize.main(dir) + child.margin.mainAxisSum(dir));

                totalViolation += child.violation;
            }

            // e. Freeze over-flexed items. The total violation is the sum of the adjustments
            //    from the previous step sum(clamped size - unclamped size). If the total violation is:
            //    - Zero
            //        Freeze all items.
            //    - Positive
            //        Freeze all the items with min violations.
            //    - Negative
            //        Freeze all the items with max violations.

            for (child in unfrozen) {
                if (totalViolation > 0.0) {
                    child.frozen = child.violation > 0.0;
                }
                else if (totalViolation < 0.0) {
                    child.frozen = child.violation < 0.0;
                }
                else {
                    child.frozen = true;
                }
            }

            // f. Return to the start of this loop.
        }
    }

    /**
     * Determine the hypothetical cross size of each item.
     *
     * # [9.4. Cross Size Determination](https://www.w3.org/TR/css-flexbox-1/#cross-sizing)
     *
     * - [**Determine the hypothetical cross size of each item**](https://www.w3.org/TR/css-flexbox-1/#algo-cross-item)
     *   by performing layout with the used main size and the available space, treating auto as fit-content.
     */
    static function determineHypotheticalCrossSize(
        tree:LayoutFlexboxContainer,
        line:FlexLine,
        constants:AlgoConstants,
        availableSpace:SizeAvail
    ):Void {
        final dir = constants.dir;
        for (child in line.items) {
            final paddingBorderSum = child.padding.add(child.border).crossAxisSum(dir);

            // The available space passed to the child excludes the child's margins
            final childAvailableMain:AvailableSpace = Definite(Sys.f32Max(constants.containerSize.main(dir) - child.margin.mainAxisSum(dir), 0.0));

            // Sizes transferred through the aspect ratio clamp the hypothetical cross size
            // https://github.com/w3c/csswg-drafts/issues/10997
            final transferredMinCross = child.minSize.maybeApplyAspectRatio(child.aspectRatio).cross(dir);
            final transferredMaxCross = child.maxSize.maybeApplyAspectRatio(child.aspectRatio).cross(dir);

            final childCross = child.size.cross(dir).maybeClamp(transferredMinCross, transferredMaxCross).maybeMax(OptionalFloat.some(paddingBorderSum));

            final crossSpace = availableSpace.cross(dir);
            var childAvailableCross:AvailableSpace = (crossSpace.isDefinite()
                ? Definite(Sys.f32Max(constants.dividedCrossSpace(crossSpace.definiteValue()) - child.margin.crossAxisSum(dir), 0.0))
                : crossSpace).maybeClamp(transferredMinCross, transferredMaxCross).maybeMax(OptionalFloat.some(paddingBorderSum));

            // A cross size that is a sizing keyword (min-content, max-content, fit-content,
            // fit-content(...)) determines the available space constraint the item is measured under.
            // The `stretch` keyword is not resolved here: it stretches to the flex line, which is
            // handled in `determineUsedCrossSize`
            final nodeInnerCross = constants.nodeInnerSize.cross(dir);
            final crossStretchSize:OptionalFloat = nodeInnerCross.isSome()
                ? OptionalFloat.some(Sys.f32Max(constants.dividedCrossSpace(nodeInnerCross.unwrap()) - child.margin.crossAxisSum(dir), 0.0))
                : OptionalFloat.NONE;
            final resolution = SizingKeyword.resolveSizingKeyword(child.sizeStyle.cross(dir), crossStretchSize, nodeInnerCross);
            if (resolution != null) {
                switch resolution {
                    case Measure(available):
                        childAvailableCross = available;
                    case _:
                }
            }

            final childInnerCross:Float = if (childCross.isSome()) {
                childCross.unwrap();
            }
            else {
                final nodeInnerSize = constants.nodeInnerSize;
                final output = tree.computeChildLayout(child.node, LayoutInput.acquireParts(
                    RunMode.ComputeSize,
                    SizingMode.ContentSize,
                    RequestedAxis.fromAbsoluteAxis(dir.crossAxis()),
                    constants.isRow ? OptionalFloat.some(child.targetSize.width) : childCross,
                    constants.isRow ? childCross : OptionalFloat.some(child.targetSize.height),
                    itemKnownDimensionDefiniteness(constants, child),
                    nodeInnerSize.width,
                    nodeInnerSize.height,
                    constants.isRow ? childAvailableMain : childAvailableCross,
                    constants.isRow ? childAvailableCross : childAvailableMain,
                    FALSE_LINE
                ));
                LayoutInput.release();
                Sys.f32Max(output.size.getAbs(dir.crossAxis()).maybeClampF(transferredMinCross, transferredMaxCross), paddingBorderSum);
            };
            final childOuterCross = childInnerCross + child.margin.crossAxisSum(dir);

            child.hypotheticalInnerSize.setCross(dir, childInnerCross);
            child.hypotheticalOuterSize.setCross(dir, childOuterCross);
        }
    }

    /** Calculate the base lines of the children. */
    static function calculateChildrenBaseLines(
        tree:LayoutFlexboxContainer,
        nodeSize:SizeOpt,
        availableSpace:SizeAvail,
        flexLines:Array<FlexLine>,
        constants:AlgoConstants
    ):Void {
        // Only compute baselines for flex rows because we only support baseline alignment in the cross axis
        // where that axis is also the inline axis
        // TODO: this may need revisiting if/when we support vertical writing modes
        if (!constants.isRow) {
            return;
        }

        for (line in flexLines) {
            // If a flex line has one or zero items participating in baseline alignment then baseline alignment is a no-op so we skip
            var lineBaselineChildCount = 0;
            for (child in line.items) {
                if (child.participatesInBaselineAlignment(constants.dir))
                    lineBaselineChildCount++;
            }
            if (lineBaselineChildCount <= 1) {
                continue;
            }

            for (child in line.items) {
                // Only calculate baselines for children participating in baseline alignment
                if (!child.participatesInBaselineAlignment(constants.dir)) {
                    continue;
                }

                // The available space passed to the child excludes the child's margins
                final childAvailableSpace = new SizeAvail(
                    constants.isRow ? Definite(constants.containerSize.width) : availableSpace.width.maybeSet(nodeSize.width),
                    constants.isRow ? availableSpace.height.maybeSet(nodeSize.height) : Definite(constants.containerSize.height)
                ).maybeSubSize(child.margin.sumAxes()).maybeMaxSize(Size.ZERO);
                final nodeInnerSize = constants.nodeInnerSize;
                final measuredSizeAndBaselines = tree.computeChildLayout(child.node, LayoutInput.acquireParts(
                    RunMode.PerformLayout,
                    SizingMode.ContentSize,
                    RequestedAxis.Both,
                    constants.isRow ? OptionalFloat.some(child.targetSize.width) : OptionalFloat.some(child.hypotheticalInnerSize.width),
                    constants.isRow ? OptionalFloat.some(child.hypotheticalInnerSize.height) : OptionalFloat.some(child.targetSize.height),
                    itemKnownDimensionDefiniteness(constants, child),
                    nodeInnerSize.width,
                    nodeInnerSize.height,
                    childAvailableSpace.width,
                    childAvailableSpace.height,
                    FALSE_LINE
                ));
                LayoutInput.release();

                final baseline = measuredSizeAndBaselines.baselines.first;
                final height = measuredSizeAndBaselines.size.height;

                // Scroll containers' baselines are determined from their content as if scrolled to the
                // initial position, but are additionally clamped to their border box.
                // See https://github.com/w3c/csswg-drafts/issues/7660
                final resolvedBaseline = if (child.overflow.y.isScrollContainer()) {
                    Sys.f32Max(Sys.f32Min(baseline.unwrapOr(height), height), 0.0);
                }
                else {
                    baseline.unwrapOr(height);
                };

                child.baseline = resolvedBaseline + child.margin.top;
            }
        }
    }

    /**
     * Calculate the cross size of each flex line.
     *
     * # [9.4. Cross Size Determination](https://www.w3.org/TR/css-flexbox-1/#cross-sizing)
     *
     * - [**Calculate the cross size of each flex line**](https://www.w3.org/TR/css-flexbox-1/#algo-cross-line).
     */
    static function calculateCrossSize(flexLines:Array<FlexLine>, nodeSize:SizeOpt, constants:AlgoConstants):Void {
        final dir = constants.dir;
        // If the flex container is single-line and has a definite cross size,
        // the cross size of the flex line is the flex container's inner cross size.
        if (!constants.isWrap && nodeSize.cross(dir).isSome()) {
            final crossAxisPaddingBorder = constants.contentBoxInset.crossAxisSum(dir);
            final crossMinSize = constants.minSize.cross(dir);
            final crossMaxSize = constants.maxSize.cross(dir);
            flexLines[0].crossSize = nodeSize.cross(dir)
                .maybeClamp(crossMinSize, crossMaxSize)
                .maybeSub(OptionalFloat.some(crossAxisPaddingBorder))
                .maybeMax(OptionalFloat.some(0.0))
                .unwrapOr(0.0);
        }
        else {
            // Otherwise, for each flex line:
            //
            //    1. Collect all the flex items whose inline-axis is parallel to the main-axis, whose
            //       align-self is baseline, and whose cross-axis margins are both non-auto. Find the
            //       largest of the distances between each item's baseline and its hypothetical outer
            //       cross-start edge, and the largest of the distances between each item's baseline
            //       and its hypothetical outer cross-end edge, and sum these two values.

            //    2. Among all the items not collected by the previous step, find the largest
            //       outer hypothetical cross size.

            //    3. The used cross-size of the flex line is the largest of the numbers found in the
            //       previous two steps and zero.
            for (line in flexLines) {
                var maxBaseline = 0.0;
                for (child in line.items)
                    maxBaseline = Sys.f32Max(maxBaseline, child.baseline);
                var crossSize = 0.0;
                for (child in line.items) {
                    final value = if (child.participatesInBaselineAlignment(dir)) {
                        maxBaseline - child.baseline + child.hypotheticalOuterSize.cross(dir);
                    }
                    else {
                        child.hypotheticalOuterSize.cross(dir);
                    };
                    crossSize = Sys.f32Max(crossSize, value);
                }
                line.crossSize = crossSize;
            }

            // If the flex container is single-line, then clamp the line's cross-size to be within the container's computed min and max cross sizes.
            // Note that if CSS 2.1's definition of min/max-width/height applied more generally, this behavior would fall out automatically.
            if (!constants.isWrap) {
                final crossAxisPaddingBorder = constants.contentBoxInset.crossAxisSum(dir);
                final crossMinSize = constants.minSize.cross(dir);
                final crossMaxSize = constants.maxSize.cross(dir);
                flexLines[0].crossSize = flexLines[0].crossSize.maybeClampF(
                    crossMinSize.maybeSub(OptionalFloat.some(crossAxisPaddingBorder)),
                    crossMaxSize.maybeSub(OptionalFloat.some(crossAxisPaddingBorder))
                );
            }
        }
    }

    /**
     * Handle 'align-content: stretch'.
     *
     * # [9.4. Cross Size Determination](https://www.w3.org/TR/css-flexbox-1/#cross-sizing)
     *
     * - [**Handle 'align-content: stretch'**](https://www.w3.org/TR/css-flexbox-1/#algo-line-stretch). If the flex container has a definite cross size, align-content is stretch,
     *   and the sum of the flex lines' cross sizes is less than the flex container's inner cross size,
     *   increase the cross size of each flex line by equal amounts such that the sum of their cross sizes exactly equals the flex container's inner cross size.
     */
    static function handleAlignContentStretch(flexLines:Array<FlexLine>, nodeSize:SizeOpt, constants:AlgoConstants):Void {
        final dir = constants.dir;
        if (constants.alignContent == AlignContent.STRETCH) {
            final crossAxisPaddingBorder = constants.contentBoxInset.crossAxisSum(dir);
            final crossMinSize = constants.minSize.cross(dir);
            final crossMaxSize = constants.maxSize.cross(dir);
            final containerMinInnerCross = nodeSize.cross(dir)
                .or(crossMinSize)
                .maybeClamp(crossMinSize, crossMaxSize)
                .maybeSub(OptionalFloat.some(crossAxisPaddingBorder))
                .maybeMax(OptionalFloat.some(0.0))
                .unwrapOr(0.0);

            final totalCrossAxisGap = sumAxisGaps(constants.gap.cross(dir), flexLines.length);
            var linesTotalCross = 0.0;
            for (line in flexLines)
                linesTotalCross += line.crossSize;
            linesTotalCross += totalCrossAxisGap;

            if (linesTotalCross < containerMinInnerCross) {
                final remaining = containerMinInnerCross - linesTotalCross;
                final addition = remaining / flexLines.length;
                for (line in flexLines)
                    line.crossSize += addition;
            }
        }
    }

    /**
     * Determine the used cross size of each flex item.
     *
     * # [9.4. Cross Size Determination](https://www.w3.org/TR/css-flexbox-1/#cross-sizing)
     *
     * - [**Determine the used cross size of each flex item**](https://www.w3.org/TR/css-flexbox-1/#algo-stretch). If a flex item has align-self: stretch, its computed cross size property is auto,
     *   and neither of its cross-axis margins are auto, the used outer cross size is the used cross size of its flex line, clamped according to the item's used min and max cross sizes.
     *   Otherwise, the used cross size is the item's hypothetical cross size.
     *
     *   If the flex item has align-self: stretch, redo layout for its contents, treating this used size as its definite cross size so that percentage-sized children can be resolved.
     *
     *   **Note that this step does not affect the main size of the flex item, even if it has an intrinsic aspect ratio**.
     */
    static function determineUsedCrossSize(tree:LayoutFlexboxContainer, flexLines:Array<FlexLine>, constants:AlgoConstants):Void {
        final dir = constants.dir;
        for (line in flexLines) {
            final lineCrossSize = line.crossSize;

            for (child in line.items) {
                final childStyle = tree.getFlexboxChildStyle(child.node);
                // A cross size of `stretch` stretches to the flex line like align-self: stretch
                // (but regardless of the alignment style)
                final crossIsStretch = child.sizeStyle.cross(dir).isStretch();
                final crossTarget:Float = if (!child.marginIsAuto.crossStart(dir)
                    && !child.marginIsAuto.crossEnd(dir)
                    && (crossIsStretch || (child.alignSelf == AlignItems.STRETCH && childStyle.size.cross(dir).isAuto()))) {
                    // For some reason this particular usage of max_width is an exception to the rule that max_width's transfer
                    // using the aspect_ratio (if set). Both Chrome and Firefox agree on this. And reading the spec, it seems like
                    // a reasonable interpretation. Although it seems to me that the spec *should* apply aspect_ratio here.
                    // Percentage padding and border resolve against the container's inline size
                    // (its width) on all four sides, not against its height for the top/bottom sides
                    final padding = childStyle.padding.resolveOrZero(constants.nodeInnerSize.width);
                    final border = childStyle.border.resolveOrZero(constants.nodeInnerSize.width);
                    final pbSum = padding.add(border).sumAxes();
                    final boxSizingAdjustment = childStyle.boxSizing == BoxSizing.ContentBox ? pbSum : Size.ZERO;

                    final maxSizeIgnoringAspectRatio = childStyle.maxSize.maybeResolve(constants.nodeInnerSize).maybeAddSize(boxSizingAdjustment);

                    Sys.f32Max(lineCrossSize - child.margin.crossAxisSum(dir), 0.0).maybeClampF(
                        child.minSize.cross(dir),
                        maxSizeIgnoringAspectRatio.cross(dir)
                    );
                }
                else {
                    child.hypotheticalInnerSize.cross(dir);
                };
                child.targetSize.setCross(dir, crossTarget);

                child.outerTargetSize.setCross(dir, child.targetSize.cross(dir) + child.margin.crossAxisSum(dir));
            }
        }
    }

    /**
     * Distribute any remaining free space.
     *
     * # [9.5. Main-Axis Alignment](https://www.w3.org/TR/css-flexbox-1/#main-alignment)
     *
     * - [**Distribute any remaining free space**](https://www.w3.org/TR/css-flexbox-1/#algo-main-align). For each flex line:
     *
     *   1. If the remaining free space is positive and at least one main-axis margin on this line is `auto`, distribute the free space equally among these margins.
     *      Otherwise, set all `auto` margins to zero.
     *
     *   2. Align the items along the main-axis per `justify-content`.
     */
    static function distributeRemainingFreeSpace(flexLines:Array<FlexLine>, constants:AlgoConstants):Void {
        final dir = constants.dir;
        for (line in flexLines) {
            final totalMainAxisGap = sumAxisGaps(constants.gap.main(dir), line.items.length);
            var usedSpace = totalMainAxisGap;
            for (child in line.items)
                usedSpace += child.outerTargetSize.main(dir);
            var freeSpace = constants.innerContainerSize.main(dir) - usedSpace;
            var numAutoMargins = 0;

            for (child in line.items) {
                if (child.marginIsAuto.mainStart(dir)) {
                    numAutoMargins += 1;
                }
                if (child.marginIsAuto.mainEnd(dir)) {
                    numAutoMargins += 1;
                }
            }

            if (freeSpace > 0.0 && numAutoMargins > 0) {
                final margin = freeSpace / numAutoMargins;

                for (child in line.items) {
                    if (child.marginIsAuto.mainStart(dir)) {
                        if (constants.isRow) {
                            child.margin = child.margin.withLeft(margin);
                        }
                        else {
                            child.margin = child.margin.withTop(margin);
                        }
                    }
                    if (child.marginIsAuto.mainEnd(dir)) {
                        if (constants.isRow) {
                            child.margin = child.margin.withRight(margin);
                        }
                        else {
                            child.margin = child.margin.withBottom(margin);
                        }
                    }
                }

                // The auto margins have absorbed all of the free space, leaving none for `justify-content`
                freeSpace = 0.0;
            }

            final numItems = line.items.length;
            final layoutReverse = dir.isReverse();
            final gap = constants.gap.main(dir);
            final justifyContentMode = Alignment.applyAlignmentFallback(freeSpace, numItems, constants.justifyContent);

            if (layoutReverse) {
                for (i in 0...numItems) {
                    final child = line.items[numItems - 1 - i];
                    child.offsetMain = Alignment.computeAlignmentOffset(freeSpace, numItems, gap, justifyContentMode, layoutReverse, i == 0);
                }
            }
            else {
                for (i in 0...numItems) {
                    final child = line.items[i];
                    child.offsetMain = Alignment.computeAlignmentOffset(freeSpace, numItems, gap, justifyContentMode, layoutReverse, i == 0);
                }
            }
        }
    }

    /**
     * Resolve cross-axis `auto` margins.
     *
     * # [9.6. Cross-Axis Alignment](https://www.w3.org/TR/css-flexbox-1/#cross-alignment)
     *
     * - [**Resolve cross-axis `auto` margins**](https://www.w3.org/TR/css-flexbox-1/#algo-cross-margins).
     *   If a flex item has auto cross-axis margins:
     *
     *   - If its outer cross size (treating those auto margins as zero) is less than the cross size of its flex line,
     *     distribute the difference in those sizes equally to the auto margins.
     *
     *   - Otherwise, if the block-start or inline-start margin (whichever is in the cross axis) is auto, set it to zero.
     *     Set the opposite margin so that the outer cross size of the item equals the cross size of its flex line.
     */
    static function resolveCrossAxisAutoMargins(flexLines:Array<FlexLine>, constants:AlgoConstants):Void {
        final dir = constants.dir;
        for (line in flexLines) {
            final lineCrossSize = line.crossSize;
            var maxBaseline = 0.0;
            for (child in line.items)
                maxBaseline = Sys.f32Max(maxBaseline, child.baseline);
            var maxBaselineToBottomDistance = 0.0;
            for (child in line.items) {
                if (child.participatesInBaselineAlignment(dir))
                    maxBaselineToBottomDistance = Sys.f32Max(maxBaselineToBottomDistance, child.outerTargetSize.cross(dir) - child.baseline);
            }

            for (child in line.items) {
                final freeSpace = lineCrossSize - child.outerTargetSize.cross(dir);

                if (child.marginIsAuto.crossStart(dir) && child.marginIsAuto.crossEnd(dir)) {
                    if (constants.isRow) {
                        child.margin = child.margin.withTop(freeSpace / 2.0).withBottom(freeSpace / 2.0);
                    }
                    else {
                        child.margin = child.margin.withLeft(freeSpace / 2.0).withRight(freeSpace / 2.0);
                    }
                }
                else if (child.marginIsAuto.crossStart(dir)) {
                    if (constants.isRow) {
                        child.margin = child.margin.withTop(freeSpace);
                    }
                    else {
                        child.margin = child.margin.withLeft(freeSpace);
                    }
                }
                else if (child.marginIsAuto.crossEnd(dir)) {
                    if (constants.isRow) {
                        child.margin = child.margin.withBottom(freeSpace);
                    }
                    else {
                        child.margin = child.margin.withRight(freeSpace);
                    }
                }
                else {
                    // 14. Align all flex items along the cross-axis.
                    child.offsetCross = alignFlexItemsAlongCrossAxis(child, freeSpace, maxBaseline, maxBaselineToBottomDistance, constants);
                }
            }
        }
    }

    /**
     * Align all flex items along the cross-axis.
     *
     * # [9.6. Cross-Axis Alignment](https://www.w3.org/TR/css-flexbox-1/#cross-alignment)
     *
     * - [**Align all flex items along the cross-axis**](https://www.w3.org/TR/css-flexbox-1/#algo-cross-align) per `align-self`,
     *   if neither of the item's cross-axis margins are `auto`.
     */
    static function alignFlexItemsAlongCrossAxis(
        child:FlexItem,
        freeSpace:Float,
        maxBaseline:Float,
        maxBaselineToBottomDistance:Float,
        constants:AlgoConstants
    ):Float {
        final crossAxisShouldReverse = constants.isColumn && constants.layoutDirection == Direction.Rtl;

        // If align-self uses a "safe" overflow-position keyword and the item would overflow its
        // line cross size, fall back to logical Start to avoid data loss. See CSS Box Alignment 3
        // §4.3 https://www.w3.org/TR/css-align-3/#overflow-values. Otherwise, drop the safety
        // field so the match below operates on a bare keyword.
        final alignKeyword = (child.alignSelf.isSafe() && freeSpace < 0.0) ? AlignItemsKeyword.Start : child.alignSelf.keyword;

        return switch alignKeyword {
            case Start:
                crossAxisShouldReverse ? freeSpace : 0.0;
            case FlexStart:
                (constants.isWrapReverse != crossAxisShouldReverse) ? freeSpace : 0.0;
            case End:
                crossAxisShouldReverse ? 0.0 : freeSpace;
            case FlexEnd:
                (constants.isWrapReverse != crossAxisShouldReverse) ? 0.0 : freeSpace;
            case Center:
                freeSpace / 2.0;
            case Baseline:
                if (constants.isRow) {
                    if (constants.isWrapReverse) {
                        // In a wrap-reverse container the cross axis is flipped, so the baseline-aligned
                        // group of items is aligned to the cross-start edge, which is the bottom of the line.
                        final lineCrossSize = freeSpace + child.outerTargetSize.cross(constants.dir);
                        lineCrossSize - maxBaselineToBottomDistance - child.baseline;
                    }
                    else {
                        maxBaseline - child.baseline;
                    }
                }
                else {
                    // Until we support vertical writing modes, baseline alignment only makes sense if
                    // the constants.direction is row, so we treat it as flex-start alignment in columns.
                    final baselineColumnShouldReverse = crossAxisShouldReverse && !constants.isWrap;
                    (constants.isWrapReverse != baselineColumnShouldReverse) ? freeSpace : 0.0;
                }
            case Stretch:
                (constants.isWrapReverse != crossAxisShouldReverse) ? freeSpace : 0.0;
            // Normal is resolved to Stretch, and SelfStart/SelfEnd are resolved to Start/End
            // against the item's own direction when flex items are generated.
            case Normal | SelfStart | SelfEnd:
                throw "unreachable";
        }
    }

    /**
     * Determine the flex container's used cross size.
     *
     * # [9.6. Cross-Axis Alignment](https://www.w3.org/TR/css-flexbox-1/#cross-alignment)
     *
     * - [**Determine the flex container's used cross size**](https://www.w3.org/TR/css-flexbox-1/#algo-cross-container):
     *
     *     - If the cross size property is a definite size, use that, clamped by the used min and max cross sizes of the flex container.
     *
     *     - Otherwise, use the sum of the flex lines' cross sizes, clamped by the used min and max cross sizes of the flex container.
     */
    static function determineContainerCrossSize(flexLines:Array<FlexLine>, nodeSize:SizeOpt, constants:AlgoConstants):Float {
        final dir = constants.dir;
        final totalCrossAxisGap = sumAxisGaps(constants.gap.cross(dir), flexLines.length);
        var totalLineCrossSize = 0.0;
        for (line in flexLines)
            totalLineCrossSize += line.crossSize;

        final paddingBorderSum = constants.contentBoxInset.crossAxisSum(dir);
        final crossScrollbarGutter = constants.scrollbarGutter.cross(dir);
        final minCrossSize = constants.minSize.cross(dir);
        final maxCrossSize = constants.maxSize.cross(dir);
        final outerContainerSize = Sys.f32Max(
            nodeSize.cross(dir)
                .unwrapOr(totalLineCrossSize + totalCrossAxisGap + paddingBorderSum)
                .maybeClampF(minCrossSize, maxCrossSize),
            paddingBorderSum - crossScrollbarGutter
        );
        final innerContainerSize = Sys.f32Max(outerContainerSize - paddingBorderSum, 0.0);

        constants.containerSize.setCross(dir, outerContainerSize);
        constants.innerContainerSize.setCross(dir, innerContainerSize);

        return totalLineCrossSize;
    }

    /**
     * Align all flex lines per `align-content`.
     *
     * # [9.6. Cross-Axis Alignment](https://www.w3.org/TR/css-flexbox-1/#cross-alignment)
     *
     * - [**Align all flex lines**](https://www.w3.org/TR/css-flexbox-1/#algo-line-align) per `align-content`.
     */
    static function alignFlexLinesPerAlignContent(flexLines:Array<FlexLine>, constants:AlgoConstants, totalCrossSize:Float):Void {
        final numLines = flexLines.length;
        final gap = constants.gap.cross(constants.dir);
        final totalCrossAxisGap = sumAxisGaps(gap, numLines);
        final freeSpace = constants.innerContainerSize.cross(constants.dir) - totalCrossSize - totalCrossAxisGap;

        final alignContentMode = Alignment.applyAlignmentFallback(freeSpace, numLines, constants.alignContent);

        if (constants.isWrapReverse) {
            for (i in 0...numLines) {
                final line = flexLines[numLines - 1 - i];
                line.offsetCross = Alignment.computeAlignmentOffset(freeSpace, numLines, gap, alignContentMode, constants.isWrapReverse, i == 0);
            }
        }
        else {
            for (i in 0...numLines) {
                final line = flexLines[i];
                line.offsetCross = Alignment.computeAlignmentOffset(freeSpace, numLines, gap, alignContentMode, constants.isWrapReverse, i == 0);
            }
        }
    }

    /** Calculates the layout for a flex-item */
    static function calculateFlexItem(
        tree:LayoutFlexboxContainer,
        item:FlexItem,
        state:FinalPassState,
        totalOffsetCross:Float,
        lineOffsetCross:Float,
        border:Rect,
        constants:AlgoConstants
    ):Void {
        final containerSize = constants.containerSize;
        final nodeInnerSize = constants.nodeInnerSize;
        final direction = constants.dir;
        final layoutDirection = constants.layoutDirection;
        final definiteness = itemKnownDimensionDefiniteness(constants, item);
        final marginSum = item.margin.sumAxes();
        final layoutOutput = tree.computeChildLayout(item.node, LayoutInput.acquireParts(
            RunMode.PerformLayout,
            SizingMode.ContentSize,
            RequestedAxis.Both,
            // `item.targetSize.toOptions()`
            OptionalFloat.some(item.targetSize.width),
            OptionalFloat.some(item.targetSize.height),
            definiteness,
            nodeInnerSize.width,
            nodeInnerSize.height,
            // The available space passed to the child excludes the child's margins
            Definite(Sys.f32Max(containerSize.width - marginSum.width, 0.0)),
            Definite(Sys.f32Max(containerSize.height - marginSum.height, 0.0)),
            FALSE_LINE
        ));
        LayoutInput.release();
        final size = layoutOutput.size;
        final scrollableOverflowRect = layoutOutput.scrollableOverflowRect;

        final isRtlRow = direction.isRow() && layoutDirection.isRtl();
        final isRtlColumn = direction.isColumn() && layoutDirection.isRtl();
        final mainRelativeInset = item.relativeInset.main(direction);
        final crossRelativeInset = item.relativeInset.cross(direction);
        final effectiveLineOffsetCross = isRtlColumn ? 0.0 : lineOffsetCross;

        final offsetMain = if (isRtlRow) {
            state.totalOffsetMain - item.offsetMain - item.margin.mainEnd(direction) - mainRelativeInset - size.width;
        }
        else {
            state.totalOffsetMain + item.offsetMain + item.margin.mainStart(direction) + mainRelativeInset;
        };

        final offsetCross = totalOffsetCross
            + item.offsetCross
            + effectiveLineOffsetCross
            + item.margin.crossStart(direction)
            + crossRelativeInset;

        if (direction.isRow()) {
            final baselineOffsetCross = totalOffsetCross + item.offsetCross + effectiveLineOffsetCross + item.margin.crossStart(direction);
            // Scroll containers' baselines are determined from their content as if scrolled to the initial
            // position, but are additionally clamped to their border box.
            // See https://github.com/w3c/csswg-drafts/issues/7660
            final baseline = layoutOutput.baselines.first.unwrapOr(size.height);
            final innerBaseline = item.overflow.y.isScrollContainer() ? Sys.f32Max(Sys.f32Min(baseline, size.height), 0.0) : baseline;
            item.baseline = baselineOffsetCross + innerBaseline;
        }
        else {
            final baselineOffsetMain = state.totalOffsetMain + item.offsetMain + item.margin.mainStart(direction);
            final innerBaseline = layoutOutput.baselines.first.unwrapOr(size.height);
            item.baseline = baselineOffsetMain + innerBaseline;
        }

        final location = direction.isRow() ? new Point(offsetMain, offsetCross) : new Point(offsetCross, offsetMain);
        final scrollbarSize = new Size(
            item.overflow.y == Overflow.Scroll ? item.scrollbarWidth : 0.0,
            item.overflow.x == Overflow.Scroll ? item.scrollbarWidth : 0.0
        );

        tree.setUnroundedLayout(item.node, new Layout(
            item.order,
            location,
            size,
            scrollableOverflowRect,
            scrollbarSize,
            item.border,
            item.padding,
            item.margin
        ));

        // Keep out-of-flow candidates from the item's subtree, translating anchors from
        // item-relative to container-relative coordinates
        item.oofCandidates = layoutOutput.oofCandidates.take();
        if (!item.oofCandidates.isEmpty()) {
            item.oofCandidates.translate(location);
        }

        if (isRtlRow) {
            state.totalOffsetMain -= item.offsetMain + item.margin.mainAxisSum(direction) + size.main(direction);
        }
        else {
            state.totalOffsetMain += item.offsetMain + item.margin.mainAxisSum(direction) + size.main(direction);
        }

        final isRtlLocation = layoutDirection.isRtl();
        final contributionLocation = new Point(isRtlLocation ? containerSize.width - (location.x + size.width) - border.right : location.x - border.left, location.y - border.top);
        state.overflowRect = state.overflowRect.union(ScrollableOverflow.computeScrollableOverflowContribution(
            contributionLocation,
            size,
            scrollableOverflowRect,
            item.overflow,
            item.contain,
            constants.isScrollContainer
        ));
    }

    /** Calculates the layout line */
    static function calculateLayoutLine(
        tree:LayoutFlexboxContainer,
        line:FlexLine,
        state:FinalPassState,
        border:Rect,
        constants:AlgoConstants
    ):Void {
        final containerSize = constants.containerSize;
        final paddingBorder = constants.contentBoxInset;
        final direction = constants.dir;
        final layoutDirection = constants.layoutDirection;
        state.totalOffsetMain = if (layoutDirection.isRtl() && direction.isRow()) {
            containerSize.width - paddingBorder.mainEnd(direction);
        }
        else {
            paddingBorder.mainStart(direction);
        };
        final lineOffsetCross = line.offsetCross;

        final isRtlColumn = layoutDirection.isRtl() && direction.isColumn();
        if (isRtlColumn) {
            state.totalOffsetCross -= lineOffsetCross + line.crossSize;
        }

        final items = line.items;
        if (direction.isReverse()) {
            var i = items.length - 1;
            while (i >= 0) {
                calculateFlexItem(tree, items[i], state, state.totalOffsetCross, lineOffsetCross, border, constants);
                i--;
            }
        }
        else {
            for (item in items) {
                calculateFlexItem(tree, item, state, state.totalOffsetCross, lineOffsetCross, border, constants);
            }
        }

        if (!isRtlColumn) {
            state.totalOffsetCross += lineOffsetCross + line.crossSize;
        }
    }

    /** Do a final layout pass and collect the resulting layouts. */
    static function finalLayoutPass(tree:LayoutFlexboxContainer, flexLines:Array<FlexLine>, constants:AlgoConstants):Rect {
        final state = new FinalPassState();
        state.totalOffsetCross = if (constants.isColumn && constants.layoutDirection.isRtl()) {
            constants.containerSize.width - constants.contentBoxInset.crossEnd(constants.dir);
        }
        else {
            constants.contentBoxInset.crossStart(constants.dir);
        };

        if (constants.isWrapReverse) {
            var i = flexLines.length - 1;
            while (i >= 0) {
                calculateLayoutLine(tree, flexLines[i], state, constants.border, constants);
                i--;
            }
        }
        else {
            for (line in flexLines) {
                calculateLayoutLine(tree, line, state, constants.border, constants);
            }
        }

        var overflowRect = state.overflowRect;

        // A scroll container's own padding at the end of the content is part of its scrollable
        // overflow region, so it is included in the overflow rect. Boxes that are not scroll
        // containers do not extend their overflow region by their own padding.
        if (constants.isScrollContainer) {
            final rightAddition = if (constants.layoutDirection.isRtl()) {
                constants.contentBoxInset.left - constants.border.left - constants.scrollbarGutter.x;
            }
            else {
                constants.contentBoxInset.right - constants.border.right - constants.scrollbarGutter.x;
            };
            overflowRect = overflowRect
                .withRight(overflowRect.right + rightAddition)
                .withBottom(overflowRect.bottom + constants.contentBoxInset.bottom - constants.border.bottom - constants.scrollbarGutter.y);
        }

        return overflowRect;
    }

    /** The static edge of the main axis for a `justify-content` keyword */
    static function mainStaticEdge(mainKeyword:AlignContentKeyword, mainAxisFlexStartReversed:Bool, mainIsRtl:Bool):AxisStaticEdge {
        // `start`/`end` are writing-mode relative (they flip for RTL but not for
        // reversed flex-directions), whereas `flex-start`/`flex-end` and the
        // distributed keywords' fallbacks are flex-relative.
        final mainStartPosition = switch mainKeyword {
            case Start: !mainIsRtl;
            case End: mainIsRtl;
            case _: true;
        }
        return switch mainKeyword {
            case Start | End:
                mainStartPosition ? AxisStaticEdge.Start : AxisStaticEdge.End;
            case SpaceBetween | Normal | Stretch | FlexStart:
                mainAxisFlexStartReversed ? AxisStaticEdge.End : AxisStaticEdge.Start;
            case FlexEnd:
                mainAxisFlexStartReversed ? AxisStaticEdge.Start : AxisStaticEdge.End;
            case SpaceEvenly | SpaceAround | Center:
                AxisStaticEdge.Center;
        }
    }

    /**
     * The static edge of the cross axis for an `align-self` keyword.
     *
     * `start`/`end` (and `baseline`, whose static-position fallback is `start`) are
     * writing-mode relative: they flip for RTL but not for `wrap-reverse`.
     * `flex-start`/`flex-end` and the `stretch` fallback are flex-relative.
     */
    static function crossEdgeFor(keyword:AlignItemsKeyword, crossIsRtl:Bool, crossAxisFlexStartReversed:Bool):AxisStaticEdge {
        final startPosition = switch keyword {
            case Start | Baseline: !crossIsRtl;
            case End: crossIsRtl;
            case _: true;
        }
        return switch keyword {
            // Stretch alignment does not apply to absolutely positioned items
            // See "Example 3" at https://www.w3.org/TR/css-flexbox-1/#abspos-items
            // Note: Stretch should be FlexStart not Start when we support both
            case Start | End | Baseline:
                startPosition ? AxisStaticEdge.Start : AxisStaticEdge.End;
            case Stretch | FlexStart:
                crossAxisFlexStartReversed ? AxisStaticEdge.End : AxisStaticEdge.Start;
            case FlexEnd:
                crossAxisFlexStartReversed ? AxisStaticEdge.Start : AxisStaticEdge.End;
            case Center:
                AxisStaticEdge.Center;
            // Normal is resolved to Stretch, and SelfStart/SelfEnd are resolved to Start/End
            // against the item's own direction where `align_self` is read above.
            case Normal | SelfStart | SelfEnd:
                throw "unreachable";
        }
    }

    /**
     * Collect out-of-flow candidates in document order: direct out-of-flow children (computing their
     * static positions per the flexbox alignment rules) interleaved with the candidates bubbled out
     * of each in-flow item's subtree. Final sizing and positioning happens in the shared
     * out-of-flow positioning pass at the containing block.
     */
    /** The unfrozen items of `resolveFlexibleLengths` (reused from call to call) */
    static final unfrozenScratch:Array<FlexItem> = [];

    static function collectOofCandidates(
        tree:LayoutFlexboxContainer,
        node:NodeId,
        constants:AlgoConstants,
        flexItems:Array<FlexItem>
    ):OofCandidates {
        // Made on the first candidate (`OofCandidates.EMPTY` when there is none)
        var candidates:Null<OofCandidates> = null;
        // Lines are contiguous slices of the items in document order (reversal is applied to
        // positions, not storage), so walking the items yields items sorted by `order`
        var itemIndex = 0;
        final itemCount = flexItems.length;
        while (itemIndex < itemCount && flexItems[itemIndex].oofCandidates.isEmpty())
            itemIndex++;

        final dir = constants.dir;
        final containerSize = constants.containerSize;
        final contentBoxInset = constants.contentBoxInset;

        final mainAxisIsHorizontal = constants.isRow;
        final crossAxisIsHorizontal = !constants.isRow;
        final mainIsRtl = mainAxisIsHorizontal && constants.layoutDirection.isRtl();
        final crossIsRtl = crossAxisIsHorizontal && constants.layoutDirection.isRtl();
        final mainAxisFlexStartReversed = dir.isReverse() != mainIsRtl;
        final crossAxisFlexStartReversed = constants.isWrapReverse != crossIsRtl;

        // The static-position area in each axis is the container's content box (made for the
        // first out-of-flow child: most containers have none)
        var mainArea:Null<Line> = null;
        var crossArea:Null<Line> = null;

        final childCount = tree.childCount(node);
        for (order in 0...childCount) {
            final child = tree.getChildId(node, order);
            final childStyle = tree.getFlexboxChildStyle(child);
            final position = childStyle.position;

            if (childStyle.boxGenerationMode() == BoxGenerationMode.None) {
                continue;
            }
            // In-flow item: merge the candidates bubbled out of its subtree
            if (!position.isOutOfFlow()) {
                if (itemIndex < itemCount && flexItems[itemIndex].order == order) {
                    if (candidates == null)
                        candidates = new OofCandidates();
                    candidates.append(flexItems[itemIndex].oofCandidates);
                    itemIndex++;
                    while (itemIndex < itemCount && flexItems[itemIndex].oofCandidates.isEmpty())
                        itemIndex++;
                }
                continue;
            }

            final alignSelf = resolveNormalAlignment(childStyle.alignSelf != null ? (childStyle.alignSelf : AlignItems) : constants.alignItems)
                .resolveSelfRelative(childStyle.direction, constants.layoutDirection, constants.isColumn);

            // Main-axis static position (justify-content).
            //
            // Stretch is an invalid value for justify_content in the flexbox algorithm, so we
            // treat it as if it wasn't set (and thus we default to FlexStart behaviour).
            // Normal has already been resolved to FlexStart.
            //
            // The `safe` overflow-position keyword is intentionally NOT applied here, even when
            // the abs-positioned item would overflow the main axis: Chrome does not apply safe
            // fallback to `justify-content` on absolutely-positioned flex items (only the
            // cross-axis `align-self` does so). Matching the layout authority over a strict
            // spec read keeps gentest fixtures green; reconsider if Chromium changes behavior.
            final mainEdge = mainStaticEdge(constants.justifyContent.keyword, mainAxisFlexStartReversed, mainIsRtl);
            if (mainArea == null) {
                mainArea = new Line(contentBoxInset.mainStart(dir), containerSize.main(dir) - contentBoxInset.mainEnd(dir));
                crossArea = new Line(contentBoxInset.crossStart(dir), containerSize.cross(dir) - contentBoxInset.crossEnd(dir));
            }

            // Cross-axis static position (align-self).
            final cross = new AxisStaticPosition(
                crossArea,
                new AxisStaticAlign(
                    crossEdgeFor(alignSelf.keyword, crossIsRtl, crossAxisFlexStartReversed),
                    alignSelf.safety,
                    crossEdgeFor(Alignment.resolveSelfAlignmentSafety(alignSelf, true), crossIsRtl, crossAxisFlexStartReversed)
                )
            );
            final main = new AxisStaticPosition(mainArea, AxisStaticAlign.fromKeyword(mainEdge));

            final staticPosition = constants.isRow ? new PointOf<AxisStaticPosition>(main, cross) : new PointOf<AxisStaticPosition>(cross, main);
            if (candidates == null)
                candidates = new OofCandidates();
            candidates.push(new OofCandidate(child, order, position, staticPosition));
        }
        return candidates != null ? candidates : OofCandidates.EMPTY;
    }

    /**
     * Computes the total space taken up by gaps in an axis given:
     *   - The size of each gap
     *   - The number of items (children or flex-lines) between which there are gaps
     */
    static inline function sumAxisGaps(gap:Float, numItems:Int):Float {
        // Gaps only exist between items, so...
        if (numItems <= 1) {
            // ...if there are less than 2 items then there are no gaps
            return 0.0;
        }
        else {
            // ...otherwise there are (num_items - 1) gaps
            return gap * (numItems - 1);
        }
    }

}
