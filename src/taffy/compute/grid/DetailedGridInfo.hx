// Ported from taffy 0.15.0: src/compute/grid/mod.rs (DetailedGridInfo, DetailedGridTracksInfo, DetailedGridItemsInfo)
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.grid;

import taffy.compute.grid.GenericGridPlacement.PlacementLine;

import haxe.ds.StringMap;
import taffy.geometry.Line;
import taffy.geometry.LineOf;
import taffy.geometry.Point;
import taffy.geometry.Rect;
import taffy.geometry.Size;
import taffy.style.Direction;
import taffy.style.GridAreaAxis;
import taffy.style.GridPlacement;
import taffy.util.Sys;

/**
 * Information from the computation of grid
 */
class DetailedGridInfo {

    /** https://drafts.csswg.org/css-grid-1/#grid-row */
    public final rows:DetailedGridTracksInfo;

    /** https://drafts.csswg.org/css-grid-1/#grid-column */
    public final columns:DetailedGridTracksInfo;

    /** https://drafts.csswg.org/css-grid-1/#grid-items */
    public final items:Array<DetailedGridItemsInfo>;

    /** Grid area edge lookup used to resolve the grid placements of absolutely positioned children */
    final areas:StringMap<NamedLineResolver.AreaLines>;

    public function new(rows:DetailedGridTracksInfo, columns:DetailedGridTracksInfo, items:Array<DetailedGridItemsInfo>,
            areas:StringMap<NamedLineResolver.AreaLines>) {
        this.rows = rows;
        this.columns = columns;
        this.items = items;
        this.areas = areas;
    }

    /**
     * Serialize the used row track sizes and line names in the resolved value format of the
     * `grid-template-rows` property (see https://www.w3.org/TR/css-grid-1/#resolved-track-list)
     * Track sizes are divided by `zoom` (the container's effective CSS `zoom`, or `1.0`) to give unzoomed px.
     */
    public function gridTemplateRows(zoom:Float):Null<String> {
        return rows.toTrackListString(zoom);
    }

    /**
     * Serialize the used column track sizes and line names in the resolved value format of the
     * `grid-template-columns` property (see https://www.w3.org/TR/css-grid-1/#resolved-track-list)
     * Track sizes are divided by `zoom` (the container's effective CSS `zoom`, or `1.0`) to give unzoomed px.
     */
    public function gridTemplateColumns(zoom:Float):Null<String> {
        return columns.toTrackListString(zoom);
    }

    /**
     * Resolve the physical grid area for an absolutely positioned box from its grid placement.
     * The padding box and returned area use coordinates relative to the grid container's border box.
     */
    public function resolveAbsoluteGridArea(gridRow:LineOf<GridPlacement>, gridColumn:LineOf<GridPlacement>, direction:Direction, paddingBox:Rect):Rect {
        final columnsLine = this.columns.resolveAbsoluteGridAxis(gridColumn, areas, Column, paddingBox.left, paddingBox.right, direction.isRtl());
        final rowsLine = this.rows.resolveAbsoluteGridAxis(gridRow, areas, Row, paddingBox.top, paddingBox.bottom, false);
        return new Rect(columnsLine.start, columnsLine.end, rowsLine.start, rowsLine.end);
    }

    /**
     * Compute the location and size of the grid area occupied by the item at `itemIndex` (an
     * index into `items`), relative to the grid container's border box.
     *
     * The edges resolve to the edges of the tracks bounding the item's grid area (a start line
     * resolves to the start of the track that follows it and an end line to the end of the track
     * that precedes it), so the area excludes any gutter or content-alignment spacing around it.
     *
     * Returns null if `itemIndex` is out of bounds. The result is a `Rect` (left, right, top, bottom).
     */
    public function itemGridArea(itemIndex:Int):Null<Rect> {
        if (itemIndex < 0 || itemIndex >= items.length)
            return null;
        final item = items[itemIndex];
        final startCol = columns.positions[item.columnStart - 1];
        final endCol = columns.positions[item.columnEnd - 2];
        final left = Sys.f32Min(startCol.start, endCol.start);
        final right = Sys.f32Max(startCol.end, endCol.end);
        final top = rows.positions[item.rowStart - 1].start;
        final bottom = rows.positions[item.rowEnd - 2].end;
        return new Rect(left, right, top, bottom);
    }

}

/**
 * Information from the computation of grids tracks
 */
class DetailedGridTracksInfo {

    static final EMPTY_NAMES:Array<String> = [];

    /** Number of leading implicit grid tracks */
    public final negativeImplicitTracks:Int;

    /** Number of explicit grid tracks */
    public final explicitTracks:Int;

    /** Number of trailing implicit grid tracks */
    public final positiveImplicitTracks:Int;

    /**
     * The start and end position of each track relative to the grid container's border box.
     * These positions account for the container's border and padding, the `gap` property,
     * content alignment (`align-content`/`justify-content`), and collapsed tracks.
     */
    public final positions:Array<Line>;

    /**
     * Sorted, disjoint ranges of collapsed `auto-fit` tracks (indices into `positions`), whose
     * adjacent gutters overlap when resolving absolute grid-area edges. Stored as pairs
     * `[start0, end0, start1, end1...]` (end exclusive). Empty unless a track collapsed.
     */
    public final collapsedTracks:Array<Int>;

    /**
     * The position of the axis' single grid line relative to the grid container's border box
     * when the axis has no tracks (an empty grid still contains one grid line in each axis,
     * positioned by content alignment). Null when the axis has tracks.
     */
    public final emptyAxisLine:Null<Float>;

    /**
     * The names of each *explicit* grid line. Stored line `i` (0-indexed) bounds the start of
     * explicit track `i`; use `namesForLine` or `iterLineNames` for indices relative to the full grid
     * (including implicit tracks). Empty if the grid has no named lines.
     */
    public final lineNames:GridLineNames;

    public function new(negativeImplicitTracks:Int, explicitTracks:Int, positiveImplicitTracks:Int, positions:Array<Line>,
            collapsedTracks:Array<Int>, emptyAxisLine:Null<Float>, lineNames:GridLineNames) {
        this.negativeImplicitTracks = negativeImplicitTracks;
        this.explicitTracks = explicitTracks;
        this.positiveImplicitTracks = positiveImplicitTracks;
        this.positions = positions;
        this.collapsedTracks = collapsedTracks;
        this.emptyAxisLine = emptyAxisLine;
        this.lineNames = lineNames;
    }

    /** Construct DetailedGridTracksInfo from TrackCounts and GridTracks */
    public static function fromGridTracksAndTrackCount(trackCount:TrackCounts, gridTracks:Array<GridTrack>, lineNames:GridLineNames):DetailedGridTracksInfo {
        // Get the start and end position of each track relative to the grid container's border box,
        // along with the index ranges of any runs of collapsed `auto-fit` tracks
        final positions:Array<Line> = [];
        final collapsedTracks:Array<Int> = [];
        for (track in gridTracks) {
            if (track.kind != Track)
                continue;
            if (track.isCollapsed) {
                final index = positions.length;
                if (collapsedTracks.length > 0 && collapsedTracks[collapsedTracks.length - 1] == index) {
                    collapsedTracks[collapsedTracks.length - 1] = index + 1;
                }
                else {
                    collapsedTracks.push(index);
                    collapsedTracks.push(index + 1);
                }
            }
            positions.push(new Line(track.offset, track.offset + track.baseSize));
        }
        // An axis with no tracks consists of a single gutter whose offset is where the axis'
        // single grid line was positioned by content alignment
        final emptyAxisLine:Null<Float> = (positions.length == 0 && gridTracks.length > 0) ? gridTracks[0].offset : null;
        return new DetailedGridTracksInfo(trackCount.negativeImplicit, trackCount.explicit, trackCount.positiveImplicit, positions, collapsedTracks,
            emptyAxisLine, lineNames);
    }

    /**
     * The names of the grid line with the passed 0-indexed line index, where line `i` bounds
     * the start of track `i` of the full grid (including implicit tracks).
     * Returns an empty array if the line has no names or the index is out of range.
     */
    public function namesForLine(lineIndex:Int):Array<String> {
        final storedIndex = lineIndex - negativeImplicitTracks;
        return storedIndex >= 0 ? lineNames.line(storedIndex) : EMPTY_NAMES;
    }

    /**
     * The name group of each grid line of the full grid (including implicit tracks) in line order,
     * with empty groups for unnamed (implicit) lines. Empty if the grid has no named lines.
     */
    public function iterLineNames():Array<Array<String>> {
        if (lineNames.isEmpty())
            return lineNames.iter();
        final totalLineCount = positions.length + 1;
        final leadingEmpty = negativeImplicitTracks;
        final trailing = totalLineCount - (leadingEmpty + lineNames.lineCount());
        return lineNames.iterPadded(leadingEmpty, trailing > 0 ? trailing : 0);
    }

    /** Resolve an absolute placement in this axis to physical start and end coordinates */
    public function resolveAbsoluteGridAxis(placement:LineOf<GridPlacement>, areas:StringMap<NamedLineResolver.AreaLines>, axis:GridAreaAxis,
            paddingStart:Float, paddingEnd:Float, isReversed:Bool):Line {
        final trackCounts = new TrackCounts(negativeImplicitTracks, explicitTracks, positiveImplicitTracks);
        final minLine = -trackCounts.negativeImplicit;
        final maxLine = trackCounts.explicit + trackCounts.positiveImplicit;
        // Resolve the placement to a pair of (sorted) lines first, and only then treat lines
        // that fall outside the grid as `auto`. A placement whose lines end up swapped (e.g.
        // `grid-column: 3 / 1`, or a non-existent named line which resolves past the end of the
        // explicit grid) is normalized before the out-of-grid check, so e.g. `foo / 3` on a
        // 2-column grid resolves to the area between line 3 and the end padding edge.
        final resolved = PlacementLine.resolveAbsolutelyPositionedGridTracks(
            PlacementLine.intoOriginZero(lineNames.resolveLineNames(placement, areas, axis, explicitTracks), explicitTracks)
        );
        final startLine = toTrackIndex(resolved.start, minLine, maxLine, trackCounts);
        final endLine = toTrackIndex(resolved.end, minLine, maxLine, trackCounts);

        var startPosition = isReversed ? paddingEnd : paddingStart;
        if (startLine != null) {
            final line:Int = startLine;
            if (line < positions.length)
                startPosition = absoluteTrackEdge(line, true, isReversed);
            else if (positions.length > 0)
                startPosition = isReversed ? positions[positions.length - 1].start : positions[positions.length - 1].end;
            else if (emptyAxisLine != null)
                startPosition = emptyAxisLine;
        }
        var endPosition = isReversed ? paddingStart : paddingEnd;
        if (endLine != null) {
            final line:Int = endLine;
            if (line >= 1 && line - 1 < positions.length)
                endPosition = absoluteTrackEdge(line - 1, false, isReversed);
            else if (positions.length > 0)
                endPosition = isReversed ? positions[0].end : positions[0].start;
            else if (emptyAxisLine != null)
                endPosition = emptyAxisLine;
        }

        // An area whose lines all fall within a collapsed run is zero-sized and anchored at its
        // logical start edge (as in Chrome; Gecko anchors it before the shared gutter instead).
        return if (isReversed) {
            new Line(Sys.f32Min(startPosition, endPosition), startPosition);
        }
        else {
            new Line(startPosition, Sys.f32Max(startPosition, endPosition));
        }
    }

    /** Filter a resolved line to the grid and convert it into a track index (`index / 2` of the GridTrack index) */
    static inline function toTrackIndex(line:Null<Int>, minLine:Int, maxLine:Int, trackCounts:TrackCounts):Null<Int> {
        return if (line == null || (line : Int) < minLine || (line : Int) > maxLine) {
            null;
        }
        else {
            final index = GridCoordinates.tryIntoTrackVecIndex(line, trackCounts);
            index < 0 ? null : Std.int(index / 2);
        }
    }

    /** Resolve a track edge, excluding gutters that overlap across a collapsed track run. */
    function absoluteTrackEdge(index:Int, isStart:Bool, isReversed:Bool):Float {
        var track = positions[index];
        // Find the collapsed range containing the index (if any)
        var r = 0;
        while (r < collapsedTracks.length) {
            final rangeStart = collapsedTracks[r];
            final rangeEnd = collapsedTracks[r + 1];
            if (rangeEnd > index) {
                if (rangeStart <= index) {
                    final adjacent = isStart ? rangeEnd : rangeStart - 1;
                    if (adjacent >= 0 && adjacent < positions.length)
                        track = positions[adjacent];
                }
                break;
            }
            r += 2;
        }
        // Collapsed gutters overlap: a start edge follows the shared gutter, while an end
        // edge precedes it.
        return isStart != isReversed ? track.start : track.end;
    }

    /**
     * Serialize the used track sizes and line names of this axis in the resolved value format of
     * the `grid-template-rows`/`grid-template-columns` properties
     * (see https://www.w3.org/TR/css-grid-1/#resolved-track-list)
     * Track sizes are divided by `zoom` (the container's effective CSS `zoom`, or `1.0`) to give unzoomed px.
     */
    public function toTrackListString(zoom:Float):String {
        if (positions.length == 0)
            return "none";

        final out = new StringBuf();
        var needsSpace = false;
        for (trackIndex in 0...positions.length) {
            final position = positions[trackIndex];
            final names = namesForLine(trackIndex);
            if (names.length > 0) {
                if (needsSpace)
                    out.add(" ");
                writeLineNames(out, names);
                needsSpace = true;
            }
            if (needsSpace)
                out.add(" ");
            out.add(formatFloat((position.end - position.start) / zoom));
            out.add("px");
            needsSpace = true;
        }
        final trailingNames = namesForLine(positions.length);
        if (trailingNames.length > 0) {
            out.add(" ");
            writeLineNames(out, trailingNames);
        }
        return out.toString();
    }

    /** Write a bracketed line name group (e.g. `[foo bar]`) */
    static function writeLineNames(out:StringBuf, names:Array<String>):Void {
        out.add("[");
        for (i in 0...names.length) {
            if (i != 0)
                out.add(" ");
            out.add(names[i]);
        }
        out.add("]");
    }

    /** Format a float like Rust's `{}` formatting of f32 (integers without a fractional part) */
    static function formatFloat(value:Float):String {
        if (value == Math.ffloor(value) && Math.abs(value) < 1e15)
            return Std.string(Std.int(value) == value ? Std.int(value) : value);
        return Std.string(value);
    }

}

/**
 * Grid area information from the placement algorithm
 *
 * The values is 1-indexed grid line numbers bounding the area.
 * This matches the Chrome and Firefox's format as of 2nd Jan 2024.
 */
class DetailedGridItemsInfo {

    /** row-start with 1-indexed grid line numbers */
    public final rowStart:Int;

    /** row-end with 1-indexed grid line numbers */
    public final rowEnd:Int;

    /** column-start with 1-indexed grid line numbers */
    public final columnStart:Int;

    /** column-end with 1-indexed grid line numbers */
    public final columnEnd:Int;

    public inline function new(rowStart:Int, rowEnd:Int, columnStart:Int, columnEnd:Int) {
        this.rowStart = rowStart;
        this.rowEnd = rowEnd;
        this.columnStart = columnStart;
        this.columnEnd = columnEnd;
    }

    /** Construct from GridItems */
    public static inline function fromGridItem(gridItem:GridItem):DetailedGridItemsInfo {
        return new DetailedGridItemsInfo(
            toOneIndexedGridLine(gridItem.rowIndexes.start),
            toOneIndexedGridLine(gridItem.rowIndexes.end),
            toOneIndexedGridLine(gridItem.columnIndexes.start),
            toOneIndexedGridLine(gridItem.columnIndexes.end)
        );
    }

    /** Conversion from the indexes of the GridTrack arrays into 1-indexed grid line numbers */
    static inline function toOneIndexedGridLine(gridTrackIndex:Int):Int {
        return Std.int(gridTrackIndex / 2) + 1;
    }

}
