package;

import haxe.ds.Vector;
import taffy.util.F32;

/**
 * Micro benchmark for the representation of the absent value of an optional
 * float (see `docs/perf/OPTIONAL_FLOAT.md` in the GPUI port).
 *
 * Four representations of `Option<f32>` run the same `maybeMin`, `maybeMax`,
 * `maybeAdd` chain (the hot helpers of `taffy.util.MaybeMath`) over the same
 * data, about a quarter of which is absent:
 *
 * - `nullable`: `Null<Float>`, the current code (boxed on hxcpp);
 * - `nan`: an abstract over `Float` whose absent value is NaN (`v != v`);
 * - `sentinel`: an abstract over `Float` whose absent value is the most
 *   negative `f32` (`v == SENTINEL`);
 * - `flag`: a `Float` with a separate `Bool`, here as two parallel vectors
 *   (a function cannot return both without an object or an out parameter, so
 *   the helpers write their result into the output vectors).
 *
 * Build (from `test/`):
 *   haxe -cp ../src -cp src -main OptionalFloatBench -D analyzer-optimize -js bin/optfloat.js
 *   haxe -cp ../src -cp src -main OptionalFloatBench -D analyzer-optimize -cpp bin/optfloat
 * The data is rounded to `f32` like taffy's values.
 */
class OptionalFloatBench {

    static inline final N = 4096;
    static inline final PASSES = 2000;
    static inline final ROUNDS = 5;

    static function main() {
        // Deterministic data
        var seed = 0x12345678;
        inline function next():Int {
            seed = (seed * 1103515245 + 12345) & 0x7fffffff;
            return seed;
        }
        final values = new Vector<Float>(N * 3);
        final present = new Vector<Bool>(N * 3);
        for (i in 0...N * 3) {
            present[i] = next() % 4 != 0;
            values[i] = F32.fround((next() % 200000) / 100.0 - 500.0);
        }

        trace('f32 sentinel survives fround: ' + (F32.fround(Sentinel.ABSENT_VALUE) == Sentinel.ABSENT_VALUE));
        trace('N=$N, passes=$PASSES, rounds=$ROUNDS (best of), ns per element (3 helpers per element)');

        final results = new Map<String, Float>();
        final sums = new Map<String, Float>();
        for (round in 0...ROUNDS) {
            runNullable(values, present, results, sums);
            runNaN(values, present, results, sums);
            runSentinel(values, present, results, sums);
            runFlag(values, present, results, sums);
        }
        for (name in ['nullable', 'nan', 'sentinel', 'flag']) {
            trace('$name: ${Math.round(results[name] * 100) / 100} ns/element (checksum ${sums[name]})');
        }
    }

    static function record(results:Map<String, Float>, sums:Map<String, Float>, name:String, elapsed:Float, sum:Float):Void {
        final ns = elapsed * 1e9 / (N * PASSES);
        if (!results.exists(name) || results[name] > ns)
            results[name] = ns;
        sums[name] = sum;
    }

    // --- Null<Float> (current representation) --------------------------------

    static inline function nMin(a:Null<Float>, b:Null<Float>):Null<Float> {
        return a == null ? null : (b == null ? a : ((a : Float) < (b : Float) ? a : b));
    }

    static inline function nMax(a:Null<Float>, b:Null<Float>):Null<Float> {
        return a == null ? null : (b == null ? a : ((a : Float) > (b : Float) ? a : b));
    }

    static inline function nAdd(a:Null<Float>, b:Null<Float>):Null<Float> {
        return a == null ? null : (b == null ? a : F32.fround((a : Float) + (b : Float)));
    }

    static function runNullable(values:Vector<Float>, present:Vector<Bool>, results:Map<String, Float>, sums:Map<String, Float>):Void {
        final a = new Vector<Null<Float>>(N);
        final b = new Vector<Null<Float>>(N);
        final c = new Vector<Null<Float>>(N);
        for (i in 0...N) {
            a[i] = present[i] ? values[i] : null;
            b[i] = present[N + i] ? values[N + i] : null;
            c[i] = present[2 * N + i] ? values[2 * N + i] : null;
        }
        var sum = 0.0;
        final start = haxe.Timer.stamp();
        for (_ in 0...PASSES) {
            for (i in 0...N) {
                final r = nAdd(nMax(nMin(a[i], b[i]), c[i]), b[i]);
                if (r != null)
                    sum += (r : Float);
            }
        }
        record(results, sums, 'nullable', haxe.Timer.stamp() - start, sum);
    }

    // --- NaN as absent ------------------------------------------------------

    static function runNaN(values:Vector<Float>, present:Vector<Bool>, results:Map<String, Float>, sums:Map<String, Float>):Void {
        final a = new Vector<NanOpt>(N);
        final b = new Vector<NanOpt>(N);
        final c = new Vector<NanOpt>(N);
        for (i in 0...N) {
            a[i] = present[i] ? NanOpt.some(values[i]) : NanOpt.none();
            b[i] = present[N + i] ? NanOpt.some(values[N + i]) : NanOpt.none();
            c[i] = present[2 * N + i] ? NanOpt.some(values[2 * N + i]) : NanOpt.none();
        }
        var sum = 0.0;
        final start = haxe.Timer.stamp();
        for (_ in 0...PASSES) {
            for (i in 0...N) {
                final r = a[i].maybeMin(b[i]).maybeMax(c[i]).maybeAdd(b[i]);
                if (r.isSome())
                    sum += r.unwrap();
            }
        }
        record(results, sums, 'nan', haxe.Timer.stamp() - start, sum);
    }

    // --- Finite sentinel as absent ------------------------------------------

    static function runSentinel(values:Vector<Float>, present:Vector<Bool>, results:Map<String, Float>, sums:Map<String, Float>):Void {
        final a = new Vector<Sentinel>(N);
        final b = new Vector<Sentinel>(N);
        final c = new Vector<Sentinel>(N);
        for (i in 0...N) {
            a[i] = present[i] ? Sentinel.some(values[i]) : Sentinel.none();
            b[i] = present[N + i] ? Sentinel.some(values[N + i]) : Sentinel.none();
            c[i] = present[2 * N + i] ? Sentinel.some(values[2 * N + i]) : Sentinel.none();
        }
        var sum = 0.0;
        final start = haxe.Timer.stamp();
        for (_ in 0...PASSES) {
            for (i in 0...N) {
                final r = a[i].maybeMin(b[i]).maybeMax(c[i]).maybeAdd(b[i]);
                if (r.isSome())
                    sum += r.unwrap();
            }
        }
        record(results, sums, 'sentinel', haxe.Timer.stamp() - start, sum);
    }

    // --- Separate flag (parallel vectors) -----------------------------------

    static function runFlag(values:Vector<Float>, present:Vector<Bool>, results:Map<String, Float>, sums:Map<String, Float>):Void {
        final a = new Vector<Float>(N);
        final ha = new Vector<Bool>(N);
        final b = new Vector<Float>(N);
        final hb = new Vector<Bool>(N);
        final c = new Vector<Float>(N);
        final hc = new Vector<Bool>(N);
        for (i in 0...N) {
            ha[i] = present[i];
            a[i] = values[i];
            hb[i] = present[N + i];
            b[i] = values[N + i];
            hc[i] = present[2 * N + i];
            c[i] = values[2 * N + i];
        }
        var sum = 0.0;
        final start = haxe.Timer.stamp();
        for (_ in 0...PASSES) {
            for (i in 0...N) {
                // min
                var rv = a[i];
                var rh = ha[i];
                if (rh && hb[i] && b[i] < rv)
                    rv = b[i];
                // max
                if (rh && hc[i] && c[i] > rv)
                    rv = c[i];
                // add
                if (rh && hb[i])
                    rv = F32.fround(rv + b[i]);
                if (rh)
                    sum += rv;
            }
        }
        record(results, sums, 'flag', haxe.Timer.stamp() - start, sum);
    }

}

/** Optional float whose absent value is NaN */
abstract NanOpt(Float) {

    public static inline function none():NanOpt return cast Math.NaN;

    inline function new(v:Float) this = v;

    public static inline function some(v:Float):NanOpt return new NanOpt(v);

    public inline function isSome():Bool return this == this;

    public inline function isNone():Bool return this != this;

    public inline function unwrap():Float return this;

    public inline function maybeMin(rhs:NanOpt):NanOpt {
        final r:Float = cast rhs;
        return isNone() ? none() : (r != r ? new NanOpt(this) : new NanOpt(this < r ? this : r));
    }

    public inline function maybeMax(rhs:NanOpt):NanOpt {
        final r:Float = cast rhs;
        return isNone() ? none() : (r != r ? new NanOpt(this) : new NanOpt(this > r ? this : r));
    }

    public inline function maybeAdd(rhs:NanOpt):NanOpt {
        final r:Float = cast rhs;
        return isNone() ? none() : (r != r ? new NanOpt(this) : new NanOpt(F32.fround(this + r)));
    }

}

/** Optional float whose absent value is a finite out of range sentinel (the most negative f32) */
abstract Sentinel(Float) {

    /** `-f32::MAX`, exactly representable as a double and as an f32 */
    public static inline final ABSENT_VALUE:Float = -3.4028234663852886e38;

    public static inline function none():Sentinel return cast ABSENT_VALUE;

    inline function new(v:Float) this = v;

    public static inline function some(v:Float):Sentinel return new Sentinel(v);

    public inline function isSome():Bool return this != ABSENT_VALUE;

    public inline function isNone():Bool return this == ABSENT_VALUE;

    public inline function unwrap():Float return this;

    public inline function maybeMin(rhs:Sentinel):Sentinel {
        final r:Float = cast rhs;
        return isNone() ? none() : (r == ABSENT_VALUE ? new Sentinel(this) : new Sentinel(this < r ? this : r));
    }

    public inline function maybeMax(rhs:Sentinel):Sentinel {
        final r:Float = cast rhs;
        return isNone() ? none() : (r == ABSENT_VALUE ? new Sentinel(this) : new Sentinel(this > r ? this : r));
    }

    public inline function maybeAdd(rhs:Sentinel):Sentinel {
        final r:Float = cast rhs;
        return isNone() ? none() : (r == ABSENT_VALUE ? new Sentinel(this) : new Sentinel(F32.fround(this + r)));
    }

}
