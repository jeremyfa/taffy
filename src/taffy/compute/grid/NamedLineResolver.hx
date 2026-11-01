// Ported from taffy 0.15.0: src/compute/grid/types/named.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.grid;

import haxe.ds.StringMap;
import taffy.geometry.AbsoluteAxis;
import taffy.geometry.LineOf;
import taffy.style.GridAreaAxis;
import taffy.style.GridAreaAxis.GridAreaEnd;
import taffy.style.GridPlacement;
import taffy.style.GridTemplateComponent;
import taffy.style.RepetitionCount;
import taffy.style.Style;

/**
 * The one-indexed positions of the first line that starts and the first line that ends a named grid area in
 * each axis, i.e. the first line named `<area-name>-start`/`<area-name>-end` (explicitly or by
 * `grid-template-areas`). A value of 0 means that there is no such line.
 */
class AreaLines {

    /** The first line that starts the area in the row axis */
    public var rowStart:Int = 0;

    /** The first line that ends the area in the row axis */
    public var rowEnd:Int = 0;

    /** The first line that starts the area in the column axis */
    public var columnStart:Int = 0;

    /** The first line that ends the area in the column axis */
    public var columnEnd:Int = 0;

    public inline function new() {}

    /** The line for the passed edge of the area (0 if there is none) */
    public inline function get(axis:GridAreaAxis, end:GridAreaEnd):Int {
        return axis == Row ? (end == Start ? rowStart : rowEnd) : (end == Start ? columnStart : columnEnd);
    }

    /** Set the line for the passed edge of the area */
    public inline function set(axis:GridAreaAxis, end:GridAreaEnd, value:Int):Void {
        if (axis == Row) {
            if (end == Start)
                rowStart = value;
            else
                rowEnd = value;
        }
        else {
            if (end == Start)
                columnStart = value;
            else
                columnEnd = value;
        }
    }

}

/**
 * Resolver for named placements in one grid axis
 */
class NamedLineResolverAxis {

    /** Named lines and their one-indexed positions (sorted) */
    final lines:StringMap<Array<Int>>;

    /** The edges of named grid areas (in both axes) */
    final areas:StringMap<AreaLines>;

    /** The axis being resolved */
    final axis:GridAreaAxis;

    /** Number of explicit tracks in this axis */
    final explicitTrackCount:Int;

    public inline function new(lines:StringMap<Array<Int>>, areas:StringMap<AreaLines>, axis:GridAreaAxis, explicitTrackCount:Int) {
        this.lines = lines;
        this.areas = areas;
        this.axis = axis;
        this.explicitTrackCount = explicitTrackCount;
    }

    /** The line for the passed edge of the named grid area in this axis (0 if there is none) */
    function areaLine(areaName:String, end:GridAreaEnd):Int {
        final area = areas.get(areaName);
        return area == null ? 0 : area.get(axis, end);
    }

    /** Resolve named lines and spans into numeric placements (Rust `Line<NonNamedGridPlacement>`) */
    public function resolveLineNames(line:LineOf<GridPlacement>):LineOf<GenericGridPlacement> {
        final startLineResolved = switch line.start {
            case NamedLine(name, idx): GridPlacement.Line(findNamedLine(name, idx, Start));
            case other: other;
        }
        final endLineResolved = switch line.end {
            case NamedLine(name, idx): GridPlacement.Line(findNamedLine(name, idx, End));
            case other: other;
        }

        // If both the *-start and *-end values of its grid-placement properties specify a line, its grid span is implicit.
        // If it has an explicit span value, its grid span is explicit.
        // Otherwise, its grid span is automatic:
        //   - if it is subgridded in that axis, its grid span is determined from its <line-name-list>;
        //   - otherwise its grid span is 1.
        //
        // <https://drafts.csswg.org/css-grid-2/#grid-span>
        switch [startLineResolved, endLineResolved] {
            case [Line(startLine), NamedSpan(name, idx)] if (startLine != 0):
                final afterStartLine = GridCoordinates.gridLineIntoOriginZeroLine(startLine, explicitTrackCount) + 1;
                final endLine = nthLineForwards(linesNamed(name), afterStartLine, idx > 1 ? idx : 1);
                return new LineOf<GenericGridPlacement>(
                    GenericGridPlacement.line(startLine),
                    GenericGridPlacement.line(GridCoordinates.originZeroLineIntoGridLine(endLine, explicitTrackCount))
                );
            case [NamedSpan(name, idx), Line(endLine)] if (endLine != 0):
                final beforeEndLine = GridCoordinates.gridLineIntoOriginZeroLine(endLine, explicitTrackCount) - 1;
                final startLine = nthLineBackwards(linesNamed(name), beforeEndLine, idx > 1 ? idx : 1);
                return new LineOf<GenericGridPlacement>(
                    GenericGridPlacement.line(GridCoordinates.originZeroLineIntoGridLine(startLine, explicitTrackCount)),
                    GenericGridPlacement.line(endLine)
                );
            case [start, end]:
                return new LineOf<GenericGridPlacement>(toNonNamed(start), toNonNamed(end));
        }
    }

    static function toNonNamed(placement:GridPlacement):GenericGridPlacement {
        return switch placement {
            case Auto: GenericGridPlacement.AUTO;
            case Line(gridLine): GenericGridPlacement.line(gridLine);
            case Span(span): GenericGridPlacement.span(span);
            case NamedSpan(_, _): GenericGridPlacement.span(1);
            case NamedLine(_, _): throw "unreachable";
        }
    }

    /**
     * Resolve the grid line for a named grid line (`<custom-ident>` or `<integer> <custom-ident>`).
     * An index of 0 is used to represent "no index specified".
     *
     * https://drafts.csswg.org/css-grid-2/#line-placement
     */
    function findNamedLine(name:String, idx:Int, end:GridAreaEnd):Int {
        // A `<custom-ident>` on its own first attempts to match the edge of a named grid area:
        // the first line named `<custom-ident>-start` (or `<custom-ident>-end` for an end line).
        // Otherwise it is treated as if the integer 1 had been specified along with it.
        if (idx == 0) {
            final firstLine = areaLine(name, end);
            if (firstLine != 0)
                return GridCoordinates.originZeroLineIntoGridLine(GridCoordinates.clampedOriginZeroLine(ozLine(firstLine)), explicitTrackCount);
        }

        final lines = linesNamed(name);
        final line = if (idx >= 0) {
            nthLineForwards(lines, 0, idx > 1 ? idx : 1);
        }
        else {
            nthLineBackwards(lines, lastExplicitLine(), -idx);
        }
        return GridCoordinates.originZeroLineIntoGridLine(line, explicitTrackCount);
    }

    static final EMPTY_LINES:Array<Int> = [];

    /**
     * The sorted line numbers of the lines with the passed name
     *
     * A line generated by a grid area is included in the lines of its name if any line has been explicitly
     * given the same name. Otherwise it is found from the area's edges.
     */
    function linesNamed(name:String):Array<Int> {
        final named = lines.get(name);
        if (named != null)
            return named;
        final split = NamedLineResolver.splitAreaEdgeName(name);
        if (split != null) {
            final line = areaLine(split.areaName, split.end);
            if (line != 0)
                return [line];
        }
        return EMPTY_LINES;
    }

    /** The line at the end edge of the explicit grid */
    inline function lastExplicitLine():Int {
        return explicitTrackCount;
    }

    /**
     * Find the `n`th line in `lines` (searching forwards) that is not before `firstLine`.
     *
     * If there are not enough such lines, then all implicit lines after the explicit grid are
     * assumed to be in `lines` for the purpose of counting
     *
     * https://drafts.csswg.org/css-grid-2/#grid-placement-int
     */
    function nthLineForwards(lines:Array<Int>, firstLine:Int, n:Int):Int {
        final first = firstLine > 0 ? firstLine : 0;
        // Partition point: index of the first line that is not before `first`
        var startIndex = 0;
        while (startIndex < lines.length && ozLine(lines[startIndex]) < first)
            startIndex++;
        final remaining = lines.length - startIndex;
        final line = if (n - 1 < remaining) {
            ozLine(lines[startIndex + n - 1]);
        }
        else {
            final lastPlusOne = lastExplicitLine() + 1;
            (first > lastPlusOne ? first : lastPlusOne) + (n - remaining) - 1;
        }
        return GridCoordinates.clampedOriginZeroLine(line);
    }

    /**
     * Find the `n`th line in `lines` (searching backwards) that is not after `lastLine`.
     *
     * If there are not enough such lines, then all implicit lines before the explicit grid are
     * assumed to be in `lines` for the purpose of counting
     *
     * https://drafts.csswg.org/css-grid-2/#grid-placement-int
     */
    function nthLineBackwards(lines:Array<Int>, lastLine:Int, n:Int):Int {
        final last = lastLine < lastExplicitLine() ? lastLine : lastExplicitLine();
        // Partition point: number of lines that are not after `last`
        var count = 0;
        while (count < lines.length && ozLine(lines[count]) <= last)
            count++;
        final line = if (count - n >= 0) {
            ozLine(lines[count - n]);
        }
        else {
            (last < -1 ? last : -1) - (n - count) + 1;
        }
        return GridCoordinates.clampedOriginZeroLine(line);
    }

    /**
     * The named line maps store lines as 1-based "CSS Grid Line" numbers (which are always within the
     * explicit grid). Convert one to OriginZero coordinates.
     */
    static inline function ozLine(line:Int):Int {
        return line - 1;
    }

}

/**
 * The area name and the edge of a line name of the form `<area-name>-start` or `<area-name>-end`
 */
class AreaEdgeName {

    public final areaName:String;

    public final end:GridAreaEnd;

    public inline function new(areaName:String, end:GridAreaEnd) {
        this.areaName = areaName;
        this.end = end;
    }

}

/**
 * Resolver that takes grid lines names and area names as input and can then be used to
 * resolve line names of grid placement properties into line numbers.
 */
class NamedLineResolver {

    /** Map of row line names to (sorted) line numbers. Each line name may correspond to multiple lines */
    var rowLines:StringMap<Array<Int>>;

    /** Map of column line names to (sorted) line numbers. Each line name may correspond to multiple lines */
    var columnLines:StringMap<Array<Int>>;

    /** Map of area names to the lines of the area's edges */
    var areas:StringMap<AreaLines>;

    /** Number of columns implied by grid area definitions */
    var areaColumnCountValue:Int;

    /** Number of rows implied by grid area definitions */
    var areaRowCountValue:Int;

    /**
     * The number of explicit columns in the grid. This is an *input* to the `NamedLineResolver` and is
     * used when computing the fallback line when a non-existent named line is specified.
     */
    var explicitColumnCount:Int = 0;

    /**
     * The number of explicit rows in the grid. This is an *input* to the `NamedLineResolver` and is
     * used when computing the fallback line when a non-existent named line is specified.
     */
    var explicitRowCount:Int = 0;

    /**
     * The (1-indexed line number, name) pairs of every column line named in the track template,
     * in source order (excludes the implicit names generated by `grid-template-areas`)
     */
    final columnLineNamePairLines:Array<Int> = [];
    final columnLineNamePairNames:Array<String> = [];

    /** The (1-indexed line number, name) pairs of every row line named in the track template, in source order */
    final rowLineNamePairLines:Array<Int> = [];
    final rowLineNamePairNames:Array<String> = [];

    /** Split a line name of the form `<area-name>-start` or `<area-name>-end` into the area name and the edge */
    public static function splitAreaEdgeName(name:String):Null<AreaEdgeName> {
        if (StringTools.endsWith(name, "-start"))
            return new AreaEdgeName(name.substr(0, name.length - 6), Start);
        if (StringTools.endsWith(name, "-end"))
            return new AreaEdgeName(name.substr(0, name.length - 4), End);
        return null;
    }

    /**
     * Utility function to create or update an entry in a line name map
     *
     * `areas` must already contain the edges of the areas defined by `grid-template-areas`
     */
    static function upsertLineNameMap(map:StringMap<Array<Int>>, areas:StringMap<AreaLines>, axis:GridAreaAxis, key:String, value:Int):Void {
        // A line named `foo-start` or `foo-end` is also an edge of the (implicitly) named area `foo`. Record it as such
        // if it is the first such line. If `foo` is also an area defined by `grid-template-areas`, then the line which
        // that area generated also has this name.
        var areaLine = 0;
        final split = splitAreaEdgeName(key);
        if (split != null) {
            // The key is only created if the area is not already in the map
            var area = areas.get(split.areaName);
            if (area == null) {
                area = new AreaLines();
                areas.set(split.areaName, area);
            }
            final edge = area.get(axis, split.end);
            areaLine = edge;
            area.set(axis, split.end, edge == 0 ? value : (edge < value ? edge : value));
        }

        final existing = map.get(key);
        if (existing != null) {
            existing.push(value);
        }
        else {
            // Until this entry is created, the only line that can have been recorded for this edge is the area's own
            map.set(key, areaLine == 0 ? [value] : [areaLine, value]);
        }
    }

    /** Create and initialise a new `NamedLineResolver` */
    public function new(style:Style, columnAutoRepetitions:Int, rowAutoRepetitions:Int) {
        columnLines = new StringMap();
        rowLines = new StringMap();
        areas = new StringMap();

        // The size of the area template may be larger than the extents of the named areas
        // due to unnamed (`.`) cells, so it is taken from the style rather than being derived
        // from the areas themselves.
        areaColumnCountValue = style.gridTemplateAreaColumnCount();
        areaRowCountValue = style.gridTemplateAreaRowCount();
        final templateAreas = style.gridTemplateAreas;
        if (templateAreas != null) {
            for (area in templateAreas.areas) {
                final lines = new AreaLines();
                lines.rowStart = area.rowStart;
                lines.rowEnd = area.rowEnd;
                lines.columnStart = area.columnStart;
                lines.columnEnd = area.columnEnd;
                areas.set(area.name, lines);
            }
        }

        collectLineNames(style.gridTemplateColumns, style.gridTemplateColumnNames, columnAutoRepetitions, Column, columnLines,
            columnLineNamePairLines, columnLineNamePairNames);
        collectLineNames(style.gridTemplateRows, style.gridTemplateRowNames, rowAutoRepetitions, Row, rowLines, rowLineNamePairLines,
            rowLineNamePairNames);

        // Sort and dedup lines for each name
        sortAndDedup(columnLines);
        sortAndDedup(rowLines);
    }

    function collectLineNames(tracks:Array<GridTemplateComponent>, lineNamesList:Array<Array<String>>, autoRepetitions:Int, axis:GridAreaAxis,
            lines:StringMap<Array<Int>>, pairLines:Array<Int>, pairNames:Array<String>):Void {
        var currentLine = 0;
        var trackIndex = 0;
        for (lineNames in lineNamesList) {
            currentLine += 1;
            for (lineName in lineNames) {
                pairLines.push(currentLine);
                pairNames.push(lineName);
                upsertLineNameMap(lines, areas, axis, lineName, currentLine);
            }

            final track = trackIndex < tracks.length ? tracks[trackIndex] : null;
            trackIndex++;
            if (track != null) {
                switch track {
                    case Repeat(repeat):
                        final repeatCount = switch repeat.count {
                            case Count(count): count;
                            case AutoFill | AutoFit: autoRepetitions;
                        }

                        // Line name sets are positional: set `i` names the `i`th line of each
                        // repetition, and the final line name set of each repetition collapses
                        // with the first line name set of the following one. An empty list means
                        // the repetition's lines are unnamed; any other length must be exactly
                        // `track_count + 1` (one set per line, including both edge lines).
                        final lineNameSetCount = repeat.lineNames.length;
                        final linesPerRepetition = repeat.trackCount();
                        if (!(lineNameSetCount == 0 || lineNameSetCount == linesPerRepetition + 1))
                            throw 'grid template repetition must have no line name sets or exactly track count + 1 of them ($linesPerRepetition tracks but $lineNameSetCount line name sets)';

                        for (_ in 0...repeatCount) {
                            var line = currentLine;
                            for (lineNameSet in repeat.lineNames) {
                                for (lineName in lineNameSet) {
                                    pairLines.push(line);
                                    pairNames.push(lineName);
                                    upsertLineNameMap(lines, areas, axis, lineName, line);
                                }
                                line++;
                            }
                            currentLine += linesPerRepetition;

                            // Names for lines beyond the maximum track limit are never resolvable:
                            // stop generating them (the explicit grid is clamped to MAX_GRID_TRACKS)
                            if (currentLine > GridCoordinates.MAX_GRID_TRACKS)
                                break;
                        }
                        // Last line name set collapses with following line name set
                        if (repeatCount > 0)
                            currentLine = currentLine > 0 ? currentLine - 1 : 0;
                    case Single(_):
                }
            }
        }
    }

    static function sortAndDedup(map:StringMap<Array<Int>>):Void {
        for (key in map.keys()) {
            final lines = map.get(key);
            lines.sort((a, b) -> a - b);
            var write = 0;
            for (i in 0...lines.length) {
                if (i == 0 || lines[i] != lines[write - 1]) {
                    lines[write] = lines[i];
                    write++;
                }
            }
            lines.resize(write);
        }
    }

    /**
     * Build the per-line name groups of the explicit grid in the passed axis as a
     * `GridLineNames`, with `repeat()`s expanded. Only names given explicitly in the track
     * template are included; the implicit `<name>-start`/`<name>-end` names generated by
     * `grid-template-areas` are omitted (matching the resolved value of
     * `grid-template-rows`/`grid-template-columns` in browsers) but remain resolvable for
     * placement via `GridLineNames.resolveLineNames`.
     *
     * Line indices are relative to the explicit grid (line 0 = start of the first explicit track).
     */
    public function detailedLineNames(axis:AbsoluteAxis):GridLineNames {
        final pairLines = axis == Horizontal ? columnLineNamePairLines : rowLineNamePairLines;
        final pairNames = axis == Horizontal ? columnLineNamePairNames : rowLineNamePairNames;
        final explicitTrackCount = axis == Horizontal ? explicitColumnCount : explicitRowCount;

        if (pairLines.length == 0)
            return new GridLineNames();

        // Stable sort by line number preserves the source order of names within each line
        final order = [for (i in 0...pairLines.length) i];
        haxe.ds.ArraySort.sort(order, (a, b) -> pairLines[a] - pairLines[b]);

        final lineCount = explicitTrackCount + 1;
        final lineNames = GridLineNames.withCapacity();
        var pairIndex = 0;
        for (line in 1...(lineCount + 1)) {
            lineNames.startLine();
            while (pairIndex < order.length) {
                final pairLine = pairLines[order[pairIndex]];
                if (pairLine != line)
                    break;
                final name = pairNames[order[pairIndex]];
                pairIndex++;
                if (!lineNames.currentLineContains(name))
                    lineNames.pushName(name);
            }
        }
        return lineNames;
    }

    /** Resolve named lines for both the `start` and `end` of a row-axis grid placement */
    public inline function resolveRowNames(line:LineOf<GridPlacement>):LineOf<GenericGridPlacement> {
        return resolveLineNames(line, Row);
    }

    /** Resolve named lines for both the `start` and `end` of a column-axis grid placement */
    public inline function resolveColumnNames(line:LineOf<GridPlacement>):LineOf<GenericGridPlacement> {
        return resolveLineNames(line, Column);
    }

    /** Resolve named lines for both the `start` and `end` of a grid placement */
    public function resolveLineNames(line:LineOf<GridPlacement>, axis:GridAreaAxis):LineOf<GenericGridPlacement> {
        final lines = axis == Row ? rowLines : columnLines;
        final explicitTrackCount = axis == Row ? explicitRowCount : explicitColumnCount;
        return new NamedLineResolverAxis(lines, areas, axis, explicitTrackCount).resolveLineNames(line);
    }

    /**
     * Move the row and column line-name maps into the detailed grid information, and return the grid area map
     * for the same purpose
     */
    public function populateDetailedLineResolvers(rows:GridLineNames, columns:GridLineNames):StringMap<AreaLines> {
        rows.resolver = rowLines;
        columns.resolver = columnLines;
        return areas;
    }

    /** Get the number of columns defined by the grid areas */
    public inline function areaColumnCount():Int {
        return areaColumnCountValue;
    }

    /** Get the number of rows defined by the grid areas */
    public inline function areaRowCount():Int {
        return areaRowCountValue;
    }

    /** Set the number of columns in the explicit grid */
    public inline function setExplicitColumnCount(count:Int):Void {
        explicitColumnCount = count;
    }

    /** Set the number of rows in the explicit grid */
    public inline function setExplicitRowCount(count:Int):Void {
        explicitRowCount = count;
    }

}
