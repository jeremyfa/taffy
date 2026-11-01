// Ported from taffy 0.15.0: src/style/dimension.rs, src/util/resolve.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * A unit of linear measurement: a length, a percentage, `auto`, or a sizing keyword
 * (`min-content`, `max-content`, `fit-content`, `fit-content(...)`, `stretch`, `content`).
 */
abstract Dimension(CompactLength) {

    /** A zero length */
    public static final ZERO:Dimension = new Dimension(CompactLength.ZERO);

    /** The `auto` value */
    public static final AUTO:Dimension = new Dimension(CompactLength.AUTO);

    inline function new(value:CompactLength) {
        this = value;
    }

    /** An absolute length in some abstract units. */
    public static inline function length(val:Float):Dimension {
        return new Dimension(CompactLength.length(val));
    }

    /** A percentage length relative to the size of the containing block (0.5 is 50%). */
    public static inline function percent(val:Float):Dimension {
        return new Dimension(CompactLength.percent(val));
    }

    /** The dimension should be automatically computed according to algorithm-specific rules */
    public static inline function auto():Dimension {
        return AUTO;
    }

    /** The `min-content` keyword */
    public static inline function minContent():Dimension {
        return new Dimension(CompactLength.MIN_CONTENT);
    }

    /** The `max-content` keyword */
    public static inline function maxContent():Dimension {
        return new Dimension(CompactLength.MAX_CONTENT);
    }

    /** The `fit-content` keyword */
    public static inline function fitContent():Dimension {
        return new Dimension(CompactLength.FIT_CONTENT_KEYWORD);
    }

    /** `fit-content(<length>)` */
    public static inline function fitContentPx(limit:Float):Dimension {
        return new Dimension(CompactLength.fitContentPx(limit));
    }

    /** `fit-content(<percentage>)` */
    public static inline function fitContentPercent(limit:Float):Dimension {
        return new Dimension(CompactLength.fitContentPercent(limit));
    }

    /** The `stretch` keyword */
    public static inline function stretch():Dimension {
        return new Dimension(CompactLength.STRETCH);
    }

    /** The `content` keyword */
    public static inline function content():Dimension {
        return new Dimension(CompactLength.CONTENT);
    }

    /** Create from a raw `CompactLength` (the caller must ensure that the tag is valid) */
    public static inline function fromRaw(val:CompactLength):Dimension {
        return new Dimension(val);
    }

    /** Convert from a `LengthPercentage` */
    @:from public static inline function fromLengthPercentage(input:LengthPercentage):Dimension {
        return new Dimension(input.intoRaw());
    }

    /** Convert from a `LengthPercentageAuto` */
    @:from public static inline function fromLengthPercentageAuto(input:LengthPercentageAuto):Dimension {
        return new Dimension(input.intoRaw());
    }

    /** Get the underlying `CompactLength` representation of the value */
    public inline function intoRaw():CompactLength {
        return this;
    }

    /** Get Length value if value is Length variant */
    public inline function intoOption():Null<Float> {
        return this.tag == CompactLength.LENGTH_TAG ? this.value : null;
    }

    /** Returns true if the value is auto */
    public inline function isAuto():Bool {
        return this.tag == CompactLength.AUTO_TAG;
    }

    /** Returns true if the value is a sizing keyword */
    public inline function isSizingKeyword():Bool {
        return this.isSizingKeyword();
    }

    /** Returns true if the value is the stretch keyword */
    public inline function isStretch():Bool {
        return this.tag == CompactLength.STRETCH_TAG;
    }

    /** Returns true if the value is the content keyword */
    public inline function isContent():Bool {
        return this.tag == CompactLength.CONTENT_TAG;
    }

    /** Never true in this port (calc is not supported) */
    public inline function isFitContentCalc():Bool {
        return false;
    }

    public inline function tag():Int {
        return this.tag;
    }

    public inline function value():Float {
        return this.value;
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

    public inline function equals(other:Dimension):Bool {
        return this.equals(other.intoRaw());
    }

    public inline function toString():String {
        return this.toString();
    }

    /** Parse a CSS value */
    public static function parse(input:String):Null<Dimension> {
        final s = StringTools.trim(input).toLowerCase();
        switch s {
            case "auto": return AUTO;
            case "min-content": return minContent();
            case "max-content": return maxContent();
            case "fit-content": return fitContent();
            case "stretch": return stretch();
            case "content": return content();
            case _:
        }
        if (StringTools.startsWith(s, "fit-content(") && StringTools.endsWith(s, ")")) {
            final inner = taffy.util.Parse.parseNumberWithUnit(StringTools.trim(s.substring(12, s.length - 1)));
            if (inner == null)
                return null;
            return switch inner.unit {
                case "px": fitContentPx(inner.value);
                case "%": fitContentPercent(inner.value / 100);
                case _: null;
            }
        }
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
