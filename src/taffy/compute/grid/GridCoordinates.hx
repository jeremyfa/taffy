// Ported from taffy 0.15.0: src/compute/grid/types/coordinates.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.grid;

/**
 * Taffy uses two coordinate systems to refer to grid lines (the gaps/gutters between rows/columns).
 * Both are represented by plain `Int`s in this port:
 *
 * "CSS Grid Line" coordinates (Rust `GridLine`) are those used in grid-row/grid-column in the CSS grid spec:
 *   - The line at left hand (or top) edge of the explicit grid is line 1 (and counts up from there)
 *   - The line at the right hand (or bottom) edge of the explicit grid is -1 (and counts down from there)
 *   - 0 is not a valid index
 *
 * "OriginZero" coordinates (Rust `OriginZeroLine`) are a normalized form:
 *   - The line at left hand (or top) edge of the explicit grid is line 0
 *   - The next line to the right (or down) is 1, and so on
 *   - The next line to the left (or up) is -1, and so on
 */
class GridCoordinates {

    /**
     * The maximum number of tracks in each direction from the start of the explicit grid (line 0 in
     * OriginZero coordinates), and the maximum span of a single grid item. Grids larger than this limit are clamped.
     *
     * See: https://www.w3.org/TR/css-grid-1/#overlarge-grids
     */
    public static inline final MAX_GRID_TRACKS:Int = 10000;

    /** The lowest valid grid line in OriginZero coordinates */
    public static inline final MIN_OZ_LINE:Int = -10000;

    /** The highest valid grid line in OriginZero coordinates */
    public static inline final MAX_OZ_LINE:Int = 10000;

    /** Rust `i16::MIN` */
    public static inline final I16_MIN:Int = -32768;

    /** Rust `i16::MAX` */
    public static inline final I16_MAX:Int = 32767;

    /**
     * Convert a CSS Grid Line into OriginZero coordinates using the specified explicit track count.
     * The result is clamped into the limited grid `[-MAX_GRID_TRACKS, MAX_GRID_TRACKS]`
     */
    public static function gridLineIntoOriginZeroLine(line:Int, explicitTrackCount:Int):Int {
        final explicitLineCount = explicitTrackCount + 1;
        final ozLine = if (line > 0) {
            line - 1;
        }
        else if (line < 0) {
            line + explicitLineCount;
        }
        else {
            throw "Grid line of zero is invalid";
        }
        return clampedOriginZeroLine(ozLine);
    }

    /** Create an OriginZero line, clamping the line into the limited grid `[-MAX_GRID_TRACKS, MAX_GRID_TRACKS]` */
    public static inline function clampedOriginZeroLine(line:Int):Int {
        return line < MIN_OZ_LINE ? MIN_OZ_LINE : (line > MAX_OZ_LINE ? MAX_OZ_LINE : line);
    }

    /** Convert an OriginZero line into "CSS Grid Line" coordinates (the inverse of `gridLineIntoOriginZeroLine`) */
    public static inline function originZeroLineIntoGridLine(line:Int, explicitTrackCount:Int):Int {
        final explicitLineCount = explicitTrackCount + 1;
        return line >= 0 ? line + 1 : line - explicitLineCount;
    }

    /** Converts a grid line in OriginZero coordinates into the index of that same grid line in the GridTrackVec. */
    public static function intoTrackVecIndex(line:Int, trackCounts:TrackCounts):Int {
        final index = tryIntoTrackVecIndex(line, trackCounts);
        if (index < 0) {
            if (line > 0)
                throw "OriginZero grid line cannot be more than the number of positive grid lines";
            else
                throw "OriginZero grid line cannot be less than the number of negative grid lines";
        }
        return index;
    }

    /**
     * Converts a grid line in OriginZero coordinates into the index of that same grid line in the GridTrackVec.
     * Returns -1 (Rust `None`) if the line is outside of the implicit grid.
     *
     * This fallible version is used for the placement of absolutely positioned grid items:
     *
     *    If a grid-placement property refers to a non-existent line either by explicitly specifying such a line or by
     *    spanning outside of the existing implicit grid, it is instead treated as specifying auto (instead of creating
     *    new implicit grid lines).
     */
    public static inline function tryIntoTrackVecIndex(line:Int, trackCounts:TrackCounts):Int {
        return if (line < -trackCounts.negativeImplicit) {
            // OriginZero grid line cannot be less than the number of negative grid lines
            -1;
        }
        else if (line > trackCounts.explicit + trackCounts.positiveImplicit) {
            // OriginZero grid line cannot be more than the number of positive grid lines
            -1;
        }
        else {
            2 * (line + trackCounts.negativeImplicit);
        }
    }

    /** The minimum number of negative implicit track there must be if a grid item starts at this line. */
    public static inline function impliedNegativeImplicitTracks(line:Int):Int {
        return line < 0 ? -line : 0;
    }

    /** The minimum number of positive implicit track there must be if a grid item end at this line. */
    public static inline function impliedPositiveImplicitTracks(line:Int, explicitTrackCount:Int):Int {
        return line > explicitTrackCount ? line - explicitTrackCount : 0;
    }

}

/**
 * A pair of integer lines (Rust `Line<OriginZeroLine>`, or `Line<u16>` for GridTrackVec indexes). Immutable.
 */
final class IntLine {

    /** A line with both ends at zero */
    public static final ZERO:IntLine = new IntLine(0, 0);

    public final start:Int;

    public final end:Int;

    public inline function new(start:Int, end:Int) {
        this.start = start;
        this.end = end;
    }

    /** The number of tracks between the start and end lines */
    public inline function span():Int {
        final s = end - start;
        return s > 0 ? s : 0;
    }

    public inline function equals(other:IntLine):Bool {
        return start == other.start && end == other.end;
    }

    public function toString():String {
        return 'Line(start: $start, end: $end)';
    }

}
