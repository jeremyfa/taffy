// Ported from taffy 0.15.0: src/style/grid.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * A typed representation of a `repeat(..)` in `grid-template-*` value
 */
class GridTemplateRepetition {

    /** The number of the times the repeat is repeated */
    public final count:RepetitionCount;

    /** The tracks to repeat */
    public final tracks:Array<TrackSizingFunction>;

    /**
     * The line names for the repeated tracks
     *
     * Line name sets are positional: set `i` names the `i`th line of each repetition. This must
     * either be empty (all lines are unnamed) or contain exactly `tracks.length + 1` sets (one set
     * per line, including both edge lines; sets may be empty).
     */
    public final lineNames:Array<Array<String>>;

    public function new(count:RepetitionCount, tracks:Array<TrackSizingFunction>, ?lineNames:Array<Array<String>>) {
        this.count = count;
        this.tracks = tracks;
        this.lineNames = lineNames != null ? lineNames : [];
    }

    /** Returns the number of repeated tracks (saturating at 65535) */
    public inline function trackCount():Int {
        return tracks.length < 65535 ? tracks.length : 65535;
    }

}
