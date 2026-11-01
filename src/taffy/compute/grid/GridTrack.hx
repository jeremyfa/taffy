// Ported from taffy 0.15.0: src/compute/grid/types/grid_track.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.grid;

import taffy.style.LengthPercentage;
import taffy.style.MaxTrackSizingFunction;
import taffy.style.MinTrackSizingFunction;
import taffy.util.Sys;
import taffy.util.OptionalFloat;

/**
 * Whether a GridTrack represents an actual track or a gutter.
 */
enum abstract GridTrackKind(Int) {

    /** Track is an actual track */
    var Track = 0;

    /** Track is a gutter (aka grid line) (aka gap) */
    var Gutter = 1;

}

/**
 * Internal sizing information for a single grid track (row/column)
 * Gutters between tracks are sized similarly to actual tracks, so they
 * are also represented by this class
 */
class GridTrack {

    /** Whether the track is a full track, a gutter, or a placeholder that has not yet been initialised */
    public var kind:GridTrackKind;

    /**
     * Whether the track is a collapsed track/gutter. Collapsed tracks are effectively treated as if
     * they don't exist for the purposes of grid sizing. Gutters between collapsed tracks are also collapsed.
     */
    public var isCollapsed:Bool = false;

    /** The minimum track sizing function of the track */
    public var minTrackSizingFunction:MinTrackSizingFunction;

    /** The maximum track sizing function of the track */
    public var maxTrackSizingFunction:MaxTrackSizingFunction;

    /** The distance of the start of the track from the start of the grid container */
    public var offset:Float = 0.0;

    /** The size (width/height as applicable) of the track */
    public var baseSize:Float = 0.0;

    /** A temporary scratch value when sizing tracks. Note: can be infinity */
    public var growthLimit:Float = 0.0;

    /**
     * A temporary scratch value when sizing tracks. Is used as an additional amount to add to the
     * estimate for the available space in the opposite axis when content sizing items
     */
    public var contentAlignmentAdjustment:Float = 0.0;

    /** A temporary scratch value when "distributing space" to avoid clobbering planned increase variable */
    public var itemIncurredIncrease:Float = 0.0;

    /** A temporary scratch value when "distributing space" to avoid clobbering the main variable */
    public var baseSizePlannedIncrease:Float = 0.0;

    /** A temporary scratch value when "distributing space" to avoid clobbering the main variable */
    public var growthLimitPlannedIncrease:Float = 0.0;

    /**
     * A temporary scratch value when "distributing space"
     * See: https://www.w3.org/TR/css3-grid-layout/#infinitely-growable
     */
    public var infinitelyGrowable:Bool = false;

    /**
     * The resolved `fit-content()` limit of the max track sizing function (infinity if it is not `fit-content()`
     * or the limit cannot be resolved). Resolved once per track sizing pass by `resolveFitContentLimit`.
     */
    public var fitContentLimitValue:Float = Math.POSITIVE_INFINITY;

    /** GridTrack constructor with all configuration parameters for the other constructors exposed */
    public inline function new(kind:GridTrackKind, minTrackSizingFunction:MinTrackSizingFunction, maxTrackSizingFunction:MaxTrackSizingFunction) {
        this.kind = kind;
        this.minTrackSizingFunction = minTrackSizingFunction;
        this.maxTrackSizingFunction = maxTrackSizingFunction;
    }

    /** Create new GridTrack representing an actual track (not a gutter) */
    public static inline function track(minTrackSizingFunction:MinTrackSizingFunction, maxTrackSizingFunction:MaxTrackSizingFunction):GridTrack {
        return new GridTrack(Track, minTrackSizingFunction, maxTrackSizingFunction);
    }

    /** Create a new GridTrack representing a gutter */
    public static inline function gutter(size:LengthPercentage):GridTrack {
        return new GridTrack(Gutter, MinTrackSizingFunction.fromLengthPercentage(size), MaxTrackSizingFunction.fromLengthPercentage(size));
    }

    /**
     * Mark a GridTrack as collapsed. Also sets both of the track's sizing functions
     * to fixed zero-sized sizing functions.
     */
    public function collapse():Void {
        isCollapsed = true;
        minTrackSizingFunction = MinTrackSizingFunction.ZERO;
        maxTrackSizingFunction = MaxTrackSizingFunction.ZERO;
        fitContentLimitValue = Math.POSITIVE_INFINITY;
    }

    /** Returns true if the track is flexible (has a Flex MaxTrackSizingFunction), else false. */
    public inline function isFlexible():Bool {
        return maxTrackSizingFunction.isFr();
    }

    /** Returns true if the track uses a percentage sizing function */
    public inline function usesPercentage():Bool {
        return minTrackSizingFunction.usesPercentage() || maxTrackSizingFunction.usesPercentage();
    }

    /** Returns true if the track has an intrinsic min and or max sizing function */
    public inline function hasIntrinsicSizingFunction():Bool {
        return minTrackSizingFunction.isIntrinsic() || maxTrackSizingFunction.isIntrinsic();
    }

    /**
     * Cache the `fit-content()` limit of the max track sizing function (if any), resolved against the
     * container's inner size in this axis. Percentage limits resolve to infinity if that size is
     * indefinite, as do tracks which are not `fit-content()`.
     */
    public inline function resolveFitContentLimit(axisInnerNodeSize:OptionalFloat):Void {
        final limit = maxTrackSizingFunction.fitContentLimit(axisInnerNodeSize);
        fitContentLimitValue = limit.isSome() ? limit.unwrap() : Math.POSITIVE_INFINITY;
    }

    /** Returns the resolved `fit-content()` limit of the track (infinity if the track is not `fit-content()`) */
    public inline function fitContentLimit():Float {
        return fitContentLimitValue;
    }

    /** Returns the track's growth limit, capped by its `fit-content()` limit (if any) */
    public inline function fitContentLimitedGrowthLimit():Float {
        return Sys.f32Min(growthLimit, fitContentLimitValue);
    }

    /** Returns the track's flex factor if it is a flex track, else 0. */
    public inline function flexFactor():Float {
        return maxTrackSizingFunction.isFr() ? maxTrackSizingFunction.value() : 0.0;
    }

}
