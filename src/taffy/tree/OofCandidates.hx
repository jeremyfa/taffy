// Ported from taffy 0.15.0: src/tree/layout.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

import taffy.geometry.Point;
import taffy.geometry.PointOf;

/**
 * A list of `OofCandidate`s.
 *
 * Lazily allocated: an empty list holds no array.
 */
class OofCandidates {

    /**
     * A shared empty list, the default of layout outputs and flex/block items (most of them carry
     * no candidate). It can be read, taken, cloned and appended from, never added to: `push` and
     * `append` throw on it, so a list that receives candidates must be a `new OofCandidates()`.
     */
    public static final EMPTY:OofCandidates = new OofCandidates();

    /** Backing storage for the candidates */
    var inner:Null<Array<OofCandidate>> = null;

    public inline function new() {}

    /** Whether the list contains no candidates */
    public inline function isEmpty():Bool {
        return inner == null || inner.length == 0;
    }

    /** The number of candidates */
    public inline function length():Int {
        return inner == null ? 0 : inner.length;
    }

    /** Get the candidate at `index` */
    public inline function get(index:Int):OofCandidate {
        return inner[index];
    }

    /** Replace the candidate at `index` */
    public inline function set(index:Int, candidate:OofCandidate):Void {
        inner[index] = candidate;
    }

    /** The candidates as an array (a new empty array if there are none) */
    public function asArray():Array<OofCandidate> {
        return inner == null ? [] : inner;
    }

    /** Append a candidate to the list */
    public function push(candidate:OofCandidate):Void {
        if (this == EMPTY)
            throw 'OofCandidates.EMPTY is shared and cannot receive candidates';
        if (inner == null)
            inner = [];
        inner.push(candidate);
    }

    /** Move all candidates from `other` into `this`, leaving `other` empty */
    public function append(other:OofCandidates):Void {
        if (other.isEmpty())
            return;
        if (this == EMPTY)
            throw 'OofCandidates.EMPTY is shared and cannot receive candidates';
        if (inner == null) {
            inner = other.inner;
        }
        else {
            for (c in other.inner)
                inner.push(c);
        }
        other.inner = null;
    }

    /** Take the candidates out of this list, leaving it empty (an empty result is the shared `EMPTY`) */
    public function take():OofCandidates {
        if (inner == null || inner.length == 0) {
            inner = null;
            return EMPTY;
        }
        final result = new OofCandidates();
        result.inner = inner;
        inner = null;
        return result;
    }

    /** Remove all candidates from the list */
    public inline function clear():Void {
        inner = null;
    }

    /** Create a copy of this list (a copy of an empty list is the shared `EMPTY`) */
    public function clone():OofCandidates {
        if (inner == null || inner.length == 0)
            return EMPTY;
        final result = new OofCandidates();
        result.inner = inner.copy();
        return result;
    }

    /**
     * Translate the static-position areas of every candidate in the list by `offset`.
     * Converts areas from being relative to a child node's border box to being relative to the parent node's border box.
     */
    public function translate(offset:Point):Void {
        if (inner == null)
            return;
        for (i in 0...inner.length) {
            final c = inner[i];
            inner[i] = new OofCandidate(c.node, c.order, c.position, new PointOf<AxisStaticPosition>(c.staticPosition.x.translate(offset.x), c.staticPosition.y.translate(offset.y)));
        }
    }

}
