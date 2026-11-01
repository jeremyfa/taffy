// Ported from taffy 0.15.0: src/style/dimension.rs, src/util/resolve.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * A unit of linear measurement: a length, a percentage or `auto`.
 */
abstract LengthPercentageAuto(CompactLength) {

    /** A zero length */
    public static final ZERO:LengthPercentageAuto = new LengthPercentageAuto(CompactLength.ZERO);

    /** The `auto` value */
    public static final AUTO:LengthPercentageAuto = new LengthPercentageAuto(CompactLength.AUTO);

    inline function new(value:CompactLength) {
        this = value;
    }

    /** An absolute length in some abstract units. */
    public static inline function length(val:Float):LengthPercentageAuto {
        return new LengthPercentageAuto(CompactLength.length(val));
    }

    /** A percentage length relative to the size of the containing block (0.5 is 50%). */
    public static inline function percent(val:Float):LengthPercentageAuto {
        return new LengthPercentageAuto(CompactLength.percent(val));
    }

    /** The dimension should be automatically computed according to algorithm-specific rules */
    public static inline function auto():LengthPercentageAuto {
        return AUTO;
    }

    /** Create from a raw `CompactLength` (the caller must ensure that the tag is valid) */
    public static inline function fromRaw(val:CompactLength):LengthPercentageAuto {
        return new LengthPercentageAuto(val);
    }

    /** Convert from a `LengthPercentage` */
    @:from public static inline function fromLengthPercentage(input:LengthPercentage):LengthPercentageAuto {
        return new LengthPercentageAuto(input.intoRaw());
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

    /** Returns true if the value is auto */
    public inline function isAuto():Bool {
        return this.tag == CompactLength.AUTO_TAG;
    }

    /**
     * Returns:
     *   - Some(length) for Length variants
     *   - Some(resolved) using the provided context for Percent variants
     *   - None for Auto variants
     */
    public inline function resolveToOption(context:Float):Null<Float> {
        return switch this.tag {
            case CompactLength.LENGTH_TAG: this.value;
            case CompactLength.PERCENT_TAG: context * this.value;
            case _: null;
        }
    }

    /** Resolve against an optional context (Rust `MaybeResolve<Option<f32>, Option<f32>>`) */
    public inline function maybeResolve(context:Null<Float>):Null<Float> {
        return switch this.tag {
            case CompactLength.LENGTH_TAG: this.value;
            case CompactLength.PERCENT_TAG: context != null ? (context : Float) * this.value : null;
            case _: null;
        }
    }

    /** Resolve against an optional context, defaulting to zero */
    public inline function resolveOrZero(context:Null<Float>):Float {
        final r = maybeResolve(context);
        return r != null ? (r : Float) : 0.0;
    }

    public inline function equals(other:LengthPercentageAuto):Bool {
        return this.equals(other.intoRaw());
    }

    public inline function toString():String {
        return this.toString();
    }

    /** Parse a CSS value (`10px`, `50%`, `auto`) */
    public static function parse(input:String):Null<LengthPercentageAuto> {
        final s = StringTools.trim(input).toLowerCase();
        if (s == "auto")
            return AUTO;
        final v = taffy.util.Parse.parseNumberWithUnit(s);
        if (v == null)
            return null;
        return switch v.unit {
            case "px": length(v.value);
            case "%": percent(v.value / 100);
            case _: null;
        }
    }

}
