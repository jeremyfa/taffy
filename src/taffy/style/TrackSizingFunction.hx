// Ported from taffy 0.15.0: src/style/grid.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * The sizing function for a grid track (row/column)
 *
 * Rust `MinMax<MinTrackSizingFunction, MaxTrackSizingFunction>`: a min and a max track sizing function.
 * Immutable.
 */
final class TrackSizingFunction {

    /** `auto` */
    public static final AUTO:TrackSizingFunction = new TrackSizingFunction(MinTrackSizingFunction.AUTO, MaxTrackSizingFunction.AUTO);

    /** `min-content` */
    public static final MIN_CONTENT:TrackSizingFunction = new TrackSizingFunction(MinTrackSizingFunction.MIN_CONTENT, MaxTrackSizingFunction.MIN_CONTENT);

    /** `max-content` */
    public static final MAX_CONTENT:TrackSizingFunction = new TrackSizingFunction(MinTrackSizingFunction.MAX_CONTENT, MaxTrackSizingFunction.MAX_CONTENT);

    /** A zero length */
    public static final ZERO:TrackSizingFunction = new TrackSizingFunction(MinTrackSizingFunction.ZERO, MaxTrackSizingFunction.ZERO);

    /** The min track sizing function */
    public final min:MinTrackSizingFunction;

    /** The max track sizing function */
    public final max:MaxTrackSizingFunction;

    public inline function new(min:MinTrackSizingFunction, max:MaxTrackSizingFunction) {
        this.min = min;
        this.max = max;
    }

    /** Extract the min track sizing function */
    public inline function minSizingFunction():MinTrackSizingFunction {
        return min;
    }

    /** Extract the max track sizing function */
    public inline function maxSizingFunction():MaxTrackSizingFunction {
        return max;
    }

    /** Determine whether at least one of the components ("min" and "max") are fixed sizing function */
    public inline function hasFixedComponent():Bool {
        return min.intoRaw().isLengthOrPercentage() || max.intoRaw().isLengthOrPercentage();
    }

    /** An absolute length */
    public static inline function length(value:Float):TrackSizingFunction {
        return new TrackSizingFunction(MinTrackSizingFunction.length(value), MaxTrackSizingFunction.length(value));
    }

    /** A percentage (0.5 is 50%) */
    public static inline function percent(value:Float):TrackSizingFunction {
        return new TrackSizingFunction(MinTrackSizingFunction.percent(value), MaxTrackSizingFunction.percent(value));
    }

    /** `minmax(auto, <value>fr)` */
    public static inline function fr(flex:Float):TrackSizingFunction {
        return new TrackSizingFunction(MinTrackSizingFunction.AUTO, MaxTrackSizingFunction.fr(flex));
    }

    /** `fit-content(<argument>)` */
    public static inline function fitContent(argument:LengthPercentage):TrackSizingFunction {
        return new TrackSizingFunction(MinTrackSizingFunction.AUTO, MaxTrackSizingFunction.fitContent(argument));
    }

    /** Convert from a `LengthPercentage` */
    public static inline function fromLengthPercentage(input:LengthPercentage):TrackSizingFunction {
        return new TrackSizingFunction(MinTrackSizingFunction.fromLengthPercentage(input), MaxTrackSizingFunction.fromLengthPercentage(input));
    }

    /** Convert from a `LengthPercentageAuto` */
    public static inline function fromLengthPercentageAuto(input:LengthPercentageAuto):TrackSizingFunction {
        return new TrackSizingFunction(MinTrackSizingFunction.fromLengthPercentageAuto(input), MaxTrackSizingFunction.fromLengthPercentageAuto(input));
    }

    /** Convert from a `Dimension` */
    public static inline function fromDimension(input:Dimension):TrackSizingFunction {
        return new TrackSizingFunction(MinTrackSizingFunction.fromDimension(input), MaxTrackSizingFunction.fromDimension(input));
    }

    public inline function equals(other:TrackSizingFunction):Bool {
        return min.equals(other.min) && max.equals(other.max);
    }

    public function toString():String {
        return 'minmax(${min.toString()}, ${max.toString()})';
    }

}
