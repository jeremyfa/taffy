// Ported from taffy 0.15.0: src/geometry.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.geometry;

/**
 * An abstract "line". Represents any type that has a start and an end (concrete `Line<f32>`).
 *
 * Immutable: every operation returns a new instance.
 */
@:structInit
class Line {

    /** A line with both ends at zero */
    public static final ZERO:Line = new Line(0.0, 0.0);

    /** The start position of a line */
    public final start:Float;

    /** The end position of a line */
    public final end:Float;

    public inline function new(start:Float, end:Float) {
        #if taffy_census
        taffy.util.Census.conc(start);
        taffy.util.Census.conc(end);
        #end
        this.start = start;
        this.end = end;
    }

    /** Add the start and end values */
    public inline function sum():Float {
        return start + end;
    }

    public inline function map(f:(Float) -> Float):Line {
        return new Line(f(start), f(end));
    }

    public inline function withStart(value:Float):Line {
        return new Line(value, end);
    }

    public inline function withEnd(value:Float):Line {
        return new Line(start, value);
    }

    public inline function equals(other:Line):Bool {
        return start == other.start && end == other.end;
    }

    public function toString():String {
        return 'Line(start: $start, end: $end)';
    }

}
