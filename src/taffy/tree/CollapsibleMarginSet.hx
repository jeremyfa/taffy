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
        // One constructor, so that a set that does not escape allocates nothing
        final isPositive = margin >= 0.0;
        return new CollapsibleMarginSet(isPositive ? margin : 0.0, isPositive ? 0.0 : margin);
    }

    /** Collapse a single margin with this set */
    public inline function collapseWithMargin(margin:Float):CollapsibleMarginSet {
        final isPositive = margin >= 0.0;
        return new CollapsibleMarginSet(isPositive ? Sys.f32Max(positive, margin) : positive, isPositive ? negative : Sys.f32Min(negative, margin));
    }

    /**
     * A copy of this set to store, or the shared `ZERO` when both values are +0. For a set built
     * inline (`a.collapseWithSet(b).share()`), only the stored object is allocated, if any.
     */
    public inline function share():CollapsibleMarginSet {
        final p = positive;
        final n = negative;
        return (p == 0.0 && 1.0 / p > 0.0 && n == 0.0 && 1.0 / n > 0.0) ? ZERO : new CollapsibleMarginSet(p, n);
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
