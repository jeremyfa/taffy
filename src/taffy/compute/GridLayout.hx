// Ported from taffy 0.15.0: src/compute/grid/mod.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute;

import taffy.compute.grid.CellOccupancyMatrix;
import taffy.compute.grid.DetailedGridInfo;
import taffy.compute.grid.ExplicitGrid;
import taffy.compute.grid.ExplicitGrid.AutoRepeatStrategy;
import taffy.compute.grid.GenericGridPlacement;
import taffy.compute.grid.GenericGridPlacement.ItemPlacement;
import taffy.compute.grid.GenericGridPlacement.PlacementLine;
import taffy.compute.grid.DetailedGridInfo.DetailedGridTracksInfo;
import taffy.compute.grid.DetailedGridInfo.DetailedGridItemsInfo;
import taffy.compute.grid.GridAlignment;
import taffy.compute.grid.GridCoordinates;
import taffy.compute.grid.GridItem;
import taffy.compute.grid.GridTrack;
import taffy.compute.grid.ImplicitGrid;
import taffy.compute.grid.NamedLineResolver;
import taffy.compute.grid.Placement;
import taffy.compute.grid.TrackCounts;
import taffy.compute.grid.TrackSizing;
import taffy.geometry.AbsoluteAxis;
import taffy.geometry.AbstractAxis;
import taffy.geometry.Line;
import taffy.geometry.LineOf;
import taffy.geometry.Point;
import taffy.geometry.PointOf;
import taffy.geometry.Rect;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.AlignContent;
import taffy.style.AlignItems;
import taffy.style.AvailableSpace;
import taffy.style.Direction;
import taffy.style.Style;
import taffy.tree.AxisStaticPosition;
import taffy.tree.Baselines;
import taffy.tree.Layout;
import taffy.tree.LayoutGridContainer;
import taffy.tree.LayoutInput;
import taffy.tree.LayoutOutput;
import taffy.tree.LayoutPartialTree;
import taffy.tree.NodeId;
import taffy.tree.OofCandidate;
import taffy.tree.OofCandidates;
import taffy.tree.OofPositioningArea;
import taffy.util.MaybeMath;
import taffy.util.Sys;
import taffy.geometry.SizeOpt;
import taffy.util.OptionalFloat;
import taffy.geometry.SizeAvail;

using taffy.geometry.SizeOf;
using taffy.util.Resolve;

/**
 * This module is a partial implementation of the CSS Grid Level 1 specification
 * https://www.w3.org/TR/css-grid-1
 */
class GridLayout {

    static final FALSE_LINE:LineOf<Bool> = new LineOf<Bool>(false, false);

    /**
     * Grid layout algorithm
     * This consists of a few phases:
     *   - Resolving the explicit grid
     *   - Placing items (which also resolves the implicit grid)
     *   - Track (row/column) sizing
     *   - Alignment & Final item placement
     */
    public static function computeGridLayout(tree:LayoutGridContainer, node:NodeId, inputs:LayoutInput):LayoutOutput {
        final knownDimensions = inputs.knownDimensions;
        final runMode = inputs.runMode;
        final parentSize = inputs.parentSize;
        final availableSpace = inputs.availableSpace;

        final style = tree.getGridContainerStyle(node);

        // 1. Resolve the grid container's style against the layout inputs
        final direction = style.direction;
        final contain = style.contain;
        final containingBlockClaims = style.isContainingBlock();

        // Compute "available grid space"
        // https://www.w3.org/TR/css-grid-1/#available-grid-space
        final aspectRatio = style.aspectRatio;
        final padding = style.padding.resolveOrZero(parentSize.width);
        final border = style.border.resolveOrZero(parentSize.width);
        final paddingBorder = padding.add(border);
        final paddingBorderSize = paddingBorder.sumAxes();
        final boxSizingAdjustment = style.boxSizing == ContentBox ? paddingBorderSize : Size.ZERO;

        final minSize = style.minSize.maybeResolve(parentSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);
        final maxSize = style.maxSize.maybeResolve(parentSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);
        final preferredSize = if (inputs.sizingMode == InherentSize) {
            style.size.maybeResolve(parentSize).maybeApplyAspectRatio(style.aspectRatio).maybeAddSize(boxSizingAdjustment);
        }
        else {
            SizeOpt.NONE;
        }

        // Scrollbar gutters are reserved when the `overflow` property is set to `Overflow::Scroll`.
        // However, the axis are switched (transposed) because a node that scrolls vertically needs
        // *horizontal* space to be reserved for a scrollbar
        final scrollbarGutter = new Point(
            style.overflow.y == Scroll ? style.scrollbarWidth : 0.0,
            style.overflow.x == Scroll ? style.scrollbarWidth : 0.0
        );
        final isScrollContainer = style.overflow.x.isScrollContainer() || style.overflow.y.isScrollContainer();
        final contentBoxInset = new Rect(
            paddingBorder.left + (direction.isRtl() ? scrollbarGutter.x : 0.0),
            paddingBorder.right + (direction.isRtl() ? 0.0 : scrollbarGutter.x),
            paddingBorder.top,
            paddingBorder.bottom + scrollbarGutter.y
        );

        // `normal` behaves as `stretch` for grid containers
        final alignContent = style.gridAlignContent(Block);
        final justifyContent = style.gridAlignContent(Inline);
        final alignItems = style.alignItems;
        final justifyItems = style.justifyItems;
        final knownOrPreferred = knownDimensions.or(preferredSize);
        final constrainedAvailableSpace = availableSpace.maybeSet(knownOrPreferred)
            .maybeClamp(minSize, maxSize)
            .maybeMaxSize(paddingBorderSize);

        final availableGridSpace = new SizeAvail(
            AvailableSpaceTools.mapDefiniteValue(constrainedAvailableSpace.width, space -> space - contentBoxInset.horizontalAxisSum()),
            AvailableSpaceTools.mapDefiniteValue(constrainedAvailableSpace.height, space -> space - contentBoxInset.verticalAxisSum())
        );

        final outerNodeSize = knownOrPreferred.maybeClamp(minSize, maxSize).maybeMaxSize(paddingBorderSize);

        // The track sizing algorithm operates on the grid container's content box, so the min/max sizes
        // (which are border-box sizes) need converting to content-box sizes before being passed to it
        final innerMinSize = minSize.maybeSubSize(contentBoxInset.sumAxes());
        final innerMaxSize = maxSize.maybeSubSize(contentBoxInset.sumAxes());
        var innerNodeSize = new SizeOpt(
            outerNodeSize.width.isSome() ? OptionalFloat.some(outerNodeSize.width.unwrap() - contentBoxInset.horizontalAxisSum()) : OptionalFloat.NONE,
            outerNodeSize.height.isSome() ? OptionalFloat.some(outerNodeSize.height.unwrap() - contentBoxInset.verticalAxisSum()) : OptionalFloat.NONE
        );

        // Short-circuit layout if the container's size is fully determined by the container's size and the run mode
        // is ComputeSize (and thus the container's size is all that we're interested in)
        if (runMode == ComputeSize) {
            if (outerNodeSize.width.isSome() && outerNodeSize.height.isSome())
                return LayoutOutput.fromOuterSize(new Size(outerNodeSize.width.unwrap(), outerNodeSize.height.unwrap()));

            // We can also short-circuit if the width is known and only the width has been requested.
            if (inputs.axis == Horizontal && outerNodeSize.width.isSome())
                return LayoutOutput.fromOuterSize(new Size(outerNodeSize.width.unwrap(), 0.0));
        }

        // 2. Resolve the explicit grid

        // This is very similar to the inner_node_size except if the inner_node_size is not definite but the node
        // has a min- or max- size style then that will be used in it's place.
        final autoFitContainerSize = outerNodeSize.or(maxSize)
            .or(minSize)
            .maybeClamp(minSize, maxSize)
            .maybeMaxSize(paddingBorderSize)
            .maybeSubSize(contentBoxInset.sumAxes());

        // If the grid container has a definite size or max size in the relevant axis:
        //   - then the number of repetitions is the largest possible positive integer that does not cause the grid to overflow the content
        //     box of its grid container.
        // Otherwise, if the grid container has a definite min size in the relevant axis:
        //   - then the number of repetitions is the smallest possible positive integer that fulfills that minimum requirement
        // Otherwise, the specified track list repeats only once.
        final autoRepeatFitStrategy = outerNodeSize.or(maxSize);
        final widthStrategy:AutoRepeatStrategy = autoRepeatFitStrategy.width.isSome() ? MaxRepetitionsThatDoNotOverflow : MinRepetitionsThatDoOverflow;
        final heightStrategy:AutoRepeatStrategy = autoRepeatFitStrategy.height.isSome() ? MaxRepetitionsThatDoNotOverflow : MinRepetitionsThatDoOverflow;

        // Compute the number of rows and columns in the explicit grid *template*
        // (explicit tracks from grid_areas are computed separately below)
        final colSize = ExplicitGrid.computeExplicitGridSizeInAxis(style, autoFitContainerSize.width, widthStrategy, Horizontal);
        final rowSize = ExplicitGrid.computeExplicitGridSizeInAxis(style, autoFitContainerSize.height, heightStrategy, Vertical);
        final colAutoRepetitionCount = colSize.autoRepetitionCount;
        final gridTemplateColCount = colSize.trackCount;
        final rowAutoRepetitionCount = rowSize.autoRepetitionCount;
        final gridTemplateRowCount = rowSize.trackCount;

        final nameResolver = new NamedLineResolver(style, colAutoRepetitionCount, rowAutoRepetitionCount);

        // Clamp the explicit grid to MAX_GRID_TRACKS tracks in each axis
        // https://www.w3.org/TR/css-grid-1/#overlarge-grids
        final explicitColCount = imin(imax(gridTemplateColCount, nameResolver.areaColumnCount()), GridCoordinates.MAX_GRID_TRACKS);
        final explicitRowCount = imin(imax(gridTemplateRowCount, nameResolver.areaRowCount()), GridCoordinates.MAX_GRID_TRACKS);

        nameResolver.setExplicitColumnCount(explicitColCount);
        nameResolver.setExplicitRowCount(explicitRowCount);

        // Build the per-line names of the explicit grid from the name resolver's collected pairs
        final detailedColumnLineNames = nameResolver.detailedLineNames(Horizontal);
        final detailedRowLineNames = nameResolver.detailedLineNames(Vertical);

        // 3. Create the grid items (in document order) and resolve the named lines in their `grid-row`/`grid-column` styles
        // Absolutely positioned children do not take part in grid placement and do not create implicit tracks,
        // so they are excluded here. Each child's style is read and its named lines resolved exactly once; the
        // results drive both the grid size estimate and item placement below.
        final childCount = tree.childCount(node);
        final items:Array<GridItem> = [];
        final placements:Array<ItemPlacement> = [];
        for (index in 0...childCount) {
            final childNode = tree.getChildId(node, index);
            final childStyle = tree.getGridChildStyle(childNode);
            if (childStyle.boxGenerationMode() == None || childStyle.position.isOutOfFlow())
                continue;
            placements.push(new ItemPlacement(
                PlacementLine.intoOriginZero(nameResolver.resolveColumnNames(childStyle.gridColumn), explicitColCount),
                PlacementLine.intoOriginZero(nameResolver.resolveRowNames(childStyle.gridRow), explicitRowCount)
            ));
            items.push(GridItem.newWithStyleAndOrder(childNode, childStyle, alignItems, justifyItems, index));
        }

        // 4. Implicit Grid: Estimate Track Counts
        // Estimate the number of rows and columns in the implicit grid (= the entire grid)
        // This is necessary as part of placement. Doing it early here is a perf optimisation to reduce allocations.
        final estimate = ImplicitGrid.computeGridSizeEstimate(explicitColCount, explicitRowCount, placements);

        // 5. Grid Item Placement
        // Match items (children) to a definite grid position (row start/end and column start/end position)
        final cellOccupancyMatrix = CellOccupancyMatrix.withTrackCounts(estimate.columns, estimate.rows);
        // `items` is in document order from here on (placement only fills in each item's grid area). The track
        // sizing and baseline passes sort references to the items rather than the items themselves.
        Placement.placeGridItems(cellOccupancyMatrix, items, placements, style.gridAutoFlow);

        // Extract track counts from previous step (auto-placement can expand the number of tracks)
        final finalColCounts = cellOccupancyMatrix.trackCounts(Horizontal).clone();
        final finalRowCounts = cellOccupancyMatrix.trackCounts(Vertical).clone();

        // 5. Initialize Tracks
        // Initialize (explicit and implicit) grid tracks (and gutters)
        // This resolves the min and max track sizing functions for all tracks and gutters
        final columns:Array<GridTrack> = [];
        final rows:Array<GridTrack> = [];
        ExplicitGrid.initializeGridTracks(columns, finalColCounts, style, Horizontal, colAutoRepetitionCount, cellOccupancyMatrix);
        ExplicitGrid.initializeGridTracks(rows, finalRowCounts, style, Vertical, rowAutoRepetitionCount, cellOccupancyMatrix);

        // 6. Track Sizing

        // Convert grid placements in origin-zero coordinates to indexes into the GridTrack (rows and columns) vectors
        // This computation is relatively trivial, but it requires the final number of negative (implicit) tracks in
        // each axis, and doing it up-front here means we don't have to keep repeating that calculation
        TrackSizing.resolveItemTrackIndexes(items, finalColCounts, finalRowCounts);
        // For each item, and in each axis, determine whether the item crosses any flexible (fr) tracks
        // Record this as a boolean (per-axis) on each item for later use in the track-sizing algorithm
        TrackSizing.determineIfItemCrossesFlexibleOrIntrinsicTracks(items, columns, rows);

        // Determine if the grid has any baseline aligned items
        var hasBaselineAlignedItem = false;
        for (item in items) {
            if (item.participatesInBaselineAlignment()) {
                hasBaselineAlignedItem = true;
                break;
            }
        }

        // Run track sizing algorithm for Inline axis
        TrackSizing.trackSizingAlgorithm(tree, Inline, innerMinSize.get(Inline), innerMaxSize.get(Inline), justifyContent, alignContent,
            availableGridSpace, innerNodeSize, columns, rows, items, GridItem.ESTIMATE_MAX_TRACK_DEFINITE_VALUE, hasBaselineAlignedItem);
        final initialColumnSum = sumBaseSizes(columns);
        if (innerNodeSize.width.isNone())
            innerNodeSize = innerNodeSize.withWidth(OptionalFloat.some(initialColumnSum));

        // If only the container's width has been requested then we can skip sizing the rows entirely (which avoids
        // measuring the height of every item), as column sizing is not re-run when only computing the container's size.
        // Note: the short-circuit above has already handled the case where the container's width is known.
        if (runMode == ComputeSize && inputs.axis == Horizontal) {
            final width = Sys.f32Max(MaybeMath.maybeClampF(initialColumnSum + contentBoxInset.horizontalAxisSum(), minSize.width, maxSize.width),
                paddingBorderSize.width);
            return LayoutOutput.fromOuterSize(new Size(width, 0.0));
        }

        for (item in items)
            item.gridAreaSizeCache = null;

        // Run track sizing algorithm for Block axis
        TrackSizing.trackSizingAlgorithm(tree, Block, innerMinSize.get(Block), innerMaxSize.get(Block), alignContent, justifyContent,
            availableGridSpace, innerNodeSize, rows, columns, items, GridItem.ESTIMATE_BASE_SIZE, false // TODO: Support baseline alignment in the vertical axis
        );
        final initialRowSum = sumBaseSizes(rows);

        // 6. Compute container size
        final resolvedStyleSize = knownOrPreferred;
        var containerBorderBoxWidth = Sys.f32Max(MaybeMath.maybeClampF(resolvedStyleSize.width.isSome() ? resolvedStyleSize.width.unwrap() : initialColumnSum
            + contentBoxInset.horizontalAxisSum(), minSize.width, maxSize.width), paddingBorderSize.width);
        var containerBorderBoxHeight = Sys.f32Max(MaybeMath.maybeClampF(resolvedStyleSize.height.isSome() ? resolvedStyleSize.height.unwrap() : initialRowSum
            + contentBoxInset.verticalAxisSum(), minSize.height, maxSize.height), paddingBorderSize.height);
        var containerContentBoxWidth = Sys.f32Max(0.0, containerBorderBoxWidth - contentBoxInset.horizontalAxisSum());
        var containerContentBoxHeight = Sys.f32Max(0.0, containerBorderBoxHeight - contentBoxInset.verticalAxisSum());

        // If only the container's size has been requested
        if (runMode == ComputeSize)
            return LayoutOutput.fromOuterSize(new Size(containerBorderBoxWidth, containerBorderBoxHeight));

        // The container's size is now determined, so percentages resolve against its content box when re-running track sizing.
        // This may be a no-op if the container's size was known upfront (in which case it already equals `inner_node_size`).
        innerNodeSize = new SizeOpt(OptionalFloat.some(containerContentBoxWidth), OptionalFloat.some(containerContentBoxHeight));

        // Column sizing must be re-run (once) if:
        //   - The grid container's width was initially indefinite and there are any columns with percentage track sizing functions
        //   - Any grid item crossing an intrinsically sized track's min content contribution width has changed
        // TODO: Only rerun sizing for tracks that actually require it rather than for all tracks if any need it.
        var rerunColumnSizing = false;
        var intrinsicColumnContributionChanged = false;

        final hasPercentageColumn = anyTrackUsesPercentage(columns);
        final hasPercentageRow = anyTrackUsesPercentage(rows);
        final parentWidthIndefinite = outerNodeSize.width.isNone();
        rerunColumnSizing = parentWidthIndefinite && hasPercentageColumn;

        if (!rerunColumnSizing) {
            // Note: every item must be visited (no short-circuiting) as the loop updates each item's caches
            for (item in items) {
                if (!item.crossesIntrinsicColumn)
                    continue;
                final gridAreaSize = item.gridAreaSize(Inline, columns, rows, innerNodeSize, GridItem.ESTIMATE_BASE_SIZE);
                final itemAvailableSpace = gridAreaSize.with(Inline, OptionalFloat.NONE);
                final newMinContentContribution = item.minContentContribution(Inline, tree, gridAreaSize, itemAvailableSpace);

                final hasChanged = item.minContentContributionCacheWidth.isNone() || newMinContentContribution != item.minContentContributionCacheWidth.unwrap();

                item.gridAreaSizeCache = gridAreaSize;
                item.minContentContributionCacheWidth = OptionalFloat.some(newMinContentContribution);
                item.maxContentContributionCacheWidth = OptionalFloat.NONE;
                item.minimumContributionCacheWidth = OptionalFloat.NONE;

                if (hasChanged)
                    intrinsicColumnContributionChanged = true;
            }
            rerunColumnSizing = intrinsicColumnContributionChanged;
        }
        else {
            // Clear intrinsic width caches
            for (item in items) {
                item.gridAreaSizeCache = null;
                item.minContentContributionCacheWidth = OptionalFloat.NONE;
                item.maxContentContributionCacheWidth = OptionalFloat.NONE;
                item.minimumContributionCacheWidth = OptionalFloat.NONE;
            }
        }

        // Row sizing must be re-run (once) if:
        //   - The grid container's height was initially indefinite and there are any rows with percentage track sizing functions
        //   - Column sizing was re-run and any grid item crossing an intrinsically sized track's min content contribution height has changed
        // TODO: Only rerun sizing for tracks that actually require it rather than for all tracks if any need it.
        final parentHeightIndefinite = outerNodeSize.height.isNone();
        var rerunRowSizing = parentHeightIndefinite && hasPercentageRow;
        var intrinsicRowContributionChanged = false;

        if (rerunRowSizing) {
            // Clear intrinsic height caches
            for (item in items) {
                item.gridAreaSizeCache = null;
                item.minContentContributionCacheHeight = OptionalFloat.NONE;
                item.maxContentContributionCacheHeight = OptionalFloat.NONE;
                item.minimumContributionCacheHeight = OptionalFloat.NONE;
            }
        }

        if (rerunColumnSizing) {
            // Re-run track sizing algorithm for Inline axis
            TrackSizing.trackSizingAlgorithm(tree, Inline, innerMinSize.get(Inline), innerMaxSize.get(Inline), justifyContent, alignContent,
                availableGridSpace, innerNodeSize, columns, rows, items, GridItem.ESTIMATE_BASE_SIZE, hasBaselineAlignedItem);

            // The column widths may have changed, so the items' intrinsic height contributions need to be recomputed
            // (unless row sizing is being re-run anyway, in which case the caches have already been cleared).
            if (!rerunRowSizing) {
                // Note: every item must be visited (no short-circuiting) as the loop updates each item's caches
                for (item in items) {
                    if (!item.crossesIntrinsicRow)
                        continue;
                    final gridAreaSize = item.gridAreaSize(Block, rows, columns, innerNodeSize, GridItem.ESTIMATE_BASE_SIZE);
                    final itemAvailableSpace = gridAreaSize.with(Block, OptionalFloat.NONE);
                    final newMinContentContribution = item.minContentContribution(Block, tree, gridAreaSize, itemAvailableSpace);

                    final hasChanged = item.minContentContributionCacheHeight.isNone()
                        || newMinContentContribution != item.minContentContributionCacheHeight.unwrap();

                    item.gridAreaSizeCache = gridAreaSize;
                    item.minContentContributionCacheHeight = OptionalFloat.some(newMinContentContribution);
                    item.maxContentContributionCacheHeight = OptionalFloat.NONE;
                    item.minimumContributionCacheHeight = OptionalFloat.NONE;

                    if (hasChanged)
                        intrinsicRowContributionChanged = true;
                }
                rerunRowSizing = intrinsicRowContributionChanged;
            }
        }

        if (rerunRowSizing) {
            // Re-run track sizing algorithm for Block axis
            TrackSizing.trackSizingAlgorithm(tree, Block, innerMinSize.get(Block), innerMaxSize.get(Block), alignContent, justifyContent,
                availableGridSpace, innerNodeSize, rows, columns, items, GridItem.ESTIMATE_BASE_SIZE, false // TODO: Support baseline alignment in the vertical axis
            );
        }

        if ((intrinsicColumnContributionChanged && !hasPercentageColumn) || (intrinsicRowContributionChanged && !hasPercentageRow)) {
            final finalColumnSum = sumBaseSizes(columns);
            final finalRowSum = sumBaseSizes(rows);

            if (intrinsicColumnContributionChanged && !hasPercentageColumn) {
                containerBorderBoxWidth = Sys.f32Max(MaybeMath.maybeClampF(resolvedStyleSize.width.isSome() ? resolvedStyleSize.width.unwrap() : finalColumnSum
                    + contentBoxInset.horizontalAxisSum(), minSize.width, maxSize.width), paddingBorderSize.width);
                containerContentBoxWidth = Sys.f32Max(0.0, containerBorderBoxWidth - contentBoxInset.horizontalAxisSum());
            }

            if (intrinsicRowContributionChanged && !hasPercentageRow) {
                containerBorderBoxHeight = Sys.f32Max(MaybeMath.maybeClampF(resolvedStyleSize.height.isSome() ? resolvedStyleSize.height.unwrap() : finalRowSum
                    + contentBoxInset.verticalAxisSum(), minSize.height, maxSize.height), paddingBorderSize.height);
                containerContentBoxHeight = Sys.f32Max(0.0, containerBorderBoxHeight - contentBoxInset.verticalAxisSum());
            }
        }

        final containerBorderBox = new Size(containerBorderBoxWidth, containerBorderBoxHeight);

        // If only the container's size has been requested
        if (runMode == ComputeSize)
            return LayoutOutput.fromOuterSize(containerBorderBox);

        // 8. Track Alignment

        // Align columns
        final inlineSizeWithoutScrollbar = Sys.f32Max(containerBorderBox.width - paddingBorderSize.width, 0.0);
        final inlineScrollbarGutterForAlignment = Sys.f32Min(scrollbarGutter.x, inlineSizeWithoutScrollbar);
        GridAlignment.alignTracks(containerContentBoxWidth,
            new Line(padding.left + (direction.isRtl() ? inlineScrollbarGutterForAlignment : 0.0),
                padding.right + (direction.isRtl() ? 0.0 : inlineScrollbarGutterForAlignment)),
            new Line(border.left, border.right), columns, justifyContent, direction.isRtl());
        // Align rows
        GridAlignment.alignTracks(containerContentBoxHeight, new Line(padding.top, padding.bottom), new Line(border.top, border.bottom), rows, alignContent,
            false);

        // 9. Size, Align, and Position Grid Items

        var itemOverflowRect = Rect.ZERO;

        // Out-of-flow candidates in document order: direct out-of-flow children of the grid
        // interleaved with candidates bubbled from in-flow children's subtrees. These are laid out
        // by the out-of-flow positioning pass (`computeOofLayout`), which runs after this algorithm.
        final oofCandidates = new OofCandidates();

        // Position in-flow children (stored in items vector)
        for (index in 0...items.length) {
            final item = items[index];
            // Tracks are stored in logical order. In RTL the physical offsets are assigned
            // right-to-left, so an item's physical left edge is derived from its logical end
            // line and its physical right edge from its logical start line.
            final gridArea = new Rect(
                direction.isRtl() ? columns[item.columnIndexes.end - 1].offset : columns[item.columnIndexes.start + 1].offset,
                direction.isRtl() ? columns[item.columnIndexes.start].offset : columns[item.columnIndexes.end].offset,
                rows[item.rowIndexes.start + 1].offset,
                rows[item.rowIndexes.end].offset
            );
            final result = GridAlignment.alignAndPositionItem(tree, item.node, index, gridArea,
                new Size(gridArea.right - gridArea.left, gridArea.bottom - gridArea.top), justifyItems, alignItems, item.baselineShim, direction,
                containerBorderBox.width, border, isScrollContainer, item.oofCandidates);
            item.yPosition = result.yPosition;
            item.height = result.height;

            itemOverflowRect = itemOverflowRect.union(result.overflowContribution);
        }

        // Position hidden and absolutely positioned children, merging in the candidates bubbled out
        // of in-flow children's subtrees (`items` is sorted by `sourceOrder`, i.e. child index)
        var order = items.length;
        var inFlowIndex = 0;
        for (index in 0...tree.childCount(node)) {
            if (inFlowIndex < items.length && items[inFlowIndex].sourceOrder == index) {
                oofCandidates.append(items[inFlowIndex].oofCandidates);
                inFlowIndex++;
                continue;
            }

            final child = tree.getChildId(node, index);
            final childStyle = tree.getGridChildStyle(child);

            // Position hidden child
            if (childStyle.boxGenerationMode() == None) {
                tree.setUnroundedLayout(child, Layout.withOrder(order));
                LayoutPartialTreeExt.performChildLayout(tree, child, SizeOpt.NONE, SizeOpt.NONE, SizeAvail.MAX_CONTENT,
                    InherentSize, FALSE_LINE);
                order++;
                continue;
            }

            // Emit out-of-flow children as candidates for the out-of-flow positioning pass
            // (`computeOofLayout`), which lays out those for which this grid is the containing
            // block after this algorithm has run (resolving their grid areas from the detailed grid
            // info recorded below).
            if (childStyle.position.isOutOfFlow()) {
                final position = childStyle.position;
                final itemDirection = childStyle.direction;
                final justifySelf = (childStyle.justifySelf != null ? (childStyle.justifySelf : AlignItems) : justifyItems).resolveSelfRelative(itemDirection,
                    direction, true);
                final alignSelf = (childStyle.alignSelf != null ? (childStyle.alignSelf : AlignItems) : alignItems).resolveSelfRelative(itemDirection,
                    direction, false);

                // The static-position rectangle: the grid area determined by the grid-placement
                // properties when this grid is the child's containing block, and otherwise the
                // grid's content box, as if the child were the sole grid item in a grid area
                // coinciding with the grid's content edges (grid placement does not apply when the
                // grid is not the containing block).
                // https://www.w3.org/TR/css-grid-1/#static-position
                final area = if (containingBlockClaims.forPosition(position)) {
                    resolveStaticPositionGridArea(childStyle, nameResolver, finalRowCounts, finalColCounts, rows, columns, direction, border,
                        scrollbarGutter, containerBorderBox);
                }
                else {
                    new Rect(
                        border.left + padding.left + (direction.isRtl() ? scrollbarGutter.x : 0.0),
                        containerBorderBox.width - border.right - padding.right - (direction.isRtl() ? 0.0 : scrollbarGutter.x),
                        border.top + padding.top,
                        containerBorderBox.height - border.bottom - padding.bottom - scrollbarGutter.y
                    );
                }

                oofCandidates.push(new OofCandidate(child, order, position, new PointOf<AxisStaticPosition>(
                    AxisStaticPosition.fromAlignment(justifySelf, new Line(area.left, area.right), direction.isRtl()),
                    AxisStaticPosition.fromAlignment(alignSelf, new Line(area.top, area.bottom), false)
                )));

                order++;
            }
        }

        final absolutePositionInset = border.add(new Rect(
            direction.isRtl() ? scrollbarGutter.x : 0.0,
            direction.isRtl() ? 0.0 : scrollbarGutter.x,
            0.0,
            scrollbarGutter.y
        ));
        final absolutePositionArea = containerBorderBox.sub(absolutePositionInset.sumAxes());
        final absolutePositionOffset = new Point(absolutePositionInset.left, absolutePositionInset.top);
        // Store the detailed grid info before the out-of-flow positioning pass so that the pass can
        // resolve the grid areas of out-of-flow boxes whose containing block is this grid
        final areas = nameResolver.populateDetailedLineResolvers(detailedRowLineNames, detailedColumnLineNames);
        tree.setDetailedGridInfo(node, new DetailedGridInfo(
            DetailedGridTracksInfo.fromGridTracksAndTrackCount(finalRowCounts, rows, detailedRowLineNames),
            DetailedGridTracksInfo.fromGridTracksAndTrackCount(finalColCounts, columns, detailedColumnLineNames),
            [for (item in items) DetailedGridItemsInfo.fromGridItem(item)],
            areas
        ));

        final oofPositioningArea = new OofPositioningArea(absolutePositionArea, absolutePositionOffset);

        // If there are no in-flow items then return the container size and the overflow (no baseline)
        if (items.length == 0) {
            var overflowRect = itemOverflowRect;
            if (isScrollContainer)
                overflowRect = new Rect(overflowRect.left, overflowRect.right + (direction.isRtl() ? padding.left : padding.right), overflowRect.top,
                    overflowRect.bottom + padding.bottom);
            final output = LayoutOutput.fromSizes(containerBorderBox, overflowRect);
            output.oofCandidates = oofCandidates;
            output.oofPositioningArea = oofPositioningArea;
            return output;
        }

        // Determine the grid container baseline(s) (currently we only compute the first baseline)
        // Layout containment suppresses the box's baseline for baseline-alignment purposes
        final gridContainerBaseline:OptionalFloat = if (contain.suppressesBaseline()) {
            OptionalFloat.NONE;
        }
        else {
            // Get the row index of the first row containing items
            var firstRow = items[0].rowIndexes.start;
            for (item in items) {
                if (item.rowIndexes.start < firstRow)
                    firstRow = item.rowIndexes.start;
            }

            // Check if any items in *this row* participate in baseline alignment
            // (items with an auto block-axis margin do not participate: https://www.w3.org/TR/css-align-3/#baseline-align-self)
            var firstItem:Null<GridItem> = null;
            var baselineItem:Null<GridItem> = null;
            for (item in items) {
                if (item.rowIndexes.start != firstRow)
                    continue;
                if (firstItem == null)
                    firstItem = item;
                if (item.participatesInBaselineAlignment()) {
                    baselineItem = item;
                    break;
                }
            }
            final item = baselineItem != null ? baselineItem : firstItem;

            OptionalFloat.some(item.yPosition + (item.baseline.isSome() ? item.baseline.unwrap() : item.height));
        }

        // A scroll container's own padding at the end of the content is part of its scrollable
        // overflow region, so it is included in the in-flow overflow rect. Boxes that are not
        // scroll containers do not extend their overflow region by their own padding.
        var scrollableOverflowRect = itemOverflowRect;
        if (isScrollContainer)
            scrollableOverflowRect = new Rect(scrollableOverflowRect.left, scrollableOverflowRect.right + (direction.isRtl() ? padding.left : padding.right),
                scrollableOverflowRect.top, scrollableOverflowRect.bottom + padding.bottom);

        final output = LayoutOutput.fromSizesAndBaselines(containerBorderBox, scrollableOverflowRect, Baselines.fromFirst(gridContainerBaseline));
        output.oofCandidates = oofCandidates;
        output.oofPositioningArea = oofPositioningArea;
        return output;
    }

    static inline function sumBaseSizes(tracks:Array<GridTrack>):Float {
        var sum = 0.0;
        for (track in tracks)
            sum += track.baseSize;
        return sum;
    }

    static inline function anyTrackUsesPercentage(tracks:Array<GridTrack>):Bool {
        var result = false;
        for (track in tracks) {
            if (track.usesPercentage()) {
                result = true;
                break;
            }
        }
        return result;
    }

    static inline function imin(a:Int, b:Int):Int {
        return a < b ? a : b;
    }

    static inline function imax(a:Int, b:Int):Int {
        return a > b ? a : b;
    }

    /**
     * Resolve the static-position rectangle (the grid area determined by the grid-placement
     * properties) for an out-of-flow child of a positioned grid container.
     *
     * Content alignment (align-content/justify-content) may distribute free space before, between,
     * or after tracks. Grid lines used by absolutely positioned items resolve to the edges of the
     * tracks adjacent to the line rather than to the raw gutter offset:
     *   - As a start edge, a line resolves to the start of the track that follows it
     *   - As an end edge, a line resolves to the end of the track that precedes it
     */
    static function resolveStaticPositionGridArea(childStyle:Style, nameResolver:NamedLineResolver, finalRowCounts:TrackCounts,
            finalColCounts:TrackCounts, rows:Array<GridTrack>, columns:Array<GridTrack>, direction:Direction, border:Rect, scrollbarGutter:Point,
            containerBorderBox:Size):Rect {
        // Convert grid-col-{start/end} into Option's of indexes into the columns vector
        // The Option is None if the style property is Auto and an unresolvable Span
        final colLines = PlacementLine.resolveAbsolutelyPositionedGridTracks(PlacementLine.intoOriginZero(nameResolver.resolveColumnNames(childStyle.gridColumn),
            finalColCounts.explicit));
        final colStart = toTrackVecIndex(colLines.start, finalColCounts);
        final colEnd = toTrackVecIndex(colLines.end, finalColCounts);
        // Convert grid-row-{start/end} into Option's of indexes into the row vector
        // The Option is None if the style property is Auto and an unresolvable Span
        final rowLines = PlacementLine.resolveAbsolutelyPositionedGridTracks(PlacementLine.intoOriginZero(nameResolver.resolveRowNames(childStyle.gridRow),
            finalRowCounts.explicit));
        final rowStart = toTrackVecIndex(rowLines.start, finalRowCounts);
        final rowEnd = toTrackVecIndex(rowLines.end, finalRowCounts);

        // In RTL the item's physical left edge derives from its logical end line and its
        // physical right edge from its logical start line.
        var gridAreaLeft:Float;
        var gridAreaRight:Float;
        if (direction.isRtl()) {
            gridAreaLeft = colEnd >= 0 ? rtlLineAsEndEdge(columns, colEnd) : border.left + scrollbarGutter.x;
            gridAreaRight = colStart >= 0 ? rtlLineAsStartEdge(columns, colStart) : containerBorderBox.width - border.right;
        }
        else {
            gridAreaLeft = colStart >= 0 ? lineAsStartEdge(columns, colStart) : border.left;
            gridAreaRight = colEnd >= 0 ? lineAsEndEdge(columns, colEnd) : containerBorderBox.width - border.right - scrollbarGutter.x;
        }

        return new Rect(
            gridAreaLeft,
            gridAreaRight,
            rowStart >= 0 ? lineAsStartEdge(rows, rowStart) : border.top,
            rowEnd >= 0 ? lineAsEndEdge(rows, rowEnd) : containerBorderBox.height - border.bottom - scrollbarGutter.y
        );
    }

    /** Convert an optional OriginZero line into a GridTrack array index (-1 if null or outside the grid) */
    static inline function toTrackVecIndex(line:Null<Int>, counts:TrackCounts):Int {
        return line == null ? -1 : GridCoordinates.tryIntoTrackVecIndex(line, counts);
    }

    /** Resolve a grid line (by track vector index) used as a start edge to a position */
    static inline function lineAsStartEdge(tracks:Array<GridTrack>, index:Int):Float {
        return (index + 1 < tracks.length ? tracks[index + 1] : tracks[index]).offset;
    }

    /** Resolve a grid line (by track vector index) used as an end edge to a position */
    static inline function lineAsEndEdge(tracks:Array<GridTrack>, index:Int):Float {
        return index == 0 ? (1 < tracks.length ? tracks[1] : tracks[0]).offset : tracks[index].offset;
    }

    // In RTL, tracks remain in logical order but physical offsets are assigned
    // right-to-left: a line used as an inline-start edge resolves to the physical
    // *right* edge of the track that follows it (its gutter's offset), and a line
    // used as an inline-end edge resolves to the physical *left* edge (offset) of
    // the track that precedes it.

    /** Resolve a grid line used as an inline-start edge to a physical right x-position (RTL) */
    static function rtlLineAsStartEdge(tracks:Array<GridTrack>, index:Int):Float {
        if (tracks.length > index + 1) {
            // The gutter's offset is the physical right edge of the track that follows the line
            return tracks[index].offset;
        }
        else if (index == 0) {
            return tracks[0].offset;
        }
        else {
            // No track follows the line: resolve to the line itself, which is the physical
            // left edge of the track that precedes it (the trailing gutter is assigned its
            // offset before any alignment offset is applied, so it cannot be used here)
            return tracks[index - 1].offset;
        }
    }

    /** Resolve a grid line used as an inline-end edge to a physical left x-position (RTL) */
    static inline function rtlLineAsEndEdge(tracks:Array<GridTrack>, index:Int):Float {
        return index == 0 ? tracks[0].offset : tracks[index - 1].offset;
    }

}
