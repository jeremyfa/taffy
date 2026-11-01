// Ported from taffy 0.15.0: src/tree/layout.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

import taffy.util.Sys;

/**
 * A set of margins that are available for collapsing with for block layout's margin collapsing
 */
@:structInit
class CollapsibleMarginSet {

    /** A default margin set with no collapsible margins */
    public static final ZERO:CollapsibleMarginSet = new CollapsibleMarginSet(0.0, 0.0);

    /** The largest positive margin */
    public final positive:Float;

    /** The smallest negative margin (with largest absolute value) */
    public final negative:Float;

    public inline function new(positive:Float, negative:Float) {
        this.positive = positive;
        this.negative = negative;
    }

    /** Create a set from a single margin */
    public static inline function fromMargin(margin:Float):CollapsibleMarginSet {
        return margin >= 0.0 ? new CollapsibleMarginSet(margin, 0.0) : new CollapsibleMarginSet(0.0, margin);
    }

    /** Collapse a single margin with this set */
    public inline function collapseWithMargin(margin:Float):CollapsibleMarginSet {
        return margin >= 0.0
            ? new CollapsibleMarginSet(Sys.f32Max(positive, margin), negative)
            : new CollapsibleMarginSet(positive, Sys.f32Min(negative, margin));
    }

    /** Collapse another margin set with this set */
    public inline function collapseWithSet(other:CollapsibleMarginSet):CollapsibleMarginSet {
        return new CollapsibleMarginSet(Sys.f32Max(positive, other.positive), Sys.f32Min(negative, other.negative));
    }

    /** Resolve the resultant margin from this set once all collapsible margins have been collapsed into it */
    public inline function resolve():Float {
        return positive + negative;
    }

    public inline function equals(other:CollapsibleMarginSet):Bool {
        return positive == other.positive && negative == other.negative;
    }

    public function toString():String {
        return 'CollapsibleMarginSet(positive: $positive, negative: $negative)';
    }

}
