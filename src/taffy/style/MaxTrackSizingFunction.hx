// Ported from taffy 0.15.0: src/style/grid.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

import taffy.util.OptionalFloat;

/**
 * Maximum track sizing function
 *
 * Specifies the maximum size of a grid track. A grid track will automatically size between it's minimum and maximum size based
 * on the size of it's contents, the amount of available space, and the sizing constraint the grid is being size under.
 * See https://developer.mozilla.org/en-US/docs/Web/CSS/grid-template-columns
 */
abstract MaxTrackSizingFunction(CompactLength) {

    /** A zero length */
    public static final ZERO:MaxTrackSizingFunction = new MaxTrackSizingFunction(CompactLength.ZERO);

    /** The `auto` value */
    public static final AUTO:MaxTrackSizingFunction = new MaxTrackSizingFunction(CompactLength.AUTO);

    /** The `min-content` value */
    public static final MIN_CONTENT:MaxTrackSizingFunction = new MaxTrackSizingFunction(CompactLength.MIN_CONTENT);

    /** The `max-content` value */
    public static final MAX_CONTENT:MaxTrackSizingFunction = new MaxTrackSizingFunction(CompactLength.MAX_CONTENT);

    inline function new(value:CompactLength) {
        this = value;
    }

    /** An absolute length in some abstract units */
    public static inline function length(val:Float):MaxTrackSizingFunction {
        return new MaxTrackSizingFunction(CompactLength.length(val));
    }

    /** A percentage length relative to the size of the containing block (0.5 is 50%) */
    public static inline function percent(val:Float):MaxTrackSizingFunction {
        return new MaxTrackSizingFunction(CompactLength.percent(val));
    }

    /** The dimension should be automatically computed according to algorithm-specific rules */
    public static inline function auto():MaxTrackSizingFunction {
        return AUTO;
    }

    /** The size should be the "min-content" size */
    public static inline function minContent():MaxTrackSizingFunction {
        return MIN_CONTENT;
    }

    /** The size should be the "max-content" size */
    public static inline function maxContent():MaxTrackSizingFunction {
        return MAX_CONTENT;
    }

    /** `fit-content(<length>)`: `max(min_content, min(max_content, limit))` */
    public static inline function fitContentPx(limit:Float):MaxTrackSizingFunction {
        return new MaxTrackSizingFunction(CompactLength.fitContentPx(limit));
    }

    /** `fit-content(<percentage>)`: `max(min_content, min(max_content, limit))` */
    public static inline function fitContentPercent(limit:Float):MaxTrackSizingFunction {
        return new MaxTrackSizingFunction(CompactLength.fitContentPercent(limit));
    }

    /** `fit-content(...)` from a `LengthPercentage` argument */
    public static inline function fitContent(argument:LengthPercentage):MaxTrackSizingFunction {
        return new MaxTrackSizingFunction(CompactLength.fitContent(argument));
    }

    /** The dimension as a fraction of the total available grid space (`fr` units in CSS) */
    public static inline function fr(val:Float):MaxTrackSizingFunction {
        return new MaxTrackSizingFunction(CompactLength.fr(val));
    }

    /** Create from a raw `CompactLength` (the caller must ensure that the tag is valid). Also an implicit conversion. */
    @:from public static inline function fromRaw(val:CompactLength):MaxTrackSizingFunction {
        return new MaxTrackSizingFunction(val);
    }

    /** Convert from a `LengthPercentage` */
    public static inline function fromLengthPercentage(input:LengthPercentage):MaxTrackSizingFunction {
        return new MaxTrackSizingFunction(input.intoRaw());
    }

    /** Convert from a `LengthPercentageAuto` */
    public static inline function fromLengthPercentageAuto(input:LengthPercentageAuto):MaxTrackSizingFunction {
        return new MaxTrackSizingFunction(input.intoRaw());
    }

    /** Convert from a `Dimension`. Values that are not valid max track sizing functions are mapped to `auto`. */
    public static function fromDimension(input:Dimension):MaxTrackSizingFunction {
        return switch input.tag() {
            case CompactLength.FIT_CONTENT_KEYWORD_TAG | CompactLength.STRETCH_TAG | CompactLength.CONTENT_TAG: AUTO;
            case _: new MaxTrackSizingFunction(input.intoRaw());
        }
    }

    /** Convert from a `MinTrackSizingFunction` */
    public static inline function fromMin(input:MinTrackSizingFunction):MaxTrackSizingFunction {
        return new MaxTrackSizingFunction(input.intoRaw());
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

    /** Returns true if the max track sizing function is `MinContent`, `MaxContent`, `FitContent` or `Auto`, else false. */
    public inline function isIntrinsic():Bool {
        return this.isIntrinsic();
    }

    /**
     * Returns true if the max track sizing function is `MaxContent`, `FitContent` or `Auto` else false.
     * "In all cases, treat auto and fit-content() as max-content, except where specified otherwise for fit-content()."
     */
    public inline function isMaxContentAlike():Bool {
        return this.isMaxContentAlike();
    }

    /** Returns true if the an Fr value, else false. */
    public inline function isFr():Bool {
        return this.isFr();
    }

    /** Returns true if the is `Auto`, else false. */
    public inline function isAuto():Bool {
        return this.isAuto();
    }

    /** Returns true if value is MinContent */
    public inline function isMinContent():Bool {
        return this.isMinContent();
    }

    /** Returns true if value is MaxContent */
    public inline function isMaxContent():Bool {
        return this.isMaxContent();
    }

    /** Returns true if value is FitContent(...) */
    public inline function isFitContent():Bool {
        return this.isFitContent();
    }

    /** Returns true if value is MaxContent or FitContent(...) */
    public inline function isMaxOrFitContent():Bool {
        return this.isMaxOrFitContent();
    }

    /** Returns whether the value can be resolved using `definiteValue` */
    public inline function hasDefiniteValue(parentSize:OptionalFloat):Bool {
        return switch this.tag {
            case CompactLength.LENGTH_TAG: true;
            case CompactLength.PERCENT_TAG: parentSize.isSome();
            case _: false;
        }
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

    /**
     * Resolve the `fit-content()` limit of this track sizing function against the passed `parentSize`.
     * Returns null if this is not a `fit-content()` function, or if it has a percentage argument and
     * `parentSize` is indefinite.
     */
    public inline function fitContentLimit(parentSize:OptionalFloat):OptionalFloat {
        return switch this.tag {
            case CompactLength.FIT_CONTENT_PX_TAG: OptionalFloat.some(this.value);
            case CompactLength.FIT_CONTENT_PERCENT_TAG: parentSize.isSome() ? OptionalFloat.some(this.value * parentSize.unwrap()) : OptionalFloat.NONE;
            case _: OptionalFloat.NONE;
        }
    }

    /**
     * Resolve the maximum size of the track as defined by either:
     *     - A fixed track sizing function
     *     - A percentage track sizing function (with definite available space)
     *     - A fit-content sizing function with fixed argument
     *     - A fit-content sizing function with percentage argument (with definite available space)
     * All other kinds of track sizing function return null.
     */
    public inline function definiteLimit(parentSize:OptionalFloat):OptionalFloat {
        return switch this.tag {
            case CompactLength.FIT_CONTENT_PX_TAG: OptionalFloat.some(this.value);
            case CompactLength.FIT_CONTENT_PERCENT_TAG: parentSize.isSome() ? OptionalFloat.some(this.value * parentSize.unwrap()) : OptionalFloat.NONE;
            case _: definiteValue(parentSize);
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

    /** Expand the compact representation into an `ExpandedMaxTrackSizingFunction` enum */
    public function expand():ExpandedMaxTrackSizingFunction {
        return switch this.tag {
            case CompactLength.LENGTH_TAG: ExpandedMaxTrackSizingFunction.Length(this.value);
            case CompactLength.PERCENT_TAG: ExpandedMaxTrackSizingFunction.Percent(this.value);
            case CompactLength.AUTO_TAG: ExpandedMaxTrackSizingFunction.Auto;
            case CompactLength.MIN_CONTENT_TAG: ExpandedMaxTrackSizingFunction.MinContent;
            case CompactLength.MAX_CONTENT_TAG: ExpandedMaxTrackSizingFunction.MaxContent;
            case CompactLength.FIT_CONTENT_PX_TAG: ExpandedMaxTrackSizingFunction.FitContentPx(this.value);
            case CompactLength.FIT_CONTENT_PERCENT_TAG: ExpandedMaxTrackSizingFunction.FitContentPercent(this.value);
            case CompactLength.FR_TAG: ExpandedMaxTrackSizingFunction.Fr(this.value);
            case _: throw "MaxTrackSizingFunction contains a value with an invalid tag";
        }
    }

    /** Convert from the expanded representation */
    public static function fromExpanded(value:ExpandedMaxTrackSizingFunction):MaxTrackSizingFunction {
        return switch value {
            case Length(val): length(val);
            case Percent(val): percent(val);
            case Auto: auto();
            case MinContent: minContent();
            case MaxContent: maxContent();
            case FitContentPx(val): fitContentPx(val);
            case FitContentPercent(val): fitContentPercent(val);
            case Fr(val): fr(val);
        }
    }

    public inline function equals(other:MaxTrackSizingFunction):Bool {
        return this.equals(other.intoRaw());
    }

    public inline function toString():String {
        return this.toString();
    }

}

/**
 * The expanded, non-compact representation of a `MaxTrackSizingFunction`.
 */
enum ExpandedMaxTrackSizingFunction {

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

    /** A `fit-content(...)` value with a length limit */
    FitContentPx(value:Float);

    /** A `fit-content(...)` value with a percentage limit */
    FitContentPercent(value:Float);

    /** A fraction of the leftover space */
    Fr(value:Float);

}
