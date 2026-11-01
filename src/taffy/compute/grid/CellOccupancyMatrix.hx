// Ported from taffy 0.15.0: src/compute/grid/types/cell_occupancy.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.grid;

import taffy.compute.grid.GridCoordinates.IntLine;

import taffy.geometry.AbsoluteAxis;

/**
 * The occupancy state of a single grid cell
 */
enum abstract CellOccupancyState(Int) {

    /** Indicates that a grid cell is unoccupied */
    var Unoccupied = 0;

    /** Indicates that a grid cell is occupied by a definitely placed item */
    var DefinitelyPlaced = 1;

    /** Indicates that a grid cell is occupied by an item that was placed by the auto placement algorithm */
    var AutoPlaced = 2;

}

/**
 * A run of occupied cells within a single track. The range (`start` inclusive, `end` exclusive) is in OriginZero line
 * coordinates along the track (so for a row track, the range spans column lines and vice versa).
 */
class OccupiedInterval {

    /** The start of the range of cells covered by this interval */
    public var start:Int;

    /** The end (exclusive) of the range of cells covered by this interval */
    public var end:Int;

    /** The occupancy state of every cell within this interval */
    public var state:CellOccupancyState;

    public inline function new(start:Int, end:Int, state:CellOccupancyState) {
        this.start = start;
        this.end = end;
        this.state = state;
    }

    /** Whether this interval overlaps the given range */
    public inline function overlaps(rangeStart:Int, rangeEnd:Int):Bool {
        return start < rangeEnd && end > rangeStart;
    }

    public inline function clone():OccupiedInterval {
        return new OccupiedInterval(start, end, state);
    }

    public inline function equals(other:OccupiedInterval):Bool {
        return start == other.start && end == other.end && state == other.state;
    }

}

/**
 * The occupied cells of a single track, stored as a sorted list of disjoint intervals in
 * OriginZero line coordinates. Gaps between intervals are unoccupied. Touching intervals
 * with the same state are merged.
 */
class TrackIntervals {

    /** The sorted, disjoint list of occupied intervals within the track */
    public var intervals:Array<OccupiedInterval> = [];

    /** The furthest end line of an auto-placed item starting in this secondary-axis track (null if none) */
    public var autoPlacementCursor:Null<Int> = null;

    public inline function new() {}

    /** Whether the track contains any occupied cells */
    public inline function isEmpty():Bool {
        return intervals.length == 0;
    }

    /** The occupancy state of the cell whose start line is at `coordinate` */
    public function stateAt(coordinate:Int):CellOccupancyState {
        for (interval in intervals) {
            if (interval.start <= coordinate && coordinate < interval.end)
                return interval.state;
        }
        return Unoccupied;
    }

    /**
     * Set the cells covered by `rangeStart..rangeEnd` to `state`, overwriting the state of any already-occupied
     * cells within the range (matching the overwrite semantics of a dense matrix of cells)
     */
    public function paint(rangeStart:Int, rangeEnd:Int, state:CellOccupancyState):Void {
        if (rangeStart >= rangeEnd)
            return;

        // Fast path: the painted range lies entirely after all existing intervals
        // (the common case, as placement queries and inserts mostly advance forwards)
        if (intervals.length == 0) {
            intervals.push(new OccupiedInterval(rangeStart, rangeEnd, state));
            return;
        }
        final last = intervals[intervals.length - 1];
        if (last.end <= rangeStart) {
            if (last.state == state && last.end == rangeStart)
                last.end = rangeEnd;
            else
                intervals.push(new OccupiedInterval(rangeStart, rangeEnd, state));
            return;
        }

        final result:Array<OccupiedInterval> = [];

        // Intervals (or partial intervals) entirely before the painted range
        for (interval in intervals) {
            if (interval.end <= rangeStart)
                result.push(interval.clone());
            else if (interval.start < rangeStart)
                result.push(new OccupiedInterval(interval.start, rangeStart, interval.state));
        }

        // The painted range, merged with the preceding interval if it touches and has the same state
        final resultLast = result.length > 0 ? result[result.length - 1] : null;
        if (resultLast != null && resultLast.state == state && resultLast.end == rangeStart)
            resultLast.end = rangeEnd;
        else
            result.push(new OccupiedInterval(rangeStart, rangeEnd, state));

        // Intervals (or partial intervals) entirely after the painted range
        for (interval in intervals) {
            final trimmed = if (interval.start >= rangeEnd) {
                interval.clone();
            }
            else if (interval.end > rangeEnd) {
                new OccupiedInterval(rangeEnd, interval.end, interval.state);
            }
            else {
                continue;
            }
            final l = result[result.length - 1];
            if (l.state == trimmed.state && l.end == trimmed.start)
                l.end = trimmed.end;
            else
                result.push(trimmed);
        }

        intervals = result;
    }

    /**
     * Find the extent of the occupied interval which an auto-placement search along the track
     * would collide with last: the end of the last overlapping interval. Returns the extremal
     * occupied cell of that interval (which may lie outside the range: every search position
     * before the returned extent also collides with the interval), or null if the range is
     * entirely unoccupied.
     */
    public function collisionExtent(rangeStart:Int, rangeEnd:Int):Null<Int> {
        var i = intervals.length - 1;
        while (i >= 0) {
            final interval = intervals[i];
            if (!(interval.end > rangeStart))
                break;
            if (interval.overlaps(rangeStart, rangeEnd))
                return interval.end - 1;
            i--;
        }
        return null;
    }

}

/**
 * A dynamically sized matrix (2d grid) which tracks the occupancy of each grid cell during auto-placement.
 * It also keeps tabs on how many tracks there are and which tracks are implicit and which are explicit.
 *
 * Occupancy is stored sparsely as per-track interval lists (in both orientations), so memory usage
 * is proportional to the number of placed items rather than the total number of grid cells.
 */
class CellOccupancyMatrix {

    /** The counts of implicit and explicit columns */
    final columns:TrackCounts;

    /** The counts of implicit and explicit rows */
    final rows:TrackCounts;

    /** For each row track: the occupied intervals within that row (in column coordinates) */
    final rowIntervals:Array<TrackIntervals>;

    /** For each column track: the occupied intervals within that column (in row coordinates) */
    final columnIntervals:Array<TrackIntervals>;

    /**
     * Create a CellOccupancyMatrix given a set of provisional track counts. The grid can expand as needed to fit more tracks,
     * the provisional track counts represent a best effort attempt to avoid the extra allocations this requires.
     */
    public function new(columns:TrackCounts, rows:TrackCounts) {
        this.columns = columns.clone();
        this.rows = rows.clone();
        rowIntervals = [for (_ in 0...rows.len()) new TrackIntervals()];
        columnIntervals = [for (_ in 0...columns.len()) new TrackIntervals()];
    }

    /** Create a CellOccupancyMatrix given a set of provisional track counts */
    public static inline function withTrackCounts(columns:TrackCounts, rows:TrackCounts):CellOccupancyMatrix {
        return new CellOccupancyMatrix(columns, rows);
    }

    /**
     * The per-track interval lists for tracks in the specified axis. Each row track's intervals
     * are in column coordinates and vice versa.
     */
    public inline function trackLists(trackAxis:AbsoluteAxis):Array<TrackIntervals> {
        return trackAxis == Horizontal ? columnIntervals : rowIntervals;
    }

    /**
     * Expands the grid (potentially in all 4 directions) in order to ensure that the specified
     * spans (in OriginZero coordinates) fit within the tracked tracks
     */
    function expandToFitRange(rowSpan:IntLine, colSpan:IntLine):Void {
        // Calculate number of rows and columns missing to accommodate ranges (if any)
        final reqNegativeRows = imax(-rows.negativeImplicit - rowSpan.start, 0);
        final reqPositiveRows = imax(rowSpan.end - rows.implicitEndLine(), 0);
        final reqNegativeCols = imax(-columns.negativeImplicit - colSpan.start, 0);
        final reqPositiveCols = imax(colSpan.end - columns.implicitEndLine(), 0);

        // Add empty tracks to the front and/or back of the per-track interval lists.
        // Interval contents are stored in OriginZero coordinates, so they do not need to shift.
        for (_ in 0...reqNegativeRows)
            rowIntervals.unshift(new TrackIntervals());
        for (_ in 0...reqPositiveRows)
            rowIntervals.push(new TrackIntervals());
        for (_ in 0...reqNegativeCols)
            columnIntervals.unshift(new TrackIntervals());
        for (_ in 0...reqPositiveCols)
            columnIntervals.push(new TrackIntervals());

        rows.negativeImplicit += reqNegativeRows;
        rows.positiveImplicit += reqPositiveRows;
        columns.negativeImplicit += reqNegativeCols;
        columns.positiveImplicit += reqPositiveCols;
    }

    /** Mark an area of the matrix as occupied, expanding the allocated space as necessary to accommodate the passed area. */
    public function markAreaAs(primaryAxis:AbsoluteAxis, primarySpan:IntLine, secondarySpan:IntLine, value:CellOccupancyState):Void {
        final rowSpan = primaryAxis == Horizontal ? secondarySpan : primarySpan;
        final columnSpan = primaryAxis == Horizontal ? primarySpan : secondarySpan;

        expandToFitRange(rowSpan, columnSpan);

        if (value == AutoPlaced && primarySpan.start < primarySpan.end && secondarySpan.start < secondarySpan.end)
            advanceAutoPlacementCursor(primaryAxis, secondarySpan.start, primarySpan.end);

        final rowRangeStart = rows.ozLineToNextTrack(rowSpan.start);
        final rowRangeEnd = rows.ozLineToNextTrack(rowSpan.end);
        final colRangeStart = columns.ozLineToNextTrack(columnSpan.start);
        final colRangeEnd = columns.ozLineToNextTrack(columnSpan.end);
        for (rowIndex in rowRangeStart...rowRangeEnd)
            rowIntervals[rowIndex].paint(columnSpan.start, columnSpan.end, value);
        for (columnIndex in colRangeStart...colRangeEnd)
            columnIntervals[columnIndex].paint(rowSpan.start, rowSpan.end, value);
    }

    /**
     * Determines whether a grid area specified by the bounding grid lines in OriginZero coordinates
     * is entirely unnocupied. Returns true if all grid cells within the grid area are unnocupied, else false.
     */
    public inline function lineAreaIsUnoccupied(primaryAxis:AbsoluteAxis, primarySpan:IntLine, secondarySpan:IntLine):Bool {
        return lineAreaCollisionJump(primaryAxis, primarySpan, secondarySpan) == null;
    }

    /**
     * Checks the specified area for occupied cells (`primarySpan` and `secondarySpan` are
     * bounding grid lines in OriginZero coordinates). Returns null if the area is entirely
     * unoccupied. Otherwise returns the next search position (in OriginZero coordinates, along
     * `primaryAxis`) that is not guaranteed to collide with the occupied cells found in the
     * area. This allows the auto-placement search cursor to jump past collisions rather than
     * advancing one track at a time.
     */
    public function lineAreaCollisionJump(primaryAxis:AbsoluteAxis, primarySpan:IntLine, secondarySpan:IntLine):Null<Int> {
        final lists = trackLists(primaryAxis.otherAxis());
        final secondaryCounts = trackCounts(primaryAxis.otherAxis());
        final secondaryRangeStart = secondaryCounts.ozLineToNextTrack(secondarySpan.start);
        final secondaryRangeEnd = secondaryCounts.ozLineToNextTrack(secondarySpan.end);

        // Out of bounds cells are considered unoccupied, so clamp the secondary range to the
        // tracks which actually exist
        final secondaryStart = imax(secondaryRangeStart, 0);
        final secondaryEnd = imin(secondaryRangeEnd, lists.length);

        var extent:Null<Int> = null;
        for (secondaryIndex in secondaryStart...secondaryEnd) {
            final cell = lists[secondaryIndex].collisionExtent(primarySpan.start, primarySpan.end);
            if (cell == null)
                continue;
            extent = extent == null ? cell : imax(extent, cell);
        }

        return extent == null ? null : (extent : Int) + 1;
    }

    /**
     * Given a span of tracks in `axis` (in OriginZero coordinates), returns the next search
     * position past all non-empty tracks within the span, or null if all tracks within the
     * span are entirely unoccupied. Used to place items which span every track in the other
     * axis (such items can only fit in a stripe of entirely unoccupied tracks).
     */
    public function occupiedTrackJump(axis:AbsoluteAxis, span:IntLine):Null<Int> {
        final counts = trackCounts(axis);
        final lists = trackLists(axis);
        final start = imax(counts.ozLineToNextTrack(span.start), 0);
        final end = imin(counts.ozLineToNextTrack(span.end), lists.length);
        var index = end - 1;
        while (index >= start) {
            if (!lists[index].isEmpty()) {
                final line = counts.trackToPrevOzLine(index);
                return line + 1;
            }
            index--;
        }
        return null;
    }

    /** Determines whether the specified row contains any items */
    public inline function rowIsOccupied(rowIndex:Int):Bool {
        return rowIndex >= 0 && rowIndex < rowIntervals.length && !rowIntervals[rowIndex].isEmpty();
    }

    /** Determines whether the specified column contains any items */
    public inline function columnIsOccupied(columnIndex:Int):Bool {
        return columnIndex >= 0 && columnIndex < columnIntervals.length && !columnIntervals[columnIndex].isEmpty();
    }

    /** Returns the track counts of this CellOccupancyMatrix in the relevant axis (do not mutate) */
    public inline function trackCounts(trackType:AbsoluteAxis):TrackCounts {
        return trackType == Horizontal ? columns : rows;
    }

    /** The sparse placement cursor for items starting in the given secondary-axis track. */
    public function autoPlacementCursor(trackType:AbsoluteAxis, startAt:Int):Null<Int> {
        final counts = trackCounts(trackType.otherAxis());
        final trackComputedIndex = counts.ozLineToNextTrack(startAt);
        final lists = trackLists(trackType.otherAxis());
        if (trackComputedIndex < 0 || trackComputedIndex >= lists.length) {
            // Index out of bounds: no tracks to search
            return null;
        }
        return lists[trackComputedIndex].autoPlacementCursor;
    }

    /**
     * Advances the sparse placement cursor to at least `primaryEnd`.
     * The secondary-axis track must already exist in the matrix.
     */
    function advanceAutoPlacementCursor(primaryAxis:AbsoluteAxis, secondaryStart:Int, primaryEnd:Int):Void {
        final trackIndex = trackCounts(primaryAxis.otherAxis()).ozLineToNextTrack(secondaryStart);
        final tracks = primaryAxis == Horizontal ? rowIntervals : columnIntervals;
        final track = tracks[trackIndex];
        final cursor = track.autoPlacementCursor;
        track.autoPlacementCursor = (cursor == null || (cursor : Int) < primaryEnd) ? primaryEnd : cursor;
    }

    /** A compact 2d text representation of the matrix (for debugging) */
    public function toString():String {
        final buf = new StringBuf();
        buf.add('Rows: neg_implicit=${rows.negativeImplicit} explicit=${rows.explicit} pos_implicit=${rows.positiveImplicit}\n');
        buf.add('Cols: neg_implicit=${columns.negativeImplicit} explicit=${columns.explicit} pos_implicit=${columns.positiveImplicit}\n');
        if (rows.len() > 100 || columns.len() > 100) {
            buf.add("State: (not printed: more than 100 tracks)\n");
            return buf.toString();
        }
        buf.add("State:\n");
        for (row in rowIntervals) {
            for (columnIndex in 0...columns.len()) {
                final coordinate = columns.trackToPrevOzLine(columnIndex);
                buf.add(switch row.stateAt(coordinate) {
                    case Unoccupied: "_";
                    case DefinitelyPlaced: "D";
                    case AutoPlaced: "A";
                });
            }
            buf.add("\n");
        }
        return buf.toString();
    }

    static inline function imax(a:Int, b:Int):Int {
        return a > b ? a : b;
    }

    static inline function imin(a:Int, b:Int):Int {
        return a < b ? a : b;
    }

}
