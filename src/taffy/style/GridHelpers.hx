// Ported from taffy 0.15.0: src/style_helpers.rs (grid helpers)
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

import taffy.geometry.LineOf;

/**
 * Helper functions which make it easier to create grid style values
 */
class GridHelpers {

    /** Returns a repeated track definition (`repeat(count, tracks...)`) */
    public static inline function repeat(count:RepetitionCount, tracks:Array<TrackSizingFunction>):GridTemplateComponent {
        return GridTemplateComponent.Repeat(new GridTemplateRepetition(count, tracks, []));
    }

    /** Returns a track definition repeated `count` times */
    public static inline function repeatCount(count:Int, tracks:Array<TrackSizingFunction>):GridTemplateComponent {
        return repeat(RepetitionCount.Count(count), tracks);
    }

    /** Returns a grid template containing `count` evenly sized tracks */
    public static function evenlySizedTracks(count:Int):Array<GridTemplateComponent> {
        return [repeatCount(count, [flex(1.0)])];
    }

    /**
     * Specifies a grid line to place a grid item between in CSS Grid Line coordinates:
     *  - Positive indices count upwards from the start (top or left) of the explicit grid
     *  - Negative indices count downwards from the end (bottom or right) of the explicit grid
     *  - ZERO IS INVALID index, and will be treated as a GridPlacement.Auto.
     */
    public static inline function line(index:Int):GridPlacement {
        return GridPlacement.Line(index);
    }

    /** A `Line<GridPlacement>` starting at the passed line (and with an `auto` end) */
    public static inline function lineLine(index:Int):LineOf<GridPlacement> {
        return new LineOf<GridPlacement>(GridPlacement.Line(index), GridPlacement.Auto);
    }

    /** Returns a `GridPlacement.Span` */
    public static inline function span(span:Int):GridPlacement {
        return GridPlacement.Span(span);
    }

    /** A `Line<GridPlacement>` with a span start (and an `auto` end) */
    public static inline function spanLine(span:Int):LineOf<GridPlacement> {
        return new LineOf<GridPlacement>(GridPlacement.Span(span), GridPlacement.Auto);
    }

    /** A `Line<GridPlacement>` with both ends `auto` */
    public static inline function autoLine():LineOf<GridPlacement> {
        return new LineOf<GridPlacement>(GridPlacement.Auto, GridPlacement.Auto);
    }

    /** Returns a track sizing function with min value of min and max value of max */
    public static inline function minmax(min:MinTrackSizingFunction, max:MaxTrackSizingFunction):TrackSizingFunction {
        return new TrackSizingFunction(min, max);
    }

    /** Shorthand for minmax(0, Nfr). Probably what you want if you want exactly evenly sized tracks. */
    public static inline function flex(flexFraction:Float):TrackSizingFunction {
        return new TrackSizingFunction(MinTrackSizingFunction.ZERO, MaxTrackSizingFunction.fr(flexFraction));
    }

    /** A `fr` track (`minmax(auto, Nfr)`) */
    public static inline function fr(flexFraction:Float):TrackSizingFunction {
        return TrackSizingFunction.fr(flexFraction);
    }

    /** A fixed length track */
    public static inline function length(value:Float):TrackSizingFunction {
        return TrackSizingFunction.length(value);
    }

    /** A percentage track (0.5 is 50%) */
    public static inline function percent(value:Float):TrackSizingFunction {
        return TrackSizingFunction.percent(value);
    }

    /** An `auto` track */
    public static inline function auto():TrackSizingFunction {
        return TrackSizingFunction.AUTO;
    }

    /** A `min-content` track */
    public static inline function minContent():TrackSizingFunction {
        return TrackSizingFunction.MIN_CONTENT;
    }

    /** A `max-content` track */
    public static inline function maxContent():TrackSizingFunction {
        return TrackSizingFunction.MAX_CONTENT;
    }

    /** A `fit-content(...)` track */
    public static inline function fitContent(argument:LengthPercentage):TrackSizingFunction {
        return TrackSizingFunction.fitContent(argument);
    }

    /** Wrap a track sizing function as a single (non-repeated) template component */
    public static inline function single(track:TrackSizingFunction):GridTemplateComponent {
        return GridTemplateComponent.Single(track);
    }

}
