// Ported from taffy 0.15.0: src/style/grid.rs (GenericGridPlacement, OriginZeroGridPlacement, NonNamedGridPlacement)
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.grid;

import taffy.compute.grid.GridCoordinates.IntLine;

import taffy.geometry.AbsoluteAxis;
import taffy.geometry.LineOf;
import taffy.style.GridPlacement;

/**
 * A grid line placement specification which is generic over the coordinate system that it uses to define
 * grid line positions (named lines are already resolved).
 *
 * Used both as Rust `NonNamedGridPlacement` (lines in "CSS Grid Line" coordinates) and as Rust
 * `OriginZeroGridPlacement` (lines in "OriginZero" coordinates). Immutable.
 */
final class GenericGridPlacement {

    /** Place item according to the auto-placement algorithm */
    public static inline final AUTO_KIND:Int = 0;

    /** Place item at specified line (column or row) index */
    public static inline final LINE_KIND:Int = 1;

    /** Item should span specified number of tracks (columns or rows) */
    public static inline final SPAN_KIND:Int = 2;

    /** The shared `Auto` placement */
    public static final AUTO:GenericGridPlacement = new GenericGridPlacement(AUTO_KIND, 0);

    /** One of `AUTO_KIND`, `LINE_KIND` or `SPAN_KIND` */
    public final kind:Int;

    /** The line (for `LINE_KIND`) or the span (for `SPAN_KIND`) */
    public final value:Int;

    inline function new(kind:Int, value:Int) {
        this.kind = kind;
        this.value = value;
    }

    /** A placement at the given line */
    public static inline function line(line:Int):GenericGridPlacement {
        return new GenericGridPlacement(LINE_KIND, line);
    }

    /** A placement spanning the given number of tracks */
    public static inline function span(span:Int):GenericGridPlacement {
        return new GenericGridPlacement(SPAN_KIND, span);
    }

    public inline function isAuto():Bool {
        return kind == AUTO_KIND;
    }

    public inline function isLine():Bool {
        return kind == LINE_KIND;
    }

    public inline function isSpan():Bool {
        return kind == SPAN_KIND;
    }

    public inline function equals(other:GenericGridPlacement):Bool {
        return kind == other.kind && value == other.value;
    }

    public function toString():String {
        return switch kind {
            case AUTO_KIND: "Auto";
            case LINE_KIND: 'Line($value)';
            case _: 'Span($value)';
        }
    }

    /** Clamp a span between 1 (a zero span is invalid and treated as 1) and the maximum track limit */
    static inline function clampSpan(span:Int):Int {
        return span < 1 ? 1 : (span > GridCoordinates.MAX_GRID_TRACKS ? GridCoordinates.MAX_GRID_TRACKS : span);
    }

    /**
     * Convert a `NonNamedGridPlacement` (CSS Grid Line coordinates) into an `OriginZeroGridPlacement`
     * (Rust `NonNamedGridPlacement::into_origin_zero_placement`)
     */
    public function intoOriginZeroPlacement(explicitTrackCount:Int):GenericGridPlacement {
        return switch kind {
            case AUTO_KIND: AUTO;
            // Spans are clamped between 1 (a zero span is an invalid value which is treated as 1)
            // and the maximum track limit (https://www.w3.org/TR/css-grid-1/#overlarge-grids)
            case SPAN_KIND: span(clampSpan(value));
            // Grid line zero is an invalid index, so it gets treated as Auto
            // See: https://developer.mozilla.org/en-US/docs/Web/CSS/grid-row-start#values
            case _: value == 0 ? AUTO : line(GridCoordinates.gridLineIntoOriginZeroLine(value, explicitTrackCount));
        }
    }

    /**
     * Convert a `GridPlacement` into an `OriginZeroGridPlacement`, treating named placements as `Auto`
     * (Rust `GridPlacement::into_origin_zero_placement_ignoring_named`)
     */
    public static function fromGridPlacementIgnoringNamed(placement:GridPlacement, explicitTrackCount:Int):GenericGridPlacement {
        return switch placement {
            case Auto: AUTO;
            // Spans are clamped between 1 (a zero span is an invalid value which is treated as 1)
            // and the maximum track limit (https://www.w3.org/TR/css-grid-1/#overlarge-grids)
            case Span(s): span(clampSpan(s));
            // Grid line zero is an invalid index, so it gets treated as Auto
            case Line(l): l == 0 ? AUTO : line(GridCoordinates.gridLineIntoOriginZeroLine(l, explicitTrackCount));
            case NamedLine(_, _): AUTO;
            case NamedSpan(_, _): AUTO;
        }
    }

}

/**
 * Helpers for `Line<GenericGridPlacement>` (Rust `impl Line<GenericGridPlacement<T>>` blocks)
 */
class PlacementLine {

    /** Rust `Line<GridPlacement>::into_origin_zero_ignoring_named` */
    public static inline function fromGridPlacementLineIgnoringNamed(line:LineOf<GridPlacement>, explicitTrackCount:Int):LineOf<GenericGridPlacement> {
        return new LineOf<GenericGridPlacement>(
            GenericGridPlacement.fromGridPlacementIgnoringNamed(line.start, explicitTrackCount),
            GenericGridPlacement.fromGridPlacementIgnoringNamed(line.end, explicitTrackCount)
        );
    }

    /**
     * Whether the track position is definite in this axis (or the item will need auto placement)
     * (Rust `Line<GridPlacement>::is_definite`)
     * The track position is definite if least one of the start and end positions is a NON-ZERO track index
     * (0 is an invalid line in GridLine coordinates, and falls back to "auto" which is indefinite)
     */
    public static function gridPlacementLineIsDefinite(line:LineOf<GridPlacement>):Bool {
        switch line.start {
            case Line(l) if (l != 0): return true;
            case _:
        }
        switch line.end {
            case Line(l) if (l != 0): return true;
            case _:
        }
        switch line.start {
            case NamedLine(_, _): return true;
            case _:
        }
        switch line.end {
            case NamedLine(_, _): return true;
            case _:
        }
        return false;
    }

    /**
     * Whether a `Line<NonNamedGridPlacement>` (CSS Grid Line coordinates) is definite: at least one of the start
     * and end positions is a NON-ZERO track index
     */
    public static inline function nonNamedIsDefinite(line:LineOf<GenericGridPlacement>):Bool {
        return (line.start.kind == GenericGridPlacement.LINE_KIND && line.start.value != 0)
            || (line.end.kind == GenericGridPlacement.LINE_KIND && line.end.value != 0);
    }

    /** Convert a `Line<NonNamedGridPlacement>` into a `Line<OriginZeroGridPlacement>` (Rust `into_origin_zero`) */
    public static inline function intoOriginZero(line:LineOf<GenericGridPlacement>, explicitTrackCount:Int):LineOf<GenericGridPlacement> {
        return new LineOf<GenericGridPlacement>(line.start.intoOriginZeroPlacement(explicitTrackCount), line.end.intoOriginZeroPlacement(explicitTrackCount));
    }

    /**
     * Whether a `Line<OriginZeroGridPlacement>` is definite (or the item will need auto placement):
     * at least one of the start and end positions is a track index
     */
    public static inline function isDefinite(line:LineOf<GenericGridPlacement>):Bool {
        return line.start.kind == GenericGridPlacement.LINE_KIND || line.end.kind == GenericGridPlacement.LINE_KIND;
    }

    /**
     * Resolves the span for an indefinite placement (a placement that does not consist of two `Line`s).
     * Throws if called on a definite placement
     */
    public static function indefiniteSpan(line:LineOf<GenericGridPlacement>):Int {
        final start = line.start;
        final end = line.end;
        return switch [start.kind, end.kind] {
            case [GenericGridPlacement.LINE_KIND, GenericGridPlacement.AUTO_KIND]: 1;
            case [GenericGridPlacement.AUTO_KIND, GenericGridPlacement.LINE_KIND]: 1;
            case [GenericGridPlacement.AUTO_KIND, GenericGridPlacement.AUTO_KIND]: 1;
            case [GenericGridPlacement.LINE_KIND, GenericGridPlacement.SPAN_KIND]: end.value;
            case [GenericGridPlacement.SPAN_KIND, GenericGridPlacement.LINE_KIND]: start.value;
            case [GenericGridPlacement.SPAN_KIND, GenericGridPlacement.AUTO_KIND]: start.value;
            case [GenericGridPlacement.AUTO_KIND, GenericGridPlacement.SPAN_KIND]: end.value;
            case [GenericGridPlacement.SPAN_KIND, GenericGridPlacement.SPAN_KIND]: start.value;
            case _: throw "indefiniteSpan should only be called on indefinite grid tracks";
        }
    }

    /**
     * If at least one of the of the start and end positions is a track index then the other end can be resolved
     * into a track index purely based on the information contained with the placement specification
     */
    public static function resolveDefiniteGridLines(line:LineOf<GenericGridPlacement>):IntLine {
        final start = line.start;
        final end = line.end;
        return switch [start.kind, end.kind] {
            case [GenericGridPlacement.LINE_KIND, GenericGridPlacement.LINE_KIND]:
                final line1 = start.value;
                final line2 = end.value;
                if (line1 == line2)
                    new IntLine(line1, line1 + 1);
                else
                    new IntLine(line1 < line2 ? line1 : line2, line1 > line2 ? line1 : line2);
            case [GenericGridPlacement.LINE_KIND, GenericGridPlacement.SPAN_KIND]: new IntLine(start.value, start.value + end.value);
            case [GenericGridPlacement.LINE_KIND, GenericGridPlacement.AUTO_KIND]: new IntLine(start.value, start.value + 1);
            case [GenericGridPlacement.SPAN_KIND, GenericGridPlacement.LINE_KIND]: new IntLine(end.value - start.value, end.value);
            case [GenericGridPlacement.AUTO_KIND, GenericGridPlacement.LINE_KIND]: new IntLine(end.value - 1, end.value);
            case _: throw "resolveDefiniteGridLines should only be called on definite grid tracks";
        }
    }

    /**
     * For absolutely positioned items:
     *   - Tracks resolve to definite tracks
     *   - For Spans:
     *      - If the other position is a Track, they resolve to a definite track relative to the other track
     *      - Else resolve to null
     *   - Auto resolves to null
     *
     * When finally positioning the item, a value of null means that the item's grid area is bounded by the grid
     * container's border box on that side.
     */
    public static function resolveAbsolutelyPositionedGridTracks(line:LineOf<GenericGridPlacement>):LineOf<Null<Int>> {
        final start = line.start;
        final end = line.end;
        return switch [start.kind, end.kind] {
            case [GenericGridPlacement.LINE_KIND, GenericGridPlacement.LINE_KIND]:
                final track1 = start.value;
                final track2 = end.value;
                if (track1 == track2)
                    new LineOf<Null<Int>>(track1, track1 + 1);
                else
                    new LineOf<Null<Int>>(track1 < track2 ? track1 : track2, track1 > track2 ? track1 : track2);
            case [GenericGridPlacement.LINE_KIND, GenericGridPlacement.SPAN_KIND]: new LineOf<Null<Int>>(start.value, start.value + end.value);
            case [GenericGridPlacement.LINE_KIND, GenericGridPlacement.AUTO_KIND]: new LineOf<Null<Int>>(start.value, null);
            case [GenericGridPlacement.SPAN_KIND, GenericGridPlacement.LINE_KIND]: new LineOf<Null<Int>>(end.value - start.value, end.value);
            case [GenericGridPlacement.AUTO_KIND, GenericGridPlacement.LINE_KIND]: new LineOf<Null<Int>>(null, end.value);
            case _: new LineOf<Null<Int>>(null, null);
        }
    }

    /**
     * If neither of the start and end positions is a track index then the other end can be resolved
     * into a track index if a definite start position is supplied externally
     */
    public static function resolveIndefiniteGridTracks(line:LineOf<GenericGridPlacement>, start:Int):IntLine {
        final s = line.start;
        final e = line.end;
        return switch [s.kind, e.kind] {
            case [GenericGridPlacement.AUTO_KIND, GenericGridPlacement.AUTO_KIND]: new IntLine(start, start + 1);
            case [GenericGridPlacement.SPAN_KIND, GenericGridPlacement.AUTO_KIND]: new IntLine(start, start + s.value);
            case [GenericGridPlacement.AUTO_KIND, GenericGridPlacement.SPAN_KIND]: new IntLine(start, start + e.value);
            case [GenericGridPlacement.SPAN_KIND, GenericGridPlacement.SPAN_KIND]: new IntLine(start, start + s.value);
            case _: throw "resolveIndefiniteGridTracks should only be called on indefinite grid tracks";
        }
    }

}

/**
 * A grid item's `grid-row`/`grid-column` styles with named lines resolved, in origin-zero coordinates
 * (Rust `ItemPlacement = InBothAbsAxis<Line<OriginZeroGridPlacement>>`)
 */
final class ItemPlacement {

    /** The placement in the horizontal axis (`grid-column`) */
    public final horizontal:LineOf<GenericGridPlacement>;

    /** The placement in the vertical axis (`grid-row`) */
    public final vertical:LineOf<GenericGridPlacement>;

    public inline function new(horizontal:LineOf<GenericGridPlacement>, vertical:LineOf<GenericGridPlacement>) {
        this.horizontal = horizontal;
        this.vertical = vertical;
    }

    /** Get the placement in the passed axis */
    public inline function get(axis:AbsoluteAxis):LineOf<GenericGridPlacement> {
        return axis == Horizontal ? horizontal : vertical;
    }

}
