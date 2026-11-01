// Ported from taffy 0.15.0: src/compute/grid/implicit_grid.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.grid;

import taffy.compute.grid.GenericGridPlacement.ItemPlacement;
import taffy.compute.grid.GenericGridPlacement.PlacementLine;

import taffy.geometry.LineOf;

/**
 * The estimated track counts in both axes (result of `ImplicitGrid.computeGridSizeEstimate`)
 */
class GridSizeEstimate {

    /** The estimated column counts */
    public final columns:TrackCounts;

    /** The estimated row counts */
    public final rows:TrackCounts;

    public inline function new(columns:TrackCounts, rows:TrackCounts) {
        this.columns = columns;
        this.rows = rows;
    }

}

/**
 * This module is not required for spec compliance, but is used as a performance optimisation
 * to reduce the number of allocations required when creating a grid.
 */
class ImplicitGrid {

    /**
     * Estimate the number of rows and columns in the grid
     * This is used as a performance optimisation to pre-size vectors and reduce allocations. It also forms a necessary step
     * in the auto-placement
     *   - The estimates for the explicit and negative implicit track counts are exact.
     *   - However, the estimates for the positive explicit track count is a lower bound as auto-placement can affect this
     *     in ways which are impossible to predict until the auto-placement algorithm is run.
     *
     * Note that this function internally mixes use of grid track numbers and grid line numbers
     */
    public static function computeGridSizeEstimate(explicitColCount:Int, explicitRowCount:Int, placements:Array<ItemPlacement>):GridSizeEstimate {
        // Iterate over children, producing an estimate of the min and max grid lines (in origin-zero coordinates where)
        // along with the span of each item
        var colMin = 0;
        var colMax = 0;
        var colMaxSpan = 0;
        var rowMin = 0;
        var rowMax = 0;
        var rowMaxSpan = 0;
        for (placement in placements) {
            // Note: that the children reference the lines in between (and around) the tracks not tracks themselves,
            // and thus we must subtract 1 to get an accurate estimate of the number of tracks
            final col = childMinLineMaxLineSpan(placement.horizontal);
            final row = childMinLineMaxLineSpan(placement.vertical);
            if (col.min < colMin)
                colMin = col.min;
            if (col.max > colMax)
                colMax = col.max;
            if (col.span > colMaxSpan)
                colMaxSpan = col.span;
            if (row.min < rowMin)
                rowMin = row.min;
            if (row.max > rowMax)
                rowMax = row.max;
            if (row.span > rowMaxSpan)
                rowMaxSpan = row.span;
        }

        // Compute *track* count estimates for each axis from:
        //   - The explicit track counts
        //   - The origin-zero coordinate min and max grid line variables
        final negativeImplicitInlineTracks = GridCoordinates.impliedNegativeImplicitTracks(colMin);
        final explicitInlineTracks = explicitColCount;
        var positiveImplicitInlineTracks = GridCoordinates.impliedPositiveImplicitTracks(colMax, explicitColCount);
        final negativeImplicitBlockTracks = GridCoordinates.impliedNegativeImplicitTracks(rowMin);
        final explicitBlockTracks = explicitRowCount;
        var positiveImplicitBlockTracks = GridCoordinates.impliedPositiveImplicitTracks(rowMax, explicitRowCount);

        // In each axis, adjust positive track estimate if any items have a span that does not fit within
        // the total number of tracks in the estimate
        final totInlineTracks = negativeImplicitInlineTracks + explicitInlineTracks + positiveImplicitInlineTracks;
        if (totInlineTracks < colMaxSpan)
            positiveImplicitInlineTracks = colMaxSpan - explicitInlineTracks - negativeImplicitInlineTracks;

        final totBlockTracks = negativeImplicitBlockTracks + explicitBlockTracks + positiveImplicitBlockTracks;
        if (totBlockTracks < rowMaxSpan)
            positiveImplicitBlockTracks = rowMaxSpan - explicitBlockTracks - negativeImplicitBlockTracks;

        final columnCounts = TrackCounts.fromRaw(negativeImplicitInlineTracks, explicitInlineTracks, positiveImplicitInlineTracks);
        final rowCounts = TrackCounts.fromRaw(negativeImplicitBlockTracks, explicitBlockTracks, positiveImplicitBlockTracks);

        return new GridSizeEstimate(columnCounts, rowCounts);
    }

    /**
     * Helper function for `computeGridSizeEstimate`
     * Produces a conservative estimate of the greatest and smallest grid lines used by a single grid item
     *
     * Values are returned in origin-zero coordinates
     */
    public static function childMinLineMaxLineSpan(ozLine:LineOf<GenericGridPlacement>):MinLineMaxLineSpan {
        // 8.3.1. Grid Placement Conflict Handling
        // A. If the placement for a grid item contains two lines, and the start line is further end-ward than the end line, swap the two lines.
        // B. If the start line is equal to the end line, remove the end line.
        // C. If the placement contains two spans, remove the one contributed by the end grid-placement property.
        // D. If the placement contains only a span for a named line, replace it with a span of 1.
        final start = ozLine.start;
        final end = ozLine.end;
        final startIsLine = start.kind == GenericGridPlacement.LINE_KIND;
        final endIsLine = end.kind == GenericGridPlacement.LINE_KIND;

        var min = 0;
        var max = 0;
        var span = 1;
        if (startIsLine && endIsLine) {
            // Both tracks specified. See rules A and B above
            final track1 = start.value;
            final track2 = end.value;
            if (track1 == track2) {
                min = track1;
                max = track1 + 1;
            }
            else {
                min = track1 < track2 ? track1 : track2;
                max = track1 > track2 ? track1 : track2;
            }
        }
        else if (startIsLine) {
            // Start track specified
            final track = start.value;
            min = track;
            max = end.kind == GenericGridPlacement.SPAN_KIND ? track + end.value : track + 1;
        }
        else if (endIsLine) {
            // End track specified
            // An auto start with a definite end resolves to a span of 1 ending at that line
            final track = end.value;
            min = start.kind == GenericGridPlacement.SPAN_KIND ? track - start.value : track - 1;
            max = track;
        }
        else {
            // Only spans or autos
            // We ignore spans here by returning 0 which never effect the estimate as these are accounted for separately
            min = 0;
            max = 0;
            // Calculate span only for indefinitely placed items as we don't need for other items (whose required space will
            // be taken into account by min and max)
            span = PlacementLine.indefiniteSpan(ozLine);
        }

        // Clamp the min and max lines into the limited grid so that the estimated implicit track counts
        // stay within the maximum track limit (https://www.w3.org/TR/css-grid-1/#overlarge-grids).
        // This matches the clamping of the actual item placements performed during placement.
        final clampedMin = min > GridCoordinates.MIN_OZ_LINE ? min : GridCoordinates.MIN_OZ_LINE;
        final clampedMax = max < GridCoordinates.MAX_OZ_LINE ? max : GridCoordinates.MAX_OZ_LINE;

        return new MinLineMaxLineSpan(clampedMin, clampedMax, span);
    }

}

/**
 * The min line, max line and span of a grid item (result of `ImplicitGrid.childMinLineMaxLineSpan`)
 */
class MinLineMaxLineSpan {

    public final min:Int;

    public final max:Int;

    public final span:Int;

    public inline function new(min:Int, max:Int, span:Int) {
        this.min = min;
        this.max = max;
        this.span = span;
    }

}
