// Ported from taffy 0.15.0: src/style/dimension.rs, src/util/resolve.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

import taffy.util.OptionalFloat;

/**
 * A unit of linear measurement: a length or a percentage.
 */
abstract LengthPercentage(CompactLength) {

    /** A zero length */
    public static final ZERO:LengthPercentage = new LengthPercentage(CompactLength.ZERO);

    inline function new(value:CompactLength) {
        this = value;
    }

    /** An absolute length in some abstract units. */
    public static inline function length(val:Float):LengthPercentage {
        return new LengthPercentage(CompactLength.length(val));
    }

    /** A percentage length relative to the size of the containing block (0.5 is 50%). */
    public static inline function percent(val:Float):LengthPercentage {
        return new LengthPercentage(CompactLength.percent(val));
    }

    /** Create from a raw `CompactLength` (the caller must ensure that the tag is valid) */
    public static inline function fromRaw(val:CompactLength):LengthPercentage {
        return new LengthPercentage(val);
    }

    /** Get the underlying `CompactLength` representation of the value */
    public inline function intoRaw():CompactLength {
        return this;
    }

    public inline function tag():Int {
        return this.tag;
    }

    public inline function value():Float {
        return this.value;
    }

    /** Resolve against an optional context (Rust `MaybeResolve<Option<f32>, Option<f32>>`) */
    public inline function maybeResolve(context:OptionalFloat):OptionalFloat {
        return this.tag == CompactLength.LENGTH_TAG ? OptionalFloat.some(this.value) : (context.isSome() ? OptionalFloat.some(context.unwrap() * this.value) : OptionalFloat.NONE);
    }

    /** Resolve against an optional context, defaulting to zero */
    public inline function resolveOrZero(context:OptionalFloat):Float {
        final r = maybeResolve(context);
        return r.isSome() ? r.unwrap() : 0.0;
    }

    public inline function equals(other:LengthPercentage):Bool {
        return this.equals(other.intoRaw());
    }

    public inline function toString():String {
        return this.toString();
    }

    /** Parse a CSS value (`10px`, `50%`) */
    public static function parse(input:String):Null<LengthPercentage> {
        final v = taffy.util.Parse.parseNumberWithUnit(StringTools.trim(input));
        if (v == null)
            return null;
        return switch v.unit {
            case "px": length(v.value);
            case "%": percent(v.value / 100);
            case _: null;
        }
    }

}
