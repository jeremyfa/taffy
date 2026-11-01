// Ported from taffy 0.15.0: src/style/compact_length.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * A representation of a length as a compact value: a tag plus a float value.
 *
 * In Rust this is a tagged pointer. In Haxe it is a small immutable object.
 * Instances for keywords without a value are shared.
 * Note: `calc()` values are not supported by this port.
 */
final class CompactLength {

    /** The tag indicating a non-pointer value */
    public static inline final NON_POINTER_BIT:Int = 0x01;
    /** Tag bit for keywords */
    public static inline final KEYWORD_BIT:Int = 0x02;
    /** Tag bit for values that use percentage */
    public static inline final PERCENTAGE_BIT:Int = 0x04;
    /** Tag bit for sizing keywords */
    public static inline final SIZING_KEYWORD_BIT:Int = 0x08;

    /** The tag indicating a calc() value */
    public static inline final CALC_TAG:Int = 0x04;
    /** The tag indicating a fit-content(calc()) value */
    public static inline final FIT_CONTENT_CALC_TAG:Int = 0x06;
    /** The tag indicating a length value */
    public static inline final LENGTH_TAG:Int = 0x01;
    /** The tag indicating a percentage value */
    public static inline final PERCENT_TAG:Int = 0x05;
    /** The tag indicating an auto value */
    public static inline final AUTO_TAG:Int = 0x03;
    /** The tag indicating a fr value */
    public static inline final FR_TAG:Int = 0x13;
    /** The tag indicating a content value */
    public static inline final CONTENT_TAG:Int = 0x23;
    /** The tag indicating a min-content value */
    public static inline final MIN_CONTENT_TAG:Int = 0x0B;
    /** The tag indicating a max-content value */
    public static inline final MAX_CONTENT_TAG:Int = 0x1B;
    /** The tag indicating a fit-content value with px limit */
    public static inline final FIT_CONTENT_PX_TAG:Int = 0x2B;
    /** The tag indicating a fit-content keyword value */
    public static inline final FIT_CONTENT_KEYWORD_TAG:Int = 0x3B;
    /** The tag indicating a stretch value */
    public static inline final STRETCH_TAG:Int = 0x4B;
    /** The tag indicating a fit-content value with percent limit */
    public static inline final FIT_CONTENT_PERCENT_TAG:Int = 0x0F;

    /** A zero length */
    public static final ZERO:CompactLength = new CompactLength(LENGTH_TAG, 0.0);
    /** The auto keyword */
    public static final AUTO:CompactLength = new CompactLength(AUTO_TAG, 0.0);
    /** The min-content keyword */
    public static final MIN_CONTENT:CompactLength = new CompactLength(MIN_CONTENT_TAG, 0.0);
    /** The max-content keyword */
    public static final MAX_CONTENT:CompactLength = new CompactLength(MAX_CONTENT_TAG, 0.0);
    /** The fit-content keyword */
    public static final FIT_CONTENT_KEYWORD:CompactLength = new CompactLength(FIT_CONTENT_KEYWORD_TAG, 0.0);
    /** The stretch keyword */
    public static final STRETCH:CompactLength = new CompactLength(STRETCH_TAG, 0.0);
    /** The content keyword */
    public static final CONTENT:CompactLength = new CompactLength(CONTENT_TAG, 0.0);

    /** The tag of the value */
    public final tag:Int;

    /** The numeric value (0 for keywords) */
    public final value:Float;

    inline function new(tag:Int, value:Float) {
        this.tag = tag;
        this.value = value;
    }

    /** An absolute length in some abstract units */
    public static inline function length(val:Float):CompactLength {
        return val == 0.0 ? ZERO : new CompactLength(LENGTH_TAG, val);
    }

    /** A percentage length relative to the size of the containing block (0.5 is 50%) */
    public static inline function percent(val:Float):CompactLength {
        return new CompactLength(PERCENT_TAG, val);
    }

    /** The dimension should be automatically computed according to algorithm-specific rules */
    public static inline function auto():CompactLength {
        return AUTO;
    }

    /** The dimension as a fraction of the total available grid space (`fr` units) */
    public static inline function fr(val:Float):CompactLength {
        return new CompactLength(FR_TAG, val);
    }

    /** The size should be the "min-content" size */
    public static inline function minContent():CompactLength {
        return MIN_CONTENT;
    }

    /** The size should be the "max-content" size */
    public static inline function maxContent():CompactLength {
        return MAX_CONTENT;
    }

    /** `fit-content(<length>)` */
    public static inline function fitContentPx(limit:Float):CompactLength {
        return new CompactLength(FIT_CONTENT_PX_TAG, limit);
    }

    /** `fit-content(<percentage>)` */
    public static inline function fitContentPercent(limit:Float):CompactLength {
        return new CompactLength(FIT_CONTENT_PERCENT_TAG, limit);
    }

    /** The `fit-content` keyword */
    public static inline function fitContentKeyword():CompactLength {
        return FIT_CONTENT_KEYWORD;
    }

    /** The `stretch` keyword */
    public static inline function stretch():CompactLength {
        return STRETCH;
    }

    /** The `content` keyword */
    public static inline function content():CompactLength {
        return CONTENT;
    }

    /** Create a `fit-content(...)` value from a `LengthPercentage` */
    public static function fitContent(lp:LengthPercentage):CompactLength {
        final inner:CompactLength = lp.intoRaw();
        return switch inner.tag {
            case LENGTH_TAG: fitContentPx(inner.value);
            case PERCENT_TAG: fitContentPercent(inner.value);
            case _: throw 'Invalid fit-content argument';
        }
    }

    /** Whether the value is a plain calc() value (never in this port) */
    public inline function isPlainCalc():Bool {
        return false;
    }

    /** Whether the value is a fit-content(calc()) value (never in this port) */
    public inline function isFitContentCalc():Bool {
        return false;
    }

    /** Whether the value contains a calc() value (never in this port) */
    public inline function hasCalc():Bool {
        return false;
    }

    /** Returns true if the value is a zero length */
    public inline function isZero():Bool {
        return tag == LENGTH_TAG && value == 0.0;
    }

    /** Returns true if the value is a length or percentage value */
    public inline function isLengthOrPercentage():Bool {
        return tag & (NON_POINTER_BIT | KEYWORD_BIT) == NON_POINTER_BIT;
    }

    /** Returns true if the value is auto */
    public inline function isAuto():Bool {
        return tag == AUTO_TAG;
    }

    /** Returns true if the value is the content keyword */
    public inline function isContent():Bool {
        return tag == CONTENT_TAG;
    }

    /** Returns true if the value is min-content */
    public inline function isMinContent():Bool {
        return tag == MIN_CONTENT_TAG;
    }

    /** Returns true if the value is max-content */
    public inline function isMaxContent():Bool {
        return tag == MAX_CONTENT_TAG;
    }

    /** Returns true if the value is a fit-content(...) value */
    public inline function isFitContent():Bool {
        return tag == FIT_CONTENT_PX_TAG || tag == FIT_CONTENT_PERCENT_TAG;
    }

    /** Returns true if the value is a sizing keyword (min-content, max-content, fit-content, stretch) */
    public inline function isSizingKeyword():Bool {
        final mask = NON_POINTER_BIT | KEYWORD_BIT | SIZING_KEYWORD_BIT;
        return tag & mask == mask;
    }

    /** Returns true if the value is max-content or fit-content(...) */
    public inline function isMaxOrFitContent():Bool {
        return tag == MAX_CONTENT_TAG || tag == FIT_CONTENT_PX_TAG || tag == FIT_CONTENT_PERCENT_TAG;
    }

    /** Returns true if the max track sizing function is `MaxContent`, `FitContent` or `Auto` */
    public inline function isMaxContentAlike():Bool {
        return tag == AUTO_TAG || tag == MAX_CONTENT_TAG || tag == FIT_CONTENT_PX_TAG || tag == FIT_CONTENT_PERCENT_TAG;
    }

    /** Returns true if the value is min-content or max-content */
    public inline function isMinOrMaxContent():Bool {
        return tag == MIN_CONTENT_TAG || tag == MAX_CONTENT_TAG;
    }

    /** Returns true if the value is an intrinsic sizing function (auto, min-content, max-content, fit-content) */
    public inline function isIntrinsic():Bool {
        return tag == AUTO_TAG || tag == MIN_CONTENT_TAG || tag == MAX_CONTENT_TAG || tag == FIT_CONTENT_PX_TAG || tag == FIT_CONTENT_PERCENT_TAG;
    }

    /** Returns true if the value is a fr value */
    public inline function isFr():Bool {
        return tag == FR_TAG;
    }

    /** Whether the value uses a percentage */
    public inline function usesPercentage():Bool {
        return tag & PERCENTAGE_BIT != 0;
    }

    /** Resolve percentage values against the passed parent_size, returning null for non-percentage values */
    public inline function resolvedPercentageSize(parentSize:Float):Null<Float> {
        return tag == PERCENT_TAG ? value * parentSize : null;
    }

    /** Structural equality */
    public inline function equals(other:CompactLength):Bool {
        return tag == other.tag && value == other.value;
    }

    public function toString():String {
        return switch tag {
            case LENGTH_TAG: '${value}px';
            case PERCENT_TAG: '${value * 100}%';
            case AUTO_TAG: 'auto';
            case FR_TAG: '${value}fr';
            case CONTENT_TAG: 'content';
            case MIN_CONTENT_TAG: 'min-content';
            case MAX_CONTENT_TAG: 'max-content';
            case FIT_CONTENT_PX_TAG: 'fit-content(${value}px)';
            case FIT_CONTENT_PERCENT_TAG: 'fit-content(${value * 100}%)';
            case FIT_CONTENT_KEYWORD_TAG: 'fit-content';
            case STRETCH_TAG: 'stretch';
            case _: 'CompactLength($tag, $value)';
        }
    }

}
