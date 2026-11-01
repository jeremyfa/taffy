// Ported from taffy 0.15.0: src/compute/grid/placement.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.grid;

import taffy.compute.grid.GridCoordinates.IntLine;
import taffy.compute.grid.GenericGridPlacement.ItemPlacement;
import taffy.compute.grid.GenericGridPlacement.PlacementLine;
import taffy.compute.grid.CellOccupancyMatrix.CellOccupancyState;

import taffy.geometry.AbsoluteAxis;
import taffy.style.GridAutoFlow;

/**
 * Implements placing items in the grid and resolving the implicit grid.
 * https://www.w3.org/TR/css-grid-1/#placement
 */
class Placement {

    /** Advances the cursor by one track. */
    public static inline function advancePosition(position:Int):Int {
        return position < GridCoordinates.I16_MAX ? position + 1 : position;
    }

    /** Resolves an indefinite span starting at `position`. */
    public static inline function resolveIndefiniteGridSpan(position:Int, span:Int):IntLine {
        return new IntLine(clampI16(position), clampI16(position + span));
    }

    static inline function clampI16(value:Int):Int {
        return value < GridCoordinates.I16_MIN ? GridCoordinates.I16_MIN : (value > GridCoordinates.I16_MAX ? GridCoordinates.I16_MAX : value);
    }

    /**
     * 8.5. Grid Item Placement Algorithm
     * Place items into the grid, generating new rows/column into the implicit grid as required
     *
     * `items` and `placements` are parallel arrays in document order: `placements[i]` holds the `grid-row`/`grid-column`
     * styles of `items[i]`, with named lines already resolved.
     *
     * Specification: https://www.w3.org/TR/css-grid-2/#auto-placement-algo
     */
    public static function placeGridItems(cellOccupancyMatrix:CellOccupancyMatrix, items:Array<GridItem>, placements:Array<ItemPlacement>,
            gridAutoFlow:GridAutoFlow):Void {
        final primaryAxis = gridAutoFlow.primaryAxis();
        final secondaryAxis = primaryAxis.otherAxis();

        // 1. Place children with definite positions
        for (i in 0...items.length) {
            final item = items[i];
            final placement = placements[i];
            if (!(PlacementLine.isDefinite(placement.horizontal) && PlacementLine.isDefinite(placement.vertical)))
                continue;

            // Resolve spans to tracks
            final primarySpan = PlacementLine.resolveDefiniteGridLines(placement.get(primaryAxis));
            final secondarySpan = PlacementLine.resolveDefiniteGridLines(placement.get(primaryAxis.otherAxis()));
            recordGridPlacement(cellOccupancyMatrix, item, primaryAxis, primarySpan, secondarySpan, DefinitelyPlaced);
        }

        // 2. Place remaining children with definite secondary axis positions
        for (i in 0...items.length) {
            final item = items[i];
            final placement = placements[i];
            if (!(PlacementLine.isDefinite(placement.get(secondaryAxis)) && !PlacementLine.isDefinite(placement.get(primaryAxis))))
                continue;

            placeDefiniteSecondaryAxisItem(cellOccupancyMatrix, placement, gridAutoFlow);
            recordGridPlacement(cellOccupancyMatrix, item, primaryAxis, resultPrimary, resultSecondary, AutoPlaced);
        }

        // 3. Determine the number of columns in the implicit grid
        // By the time we get to this point in the execution, this is actually already accounted for:
        //
        // 3.1 Start with the columns from the explicit grid
        //        => Handled by grid size estimate which is used to pre-size the GridOccupancyMatrix
        //
        // 3.2 Among all the items with a definite column position (explicitly positioned items, items positioned in the previous step,
        //     and items not yet positioned but with a definite column) add columns to the beginning and end of the implicit grid as necessary
        //     to accommodate those items.
        //        => Handled by expand_to_fit_range which expands the GridOccupancyMatrix as necessary
        //            -> Called by mark_area_as
        //            -> Called by record_grid_placement
        //
        // 3.3 If the largest column span among all the items without a definite column position is larger than the width of
        //     the implicit grid, add columns to the end of the implicit grid to accommodate that column span.
        //        => Handled by grid size estimate which is used to pre-size the GridOccupancyMatrix

        // 4. Position the remaining grid items
        // (which either have definite position only in the secondary axis or indefinite positions in both axis)
        final primaryAxisGridStartLine = cellOccupancyMatrix.trackCounts(primaryAxis).implicitStartLine();
        final secondaryAxisGridStartLine = cellOccupancyMatrix.trackCounts(secondaryAxis).implicitStartLine();
        var gridPositionPrimary = primaryAxisGridStartLine;
        var gridPositionSecondary = secondaryAxisGridStartLine;
        for (i in 0...items.length) {
            final item = items[i];
            final placement = placements[i];
            if (PlacementLine.isDefinite(placement.get(secondaryAxis)))
                continue;

            // Compute placement
            placeIndefinitelyPositionedItem(cellOccupancyMatrix, placement, gridAutoFlow, gridPositionPrimary, gridPositionSecondary);
            final primarySpan = resultPrimary;
            final secondarySpan = resultSecondary;

            // Record item
            recordGridPlacement(cellOccupancyMatrix, item, primaryAxis, primarySpan, secondarySpan, AutoPlaced);

            // If using the "dense" placement algorithm then reset the grid position back to grid_start_position ready for the next item
            // Otherwise set it to the position of the current item so that the next item it placed after it.
            if (gridAutoFlow.isDense()) {
                gridPositionPrimary = primaryAxisGridStartLine;
                gridPositionSecondary = secondaryAxisGridStartLine;
            }
            else {
                gridPositionPrimary = primarySpan.end;
                gridPositionSecondary = secondarySpan.start;
            }
        }
    }

    /** The primary span result of the last `place*` call (avoids allocating a tuple) */
    static var resultPrimary:IntLine = IntLine.ZERO;

    /** The secondary span result of the last `place*` call (avoids allocating a tuple) */
    static var resultSecondary:IntLine = IntLine.ZERO;

    /**
     * 8.5. Grid Item Placement Algorithm
     * Step 2. Place remaining children with definite secondary axis positions
     * The result is stored in `resultPrimary` / `resultSecondary`.
     */
    static function placeDefiniteSecondaryAxisItem(cellOccupancyMatrix:CellOccupancyMatrix, placement:ItemPlacement, autoFlow:GridAutoFlow):Void {
        final primaryAxis = autoFlow.primaryAxis();
        final secondaryAxis = primaryAxis.otherAxis();
        final primaryAxisGridStartLine = cellOccupancyMatrix.trackCounts(primaryAxis).implicitStartLine();

        final secondaryAxisPlacement = PlacementLine.resolveDefiniteGridLines(placement.get(secondaryAxis));
        final startingPosition = if (autoFlow.isDense()) {
            primaryAxisGridStartLine;
        }
        else {
            final cursor = cellOccupancyMatrix.autoPlacementCursor(primaryAxis, secondaryAxisPlacement.start);
            cursor != null ? (cursor : Int) : primaryAxisGridStartLine;
        }
        final primaryAxisSpan = PlacementLine.indefiniteSpan(placement.get(primaryAxis));

        var position = startingPosition;
        while (true) {
            final primaryAxisPlacement = resolveIndefiniteGridSpan(position, primaryAxisSpan);

            final collision = cellOccupancyMatrix.lineAreaCollisionJump(primaryAxis, primaryAxisPlacement, secondaryAxisPlacement);

            if (collision == null) {
                resultPrimary = primaryAxisPlacement;
                resultSecondary = secondaryAxisPlacement;
                return;
            }
            position = collision;
        }
    }

    /**
     * 8.5. Grid Item Placement Algorithm
     * Step 4. Position the remaining grid items.
     * The result is stored in `resultPrimary` / `resultSecondary`.
     */
    static function placeIndefinitelyPositionedItem(cellOccupancyMatrix:CellOccupancyMatrix, placement:ItemPlacement, autoFlow:GridAutoFlow,
            gridPositionPrimary:Int, gridPositionSecondary:Int):Void {
        final primaryAxis = autoFlow.primaryAxis();
        final secondaryAxis = primaryAxis.otherAxis();

        final primaryPlacementStyle = placement.get(primaryAxis);
        final secondaryPlacementStyle = placement.get(secondaryAxis);

        final secondarySpanCount = PlacementLine.indefiniteSpan(secondaryPlacementStyle);
        final hasDefinitePrimaryAxisPosition = PlacementLine.isDefinite(primaryPlacementStyle);
        final primaryAxisGridStartLine = cellOccupancyMatrix.trackCounts(primaryAxis).implicitStartLine();
        final primaryAxisGridEndLine = cellOccupancyMatrix.trackCounts(primaryAxis).implicitEndLine();
        final secondaryAxisGridStartLine = cellOccupancyMatrix.trackCounts(secondaryAxis).implicitStartLine();

        var primaryIdx = gridPositionPrimary;
        var secondaryIdx = gridPositionSecondary;

        if (hasDefinitePrimaryAxisPosition) {
            final primarySpan = PlacementLine.resolveDefiniteGridLines(primaryPlacementStyle);

            // Compute secondary axis starting position for search
            secondaryIdx = if (autoFlow.isDense()) {
                // If auto-flow is dense then we always search from the first track
                secondaryAxisGridStartLine;
            }
            else {
                primarySpan.start < primaryIdx ? advancePosition(secondaryIdx) : secondaryIdx;
            }

            // Item has fixed primary axis position: so we simply increment the secondary axis position
            // until we find a space that the item fits in
            while (true) {
                final secondarySpan = resolveIndefiniteGridSpan(secondaryIdx, secondarySpanCount);

                // If area is occupied, jump the index past the collision and try again
                final collision = cellOccupancyMatrix.lineAreaCollisionJump(secondaryAxis, secondarySpan, primarySpan);
                if (collision != null) {
                    secondaryIdx = collision;
                    continue;
                }

                // Once we find a free space, return that position
                resultPrimary = primarySpan;
                resultSecondary = secondarySpan;
                return;
            }
        }
        else {
            final primarySpanCount = PlacementLine.indefiniteSpan(primaryPlacementStyle);

            // Whether the item spans every track in the primary axis. Such an item can only be
            // placed at the primary axis grid start, in a stripe of entirely unoccupied tracks.
            final spansAllPrimaryTracks = primarySpanCount >= cellOccupancyMatrix.trackCounts(primaryAxis).len();

            // Item does not have any fixed axis, so we search along the primary axis until we hit the end of the already
            // existent tracks, and then we reset the primary axis back to zero and increment the secondary axis index.
            // We continue in this vein until we find a space that the item fits in.
            while (true) {
                final primarySpan = resolveIndefiniteGridSpan(primaryIdx, primarySpanCount);
                final secondarySpan = resolveIndefiniteGridSpan(secondaryIdx, secondarySpanCount);

                // If the primary index is out of bounds, then increment the secondary index and reset the primary
                // index back to the start of the grid
                final primaryOutOfBounds = primarySpan.end > primaryAxisGridEndLine;
                if (primaryOutOfBounds) {
                    // If the span is out of bounds even at the search start position then it can never fit,
                    // as searching only ever moves the span further away from the start of the grid. Bail out
                    // and let `recordGridPlacement` clamp the placement into the limited grid
                    if (primaryIdx == primaryAxisGridStartLine) {
                        resultPrimary = primarySpan;
                        resultSecondary = secondarySpan;
                        return;
                    }
                    secondaryIdx = advancePosition(secondaryIdx);
                    primaryIdx = primaryAxisGridStartLine;
                    continue;
                }

                // If the item spans every primary axis track, it fits if and only if all of the
                // secondary axis tracks it spans are entirely unoccupied. Jump the secondary index
                // past any non-empty tracks in the spanned stripe.
                if (spansAllPrimaryTracks) {
                    final nextPosition = cellOccupancyMatrix.occupiedTrackJump(secondaryAxis, secondarySpan);
                    if (nextPosition != null) {
                        secondaryIdx = nextPosition;
                        primaryIdx = primaryAxisGridStartLine;
                        continue;
                    }
                    resultPrimary = primarySpan;
                    resultSecondary = secondarySpan;
                    return;
                }

                // If area is occupied, jump the primary index past the collision and try again
                final collision = cellOccupancyMatrix.lineAreaCollisionJump(primaryAxis, primarySpan, secondarySpan);
                if (collision != null) {
                    primaryIdx = collision;
                    continue;
                }

                // Once we find a free space that's in bounds, return that position
                resultPrimary = primarySpan;
                resultSecondary = secondarySpan;
                return;
            }
        }
    }

    /**
     * Clamp a placement into the limited grid, preserving a span of at least 1 track.
     * Items placed outside of the limited grid are clamped into it.
     *
     * See: https://www.w3.org/TR/css-grid-1/#overlarge-grids
     */
    public static function clampSpanToLimitedGrid(span:IntLine):IntLine {
        final s = span.start;
        final start = s < GridCoordinates.MIN_OZ_LINE ? GridCoordinates.MIN_OZ_LINE : (s > GridCoordinates.MAX_OZ_LINE - 1 ? GridCoordinates.MAX_OZ_LINE - 1 : s);
        final e = span.end;
        final end = e < start + 1 ? start + 1 : (e > GridCoordinates.MAX_OZ_LINE ? GridCoordinates.MAX_OZ_LINE : e);
        return (start == s && end == e) ? span : new IntLine(start, end);
    }

    /**
     * Record the grid item's placement in both the CellOccupancyMatrix and the item itself
     * once a definite placement has been determined
     */
    static function recordGridPlacement(cellOccupancyMatrix:CellOccupancyMatrix, item:GridItem, primaryAxis:AbsoluteAxis, primarySpan:IntLine,
            secondarySpan:IntLine, placementType:CellOccupancyState):Void {
        // Clamp placements into the limited grid to prevent arithmetic overflow when growing the
        // implicit grid (https://www.w3.org/TR/css-grid-1/#overlarge-grids)
        final primary = clampSpanToLimitedGrid(primarySpan);
        final secondary = clampSpanToLimitedGrid(secondarySpan);

        // Mark area of grid as occupied
        cellOccupancyMatrix.markAreaAs(primaryAxis, primary, secondary, placementType);

        // Record placement on the item
        if (primaryAxis == Horizontal) {
            item.column = primary;
            item.row = secondary;
        }
        else {
            item.column = secondary;
            item.row = primary;
        }
    }

}
