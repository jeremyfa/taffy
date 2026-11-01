// Ported from taffy 0.15.0: src/compute/grid/types/named.rs (GridLineNames)
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.grid;

import haxe.ds.StringMap;
import taffy.geometry.LineOf;
import taffy.style.GridAreaAxis;
import taffy.style.GridPlacement;

/**
 * The names of each explicit grid line in a single axis, stored in CSR (compressed sparse
 * row) format: a single flat array of names plus an array of offsets into it (one more offset
 * than there are lines). The names of line `i` (0-indexed) are `names[offsets[i]...offsets[i + 1]]`.
 *
 * Line indices here are relative to the explicit grid; `DetailedGridTracksInfo` provides accessors with indices
 * relative to the full grid (including implicit tracks).
 *
 * A grid with no named lines is represented by two empty arrays (see `isEmpty`).
 */
class GridLineNames {

    static final EMPTY:Array<String> = [];

    /** The names of every grid line in the axis, concatenated in line order */
    final names:Array<String>;

    /**
     * Offsets into `names`: line `i`'s names are `names[offsets[i]...offsets[i + 1]]`.
     * Either empty (no named lines) or of length `line count + 1`.
     */
    final offsets:Array<Int>;

    /** Named line lookup used to resolve arbitrary grid placements */
    public var resolver:StringMap<Array<Int>>;

    public function new() {
        names = [];
        offsets = [];
        resolver = new StringMap();
    }

    /** Create an empty `GridLineNames` ready to receive lines */
    public static function withCapacity():GridLineNames {
        final result = new GridLineNames();
        result.offsets.push(0);
        return result;
    }

    /** Start a new (initially empty) line */
    public inline function startLine():Void {
        offsets.push(names.length);
    }

    /** Append a name to the current (last) line */
    public inline function pushName(name:String):Void {
        names.push(name);
        offsets[offsets.length - 1] = names.length;
    }

    /** Whether the current (last) line already contains the passed name */
    public function currentLineContains(name:String):Bool {
        final count = lineCount();
        if (count == 0)
            return false;
        final start = offsets[count - 1];
        final end = offsets[count];
        for (i in start...end) {
            if (names[i] == name)
                return true;
        }
        return false;
    }

    /** Resolve named lines and spans using the retained line-name map and the passed grid area map */
    public function resolveLineNames(line:LineOf<GridPlacement>, areas:StringMap<NamedLineResolver.AreaLines>, axis:GridAreaAxis,
            explicitTrackCount:Int):LineOf<GenericGridPlacement> {
        return new NamedLineResolver.NamedLineResolverAxis(resolver, areas, axis, explicitTrackCount).resolveLineNames(line);
    }

    /** Whether the axis has any named lines at all */
    public inline function isEmpty():Bool {
        return names.length == 0;
    }

    /** The number of grid lines represented (zero if the grid has no named lines) */
    public inline function lineCount():Int {
        return offsets.length > 0 ? offsets.length - 1 : 0;
    }

    /**
     * The names of the line with the passed 0-indexed line index.
     * Returns an empty array if the line has no names or the index is out of range.
     */
    public function line(lineIndex:Int):Array<String> {
        if (lineIndex < 0 || lineIndex + 1 >= offsets.length)
            return EMPTY;
        final start = offsets[lineIndex];
        final end = offsets[lineIndex + 1];
        return start == end ? EMPTY : names.slice(start, end);
    }

    /** The name groups of each grid line in line order */
    public function iter():Array<Array<String>> {
        return iterPadded(0, 0);
    }

    /**
     * The name groups of each grid line in line order, additionally yielding `leadingEmpty`
     * empty groups before the stored lines and `trailingEmpty` empty groups after them
     * (representing unnamed implicit grid lines)
     */
    public function iterPadded(leadingEmpty:Int, trailingEmpty:Int):Array<Array<String>> {
        final result:Array<Array<String>> = [];
        for (_ in 0...leadingEmpty)
            result.push([]);
        for (i in 0...lineCount())
            result.push(names.slice(offsets[i], offsets[i + 1]));
        for (_ in 0...trailingEmpty)
            result.push([]);
        return result;
    }

}
