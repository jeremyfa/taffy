// Ported from taffy 0.15.0: src/compute/grid/types/grid_track_counts.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.grid;

/**
 * Stores the number of tracks in a given dimension.
 * Stores separately the number of tracks in the implicit and explicit grids.
 *
 * Mutable (the cell occupancy matrix grows it): use `clone()` where Rust copies the struct.
 *
 * Taffy also uses two coordinate systems to refer to grid tracks (rows/columns), which both represent the entire
 * implicit grid, not just the explicit grid:
 *
 *   "CellOccupancyMatrix track indices":
 *       - These are indexes into the CellOccupancyMatrix
 *       - The CellOccupancyMatrix stores only tracks
 *       - 0 is the leftmost track of the implicit grid, and indexes count up there
 *
 *   "GridTrackVec track indices":
 *       - The GridTrackVecs store both lines and tracks, so:
 *           - even indices (0, 2, 4, etc) represent lines
 *           - odd indices (1, 3, 5, etc) represent tracks
 *       - Index 1 is the leftmost track of the implicit grid. Index 3 is the second leftmost track, etc.
 *       - Index 0 is the leftmost grid line. Index 2 is the second leftmost line, etc.
 */
class TrackCounts {

    /** The number of track in the implicit grid before the explicit grid */
    public var negativeImplicit:Int;

    /** The number of tracks in the explicit grid */
    public var explicit:Int;

    /** The number of tracks in the implicit grid after the explicit grid */
    public var positiveImplicit:Int;

    /** Create a TrackCounts instance from raw track count numbers */
    public inline function new(negativeImplicit:Int, explicit:Int, positiveImplicit:Int) {
        this.negativeImplicit = negativeImplicit;
        this.explicit = explicit;
        this.positiveImplicit = positiveImplicit;
    }

    /** Create a TrackCounts instance from raw track count numbers */
    public static inline function fromRaw(negativeImplicit:Int, explicit:Int, positiveImplicit:Int):TrackCounts {
        return new TrackCounts(negativeImplicit, explicit, positiveImplicit);
    }

    /** Count the total number of tracks in the axis */
    public inline function len():Int {
        return negativeImplicit + explicit + positiveImplicit;
    }

    /** The OriginZeroLine representing the start of the implicit grid */
    public inline function implicitStartLine():Int {
        return -negativeImplicit;
    }

    /** The OriginZeroLine representing the end of the implicit grid */
    public inline function implicitEndLine():Int {
        return explicit + positiveImplicit;
    }

    /**
     * Converts a grid line in OriginZero coordinates into the track immediately
     * following that grid line as an index into the CellOccupancyMatrix.
     */
    public inline function ozLineToNextTrack(index:Int):Int {
        return index + negativeImplicit;
    }

    /**
     * Converts a track as an index into the CellOccupancyMatrix into the grid line immediately
     * preceding that track in OriginZero coordinates.
     */
    public inline function trackToPrevOzLine(index:Int):Int {
        return index - negativeImplicit;
    }

    public inline function clone():TrackCounts {
        return new TrackCounts(negativeImplicit, explicit, positiveImplicit);
    }

    public inline function equals(other:TrackCounts):Bool {
        return negativeImplicit == other.negativeImplicit && explicit == other.explicit && positiveImplicit == other.positiveImplicit;
    }

    public function toString():String {
        return 'TrackCounts(negativeImplicit: $negativeImplicit, explicit: $explicit, positiveImplicit: $positiveImplicit)';
    }

}
