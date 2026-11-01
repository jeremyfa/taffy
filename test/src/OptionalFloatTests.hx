package;

import taffy.util.F32;
import taffy.util.MaybeMath;
import taffy.style.AvailableSpace;
import taffy.util.OptionalFloat;

using taffy.style.AvailableSpace;

/**
 * Tests of `taffy.util.OptionalFloat` (Rust `Option<f32>` over a plain
 * float): the sentinel itself, and every `MaybeMath` helper against the
 * `Null<Float>` implementation it replaces (`NullableMaybeMath`, a frozen
 * copy), on a table of inputs with NaN, infinities, signed zeros and the f32
 * edges. Results must be identical bit for bit (same presence, same value,
 * same sign of zero, NaN for NaN).
 */
class OptionalFloatTests {

    /** Present inputs of the table (`null` is added separately) */
    static final VALUES:Array<Float> = [
        0.0,
        -0.0,
        1.0,
        -1.0,
        1.5,
        -2.25,
        0.1, // not an f32: the f32 helpers round the results of add / sub
        100.0,
        -3840.0,
        1920.0,
        16777216.0, // 2^24, last integer exact in f32
        16777217.0, // not an f32
        3.4028234663852886e38, // f32::MAX
        -3.4028234663852886e38, // f32::MIN
        6.805646932770577e38, // 2 * f32::MAX, seen in GPUI inputs
        1.1754943508222875e-38, // f32::MIN_POSITIVE
        1.401298464324817e-45, // smallest f32 subnormal
        -1.401298464324817e-45,
        1.1920928955078125e-7, // f32::EPSILON
        Math.NaN,
        Math.POSITIVE_INFINITY,
        Math.NEGATIVE_INFINITY,
    ];

    /** An absent value the analyzer cannot see as a constant */
    static var leakedNone:OptionalFloat = OptionalFloat.NONE;

    /** Sentinels the analyzer cannot see as constants */
    static var leakedSpaces:Array<AvailableSpace> = [MinContent, MaxContent];

    public static function run():{passed:Int, total:Int, failures:Array<String>} {
        final tests:Array<{name:String, fn:Void->Void}> = [
            {name: "none_is_none", fn: noneIsNone},
            {name: "fround_of_none_is_not_none", fn: froundOfNoneIsNotNone},
            {name: "nan_and_infinities_are_some", fn: nanAndInfinitiesAreSome},
            {name: "equality_matches_option", fn: equalityMatchesOption},
            {name: "unwrap_or_and_or", fn: unwrapOrAndOr},
            {name: "nullable_round_trip", fn: nullableRoundTrip},
            {name: "float_helpers", fn: floatHelpers},
            {name: "maybe_min", fn: maybeMin},
            {name: "maybe_max", fn: maybeMax},
            {name: "maybe_add", fn: maybeAdd},
            {name: "maybe_sub", fn: maybeSub},
            {name: "maybe_clamp", fn: maybeClamp},
            {name: "clamp_f", fn: clampF},
            {name: "available_space", fn: availableSpace},
        ];
        final failures:Array<String> = [];
        var passed = 0;
        for (test in tests) {
            try {
                test.fn();
                passed++;
            }
            catch (e:Dynamic) {
                failures.push('optional_float ${test.name}: $e');
            }
        }
        return {passed: passed, total: tests.length, failures: failures};
    }

    // Helpers

    static function check(cond:Bool, message:String):Void {
        if (!cond)
            throw message;
    }

    /** Every input of the table, absent first */
    static function inputs():Array<Null<Float>> {
        final result:Array<Null<Float>> = [null];
        for (v in VALUES)
            result.push(v);
        return result;
    }

    static function opt(v:Null<Float>):OptionalFloat {
        return v == null ? OptionalFloat.NONE : OptionalFloat.some(v);
    }

    static function show(v:Null<Float>):String {
        if (v == null)
            return 'None';
        final f:Float = v;
        return (f == 0 && 1 / f < 0) ? 'Some(-0)' : 'Some($f)';
    }

    /** Same float bit for bit: NaN equals NaN, 0 and -0 differ */
    static function sameFloat(a:Float, b:Float):Bool {
        if (a != a || b != b)
            return a != a && b != b;
        if (a == 0 && b == 0)
            return (1 / a < 0) == (1 / b < 0);
        return a == b;
    }

    static function sameOption(actual:OptionalFloat, expected:Null<Float>):Bool {
        if (expected == null)
            return actual.isNone();
        return actual.isSome() && sameFloat(actual.unwrap(), expected);
    }

    static function expectSame(actual:OptionalFloat, expected:Null<Float>, what:String):Void {
        check(sameOption(actual, expected), '$what: expected ${show(expected)}, got $actual');
    }

    // Tests

    static function noneIsNone():Void {
        check(OptionalFloat.NONE.isNone(), 'NONE.isNone()');
        check(!OptionalFloat.NONE.isSome(), '!NONE.isSome()');
        check(OptionalFloat.NONE == OptionalFloat.NONE, 'NONE == NONE');
        check(OptionalFloat.fromNullable(null).isNone(), 'fromNullable(null) is none');
    }

    /**
     * The canary: the sentinel is outside the f32 range, so rounding it to
     * f32 (what any arithmetic on a leaked absent value does in taffy) gives
     * `-inf`, never the sentinel again and never a plausible number.
     */
    static function froundOfNoneIsNotNone():Void {
        // Read from a static var: a constant would be folded by the Haxe
        // analyzer, which drops the f32 conversion of `fround` on constants
        // (hxcpp), while the leak this guards against is a runtime value
        final raw:Float = cast leakedNone;
        final rounded:OptionalFloat = OptionalFloat.some(F32.fround(raw));
        check(rounded != OptionalFloat.NONE, 'fround(NONE) != NONE');
        check(rounded.isSome(), 'fround(NONE) is some');
        check(rounded.unwrap() == Math.NEGATIVE_INFINITY, 'fround(NONE) is -inf, got $rounded');
        check(raw < -3.4028234663852886e38, 'the sentinel is below f32::MIN');
        check(Math.isFinite(raw), 'the sentinel is finite');
    }

    static function nanAndInfinitiesAreSome():Void {
        check(OptionalFloat.some(Math.NaN).isSome(), 'some(NaN).isSome()');
        check(!OptionalFloat.some(Math.NaN).isNone(), '!some(NaN).isNone()');
        check(Math.isNaN(OptionalFloat.some(Math.NaN).unwrap()), 'some(NaN).unwrap() is NaN');
        check(OptionalFloat.some(Math.POSITIVE_INFINITY).isSome(), 'some(+inf).isSome()');
        check(OptionalFloat.some(Math.NEGATIVE_INFINITY).isSome(), 'some(-inf).isSome()');
        for (v in VALUES)
            check(OptionalFloat.some(v).isSome(), 'some($v).isSome()');
    }

    static function equalityMatchesOption():Void {
        // `==` compares like `Option<f32>`: None == None, None != Some, IEEE for values
        for (a in inputs()) {
            for (b in inputs()) {
                final expected = if (a == null || b == null) (a == null && b == null) else ((a : Float) == (b : Float));
                check((opt(a) == opt(b)) == expected, '${show(a)} == ${show(b)} should be $expected');
                check((opt(a) != opt(b)) == !expected, '${show(a)} != ${show(b)} should be ${!expected}');
            }
        }
    }

    static function unwrapOrAndOr():Void {
        for (a in inputs()) {
            for (alt in VALUES) {
                check(sameFloat(opt(a).unwrapOr(alt), NullableMaybeMath.unwrapOr(a, alt)), 'unwrapOr(${show(a)}, $alt)');
            }
            for (b in inputs())
                expectSame(opt(a).or(opt(b)), NullableMaybeMath.or(a, b), 'or(${show(a)}, ${show(b)})');
        }
    }

    static function nullableRoundTrip():Void {
        for (a in inputs()) {
            final back = OptionalFloat.fromNullable(a).toNullable();
            check(a == null ? back == null : (back != null && sameFloat(back, a)), 'round trip of ${show(a)}');
        }
    }

    /**
     * The `f32 x Option<f32> -> f32` helpers of `MaybeMath`. (Before the
     * conversion, a test checked that `NullableMaybeMath` was identical to
     * the `Null<Float>` `MaybeMath` on this whole table, on node, cpp and
     * interp.)
     */
    static function floatHelpers():Void {
        for (v in VALUES) {
            for (b in inputs()) {
                final pairs:Array<{name:String, actual:Float, expected:Float}> = [
                    {name: 'maybeMinF', actual: MaybeMath.maybeMinF(v, opt(b)), expected: NullableMaybeMath.maybeMinF(v, b)},
                    {name: 'maybeMaxF', actual: MaybeMath.maybeMaxF(v, opt(b)), expected: NullableMaybeMath.maybeMaxF(v, b)},
                    {name: 'maybeAddF', actual: MaybeMath.maybeAddF(v, opt(b)), expected: NullableMaybeMath.maybeAddF(v, b)},
                    {name: 'maybeSubF', actual: MaybeMath.maybeSubF(v, opt(b)), expected: NullableMaybeMath.maybeSubF(v, b)},
                ];
                for (p in pairs)
                    check(sameFloat(p.actual, p.expected), '${p.name}($v, ${show(b)}): expected ${p.expected}, got ${p.actual}');
                for (c in inputs()) {
                    final actual = MaybeMath.maybeClampF(v, opt(b), opt(c));
                    final expected = NullableMaybeMath.maybeClampF(v, b, c);
                    check(sameFloat(actual, expected), 'maybeClampF($v, ${show(b)}, ${show(c)}): expected $expected, got $actual');
                }
            }
        }
    }

    static function maybeMin():Void {
        for (a in inputs())
            for (b in inputs())
                expectSame(opt(a).maybeMin(opt(b)), NullableMaybeMath.maybeMin(a, b), 'maybeMin(${show(a)}, ${show(b)})');
    }

    static function maybeMax():Void {
        for (a in inputs())
            for (b in inputs())
                expectSame(opt(a).maybeMax(opt(b)), NullableMaybeMath.maybeMax(a, b), 'maybeMax(${show(a)}, ${show(b)})');
    }

    static function maybeAdd():Void {
        for (a in inputs())
            for (b in inputs())
                expectSame(opt(a).maybeAdd(opt(b)), NullableMaybeMath.maybeAdd(a, b), 'maybeAdd(${show(a)}, ${show(b)})');
    }

    static function maybeSub():Void {
        for (a in inputs())
            for (b in inputs())
                expectSame(opt(a).maybeSub(opt(b)), NullableMaybeMath.maybeSub(a, b), 'maybeSub(${show(a)}, ${show(b)})');
    }

    static function maybeClamp():Void {
        for (a in inputs())
            for (min in inputs())
                for (max in inputs())
                    expectSame(opt(a).maybeClamp(opt(min), opt(max)), NullableMaybeMath.maybeClamp(a, min, max), 'maybeClamp(${show(a)}, ${show(min)}, ${show(max)})');
    }

    static function clampF():Void {
        for (v in VALUES)
            for (min in inputs())
                for (max in inputs()) {
                    final actual = OptionalFloat.clampF(v, opt(min), opt(max));
                    final expected = NullableMaybeMath.maybeClampF(v, min, max);
                    check(sameFloat(actual, expected), 'clampF($v, ${show(min)}, ${show(max)}): expected $expected, got $actual');
                }
    }

    /**
     * `AvailableSpace` over a float: the two sentinels, definite NaN and
     * infinities, and the `MaybeMath` helpers against the semantics of the
     * former enum (written out here per variant).
     */
    static function availableSpace():Void {
        final spaces:Array<AvailableSpace> = [MinContent, MaxContent];
        for (v in VALUES)
            spaces.push(AvailableSpace.Definite(v));
        check(MinContent != MaxContent, 'MinContent != MaxContent');
        check(!MinContent.isDefinite() && !MaxContent.isDefinite(), 'sentinels are not definite');
        check(AvailableSpace.Definite(Math.NaN).isDefinite(), 'Definite(NaN) is definite');
        check(AvailableSpace.Definite(Math.POSITIVE_INFINITY).isDefinite(), 'Definite(+inf) is definite');
        check(AvailableSpace.Definite(Math.POSITIVE_INFINITY) != MaxContent, 'Definite(+inf) != MaxContent');
        final noneRaw:Float = cast OptionalFloat.NONE;
        for (sentinel in leakedSpaces) {
            final raw:Float = cast sentinel;
            check(raw != noneRaw, 'AvailableSpace sentinels differ from OptionalFloat.NONE');
            check(F32.fround(raw) == Math.NEGATIVE_INFINITY, 'fround of a sentinel is -inf');
        }
        for (a in spaces) {
            for (b in inputs()) {
                final o = opt(b);
                // Former enum: Definite(v) min Some(r) = Definite(min(v, r)); MinContent / MaxContent min Some(r) = Definite(r)
                final expectedMin:AvailableSpace = b == null ? a : (a.isDefinite() ? AvailableSpace.Definite(taffy.util.Sys.f32Min(a.definiteValue(), b)) : AvailableSpace.Definite(b));
                final expectedMax:AvailableSpace = (b != null && a.isDefinite()) ? AvailableSpace.Definite(taffy.util.Sys.f32Max(a.definiteValue(), b)) : a;
                final expectedAdd:AvailableSpace = (b != null && a.isDefinite()) ? AvailableSpace.Definite(F32.fround(a.definiteValue() + b)) : a;
                final expectedSub:AvailableSpace = (b != null && a.isDefinite()) ? AvailableSpace.Definite(F32.fround(a.definiteValue() - b)) : a;
                final expectedSet:AvailableSpace = b == null ? a : AvailableSpace.Definite(b);
                for (p in [
                    {name: 'maybeMin', actual: a.maybeMin(o), expected: expectedMin},
                    {name: 'maybeMax', actual: a.maybeMax(o), expected: expectedMax},
                    {name: 'maybeAdd', actual: a.maybeAdd(o), expected: expectedAdd},
                    {name: 'maybeSub', actual: a.maybeSub(o), expected: expectedSub},
                    {name: 'maybeSet', actual: a.maybeSet(o), expected: expectedSet},
                ]) {
                    final same = p.actual.isDefinite() == p.expected.isDefinite()
                        && (p.actual.isDefinite() ? sameFloat(p.actual.definiteValue(), p.expected.definiteValue()) : p.actual == p.expected);
                    check(same, '${p.name}(${a.toString()}, ${show(b)}): expected ${p.expected.toString()}, got ${p.actual.toString()}');
                }
            }
            final option = a.intoOption();
            check(a.isDefinite() ? (option.isSome() && sameFloat(option.unwrap(), a.definiteValue())) : option.isNone(), 'intoOption(${a.toString()})');
            check(a.isDefinite() || AvailableSpaceTools.fromOption(option) == MaxContent, 'fromOption(intoOption) of an indefinite space is MaxContent');
        }
    }

}
