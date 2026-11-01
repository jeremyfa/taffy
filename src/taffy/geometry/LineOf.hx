// Ported from taffy 0.15.0: src/geometry.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.geometry;

/**
 * An abstract "line", generic version (`Line<T>` where `T` is not `f32`).
 *
 * Immutable: every operation returns a new instance.
 */
@:structInit
class LineOf<T> {

    /** The start position of a line */
    public final start:T;

    /** The end position of a line */
    public final end:T;

    public inline function new(start:T, end:T) {
        this.start = start;
        this.end = end;
    }

    /** Applies the function `f` to both the start and end */
    public inline function map<R>(f:T->R):LineOf<R> {
        return new LineOf<R>(f(start), f(end));
    }

    public inline function withStart(value:T):LineOf<T> {
        return new LineOf<T>(value, end);
    }

    public inline function withEnd(value:T):LineOf<T> {
        return new LineOf<T>(start, value);
    }

    public function toString():String {
        return 'Line(start: $start, end: $end)';
    }

}

/**
 * Constants for `LineOf<Bool>`
 */
class BoolLineTools {

    /** A `LineOf<Bool>` with both start and end set to `true` */
    public static final TRUE:LineOf<Bool> = new LineOf<Bool>(true, true);

    /** A `LineOf<Bool>` with both start and end set to `false` */
    public static final FALSE:LineOf<Bool> = new LineOf<Bool>(false, false);

}
