// Ported from taffy 0.15.0: src/style/grid.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

import taffy.util.OptionalFloat;

/**
 * Minimum track sizing function
 *
 * Specifies the minimum size of a grid track. A grid track will automatically size between it's minimum and maximum size based
 * on the size of it's contents, the amount of available space, and the sizing constraint the grid is being size under.
 * See https://developer.mozilla.org/en-US/docs/Web/CSS/grid-template-columns
 */
abstract MinTrackSizingFunction(CompactLength) {

    /** A zero length */
    public static final ZERO:MinTrackSizingFunction = new MinTrackSizingFunction(CompactLength.ZERO);

    /** The `auto` value */
    public static final AUTO:MinTrackSizingFunction = new MinTrackSizingFunction(CompactLength.AUTO);

    /** The `min-content` value */
    public static final MIN_CONTENT:MinTrackSizingFunction = new MinTrackSizingFunction(CompactLength.MIN_CONTENT);

    /** The `max-content` value */
    public static final MAX_CONTENT:MinTrackSizingFunction = new MinTrackSizingFunction(CompactLength.MAX_CONTENT);

    inline function new(value:CompactLength) {
        this = value;
    }

    /** An absolute length in some abstract units */
    public static inline function length(val:Float):MinTrackSizingFunction {
        return new MinTrackSizingFunction(CompactLength.length(val));
    }

    /** A percentage length relative to the size of the containing block (0.5 is 50%) */
    public static inline function percent(val:Float):MinTrackSizingFunction {
        return new MinTrackSizingFunction(CompactLength.percent(val));
    }

    /** The dimension should be automatically computed according to algorithm-specific rules */
    public static inline function auto():MinTrackSizingFunction {
        return AUTO;
    }

    /** The size should be the "min-content" size */
    public static inline function minContent():MinTrackSizingFunction {
        return MIN_CONTENT;
    }

    /** The size should be the "max-content" size */
    public static inline function maxContent():MinTrackSizingFunction {
        return MAX_CONTENT;
    }

    /** Create from a raw `CompactLength` (the caller must ensure that the tag is valid). Also an implicit conversion. */
    @:from public static inline function fromRaw(val:CompactLength):MinTrackSizingFunction {
        return new MinTrackSizingFunction(val);
    }

    /** Convert from a `LengthPercentage` */
    public static inline function fromLengthPercentage(input:LengthPercentage):MinTrackSizingFunction {
        return new MinTrackSizingFunction(input.intoRaw());
    }

    /** Convert from a `LengthPercentageAuto` */
    public static inline function fromLengthPercentageAuto(input:LengthPercentageAuto):MinTrackSizingFunction {
        return new MinTrackSizingFunction(input.intoRaw());
    }

    /** Convert from a `Dimension`. Values that are not valid min track sizing functions are mapped to `auto`. */
    public static function fromDimension(input:Dimension):MinTrackSizingFunction {
        return switch input.tag() {
            case CompactLength.FIT_CONTENT_PX_TAG | CompactLength.FIT_CONTENT_PERCENT_TAG | CompactLength.FIT_CONTENT_KEYWORD_TAG
                | CompactLength.STRETCH_TAG | CompactLength.CONTENT_TAG:
                AUTO;
            case _:
                new MinTrackSizingFunction(input.intoRaw());
        }
    }

    /** Convert from a `MaxTrackSizingFunction` (`fr` and `fit-content()` values become `auto`) */
    public static inline function fromMax(input:MaxTrackSizingFunction):MinTrackSizingFunction {
        return (input.isFr() || input.isFitContent()) ? AUTO : new MinTrackSizingFunction(input.intoRaw());
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

    /** Returns true if the min track sizing function is `MinContent`, `MaxContent` or `Auto`, else false. */
    public inline function isIntrinsic():Bool {
        return this.isIntrinsic();
    }

    /** Returns true if the min track sizing function is `MinContent` or `MaxContent`, else false. */
    public inline function isMinOrMaxContent():Bool {
        return this.isMinOrMaxContent();
    }

    /** Returns true if the value is an fr value */
    public inline function isFr():Bool {
        return this.isFr();
    }

    /** Returns true if the is `Auto`, else false. */
    public inline function isAuto():Bool {
        return this.isAuto();
    }

    /** Returns true if the value is `Auto`, or is a percentage and `parentSize` is null */
    public inline function behavesAsAuto(parentSize:OptionalFloat):Bool {
        return this.isAuto() || (parentSize.isNone() && this.usesPercentage());
    }

    /** Returns true if value is MinContent */
    public inline function isMinContent():Bool {
        return this.isMinContent();
    }

    /** Returns true if value is MaxContent */
    public inline function isMaxContent():Bool {
        return this.isMaxContent();
    }

    /**
     * Returns fixed point values directly. Attempts to resolve percentage values against
     * the passed parentSize and returns if this results in a concrete value. Otherwise returns null.
     */
    public inline function definiteValue(parentSize:OptionalFloat):OptionalFloat {
        return switch this.tag {
            case CompactLength.LENGTH_TAG: OptionalFloat.some(this.value);
            case CompactLength.PERCENT_TAG: parentSize.isSome() ? OptionalFloat.some(this.value * parentSize.unwrap()) : OptionalFloat.NONE;
            case _: OptionalFloat.NONE;
        }
    }

    /** Resolve percentage values against the passed parentSize. Non-percentage values always return null. */
    public inline function resolvedPercentageSize(parentSize:Float):OptionalFloat {
        return this.resolvedPercentageSize(parentSize);
    }

    /** Whether the track sizing functions depends on the size of the parent node */
    public inline function usesPercentage():Bool {
        return this.usesPercentage();
    }

    /** Expand the compact representation into an `ExpandedMinTrackSizingFunction` enum */
    public function expand():ExpandedMinTrackSizingFunction {
        return switch this.tag {
            case CompactLength.LENGTH_TAG: ExpandedMinTrackSizingFunction.Length(this.value);
            case CompactLength.PERCENT_TAG: ExpandedMinTrackSizingFunction.Percent(this.value);
            case CompactLength.AUTO_TAG: ExpandedMinTrackSizingFunction.Auto;
            case CompactLength.MIN_CONTENT_TAG: ExpandedMinTrackSizingFunction.MinContent;
            case CompactLength.MAX_CONTENT_TAG: ExpandedMinTrackSizingFunction.MaxContent;
            case _: throw "MinTrackSizingFunction contains a value with an invalid tag";
        }
    }

    /** Convert from the expanded representation */
    public static function fromExpanded(value:ExpandedMinTrackSizingFunction):MinTrackSizingFunction {
        return switch value {
            case Length(val): length(val);
            case Percent(val): percent(val);
            case Auto: auto();
            case MinContent: minContent();
            case MaxContent: maxContent();
        }
    }

    public inline function equals(other:MinTrackSizingFunction):Bool {
        return this.equals(other.intoRaw());
    }

    public inline function toString():String {
        return this.toString();
    }

}

/**
 * The expanded, non-compact representation of a `MinTrackSizingFunction`.
 */
enum ExpandedMinTrackSizingFunction {

    /** An absolute length */
    Length(value:Float);

    /** A percentage length */
    Percent(value:Float);

    /** The automatic keyword */
    Auto;

    /** The `min-content` keyword */
    MinContent;

    /** The `max-content` keyword */
    MaxContent;

}
