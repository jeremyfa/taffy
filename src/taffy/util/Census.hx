package taffy.util;

/**
 * Instrumentation for the `OptionalFloat` decision (see
 * `docs/perf/OPTIONAL_FLOAT.md` of glaze-golden): counts the values that
 * reach the optional floats of taffy, to check which representation of the
 * absent value is safe.
 *
 * Only compiled with `-D taffy_census`. Then `F32.build` records every
 * `Null<Float>` parameter and every `Null<Float>` return value of the taffy
 * package (`opt`), and the geometry constructors record every component
 * (`any`). Without the define this class is empty.
 */
class Census {

    #if taffy_census

    /** Candidate finite sentinel: the most negative `f32` (exact in a double) */
    public static inline final SENTINEL:Float = -3.4028234663852886e38;

    /** Values at or above this magnitude count as "huge" */
    public static inline final HUGE:Float = 1e30;

    // Optional slots (`Null<Float>` parameters and returns, generic geometry)
    public static var optTotal = 0;
    public static var optNull = 0;
    public static var optNaN = 0;
    public static var optPosInf = 0;
    public static var optNegInf = 0;
    public static var optHuge = 0;
    public static var optSentinel = 0;
    public static var optMaxAbs = 0.0;
    public static var optMin = 0.0;
    public static var optMax = 0.0;
    public static var optOver1e6 = 0;
    public static var optOver1e9 = 0;

    // Concrete float slots (`Size`, `Rect`, `Point`, `Line` components)
    public static var concTotal = 0;
    public static var concNaN = 0;
    public static var concPosInf = 0;
    public static var concNegInf = 0;
    public static var concHuge = 0;
    public static var concMaxAbs = 0.0;
    public static var concMin = 0.0;
    public static var concMax = 0.0;

    /** Distinct source positions where a NaN or an infinity reached an optional slot */
    public static final nanSites:Array<String> = [];
    public static final infSites:Array<String> = [];
    public static final hugeSites:Array<String> = [];
    static inline final MAX_SITES = 12;

    static var hooked = hook();

    static function recordSite(sites:Array<String>, site:String):Void {
        if (sites.length >= MAX_SITES) return;
        if (sites.indexOf(site) == -1) sites.push(site);
    }

    static function hook():Bool {
        #if js
        if (js.Syntax.code("typeof process !== 'undefined' && !!process.on")) {
            js.Syntax.code("process.on('exit', function() { console.log({0}()); })", report);
        }
        #end
        return true;
    }

    /** Records a value reaching the `Null<Float>` slot at `site` (a Haxe source position) and returns it unchanged */
    public static function opt(v:Null<Float>, site:String):Null<Float> {
        optTotal++;
        if (v == null) {
            optNull++;
            return v;
        }
        {
            final f:Float = v;
            if (f != f) {
                optNaN++;
                recordSite(nanSites, site);
                // Interleaved with the test runner output, to attribute the first ones to a test
                if (optNaN <= 4)
                    trace('taffy census: Some(NaN) at ' + site);
            } else if (f == Math.POSITIVE_INFINITY) {
                optPosInf++;
                recordSite(infSites, site);
                if (optPosInf <= 2)
                    trace('taffy census: Some(+inf) at ' + site);
            } else if (f == Math.NEGATIVE_INFINITY) {
                optNegInf++;
                recordSite(infSites, site);
            } else {
                final a = f < 0 ? -f : f;
                if (a >= HUGE) {
                    optHuge++;
                    recordSite(hugeSites, site);
                    if (optHuge <= 2)
                        trace('taffy census: Some(' + f + ') at ' + site);
                }
                if (a >= 1e6) optOver1e6++;
                if (a >= 1e9) optOver1e9++;
                if (f == SENTINEL) optSentinel++;
                if (a > optMaxAbs) optMaxAbs = a;
                if (f < optMin) optMin = f;
                if (f > optMax) optMax = f;
            }
        }
        return v;
    }

    /** Records a value reaching an `OptionalFloat` slot at `site` (absent counts as null) and returns it unchanged */
    public static function optional(v:OptionalFloat, site:String):OptionalFloat {
        opt(v.toNullable(), site);
        return v;
    }

    /** Records a component of a generic geometry value (counted as optional when it is a float) */
    public static function any(v:Dynamic, site:String):Void {
        if (v == null || Std.isOfType(v, Float))
            opt((v : Null<Float>), site);
    }

    // AvailableSpace values (for the representation of `AvailableSpace` as a float)
    public static var availTotal = 0;
    public static var availMinContent = 0;
    public static var availMaxContent = 0;
    public static var availDefiniteCount = 0;
    public static var availNaN = 0;
    public static var availPosInf = 0;
    public static var availNegInf = 0;
    public static var availHuge = 0;
    public static var availNegative = 0;
    public static var availMin = 0.0;
    public static var availMax = 0.0;
    public static final availNaNSites:Array<String> = [];
    public static final availInfSites:Array<String> = [];
    public static final availHugeSites:Array<String> = [];

    /** Records an `AvailableSpace` value at `site` (a geometry component) */
    public static function availableSpace(v:taffy.style.AvailableSpace, site:String):Void {
        if (v == taffy.style.AvailableSpace.MinContent) {
            availTotal++;
            availMinContent++;
        }
        else if (v == taffy.style.AvailableSpace.MaxContent) {
            availTotal++;
            availMaxContent++;
        }
        else {
            availDefinite(v.definiteValue(), site);
        }
    }

    /** Records the value of a `Definite(value)` built at `site` and returns it unchanged */
    public static function availDefinite(f:Float, site:String):Float {
        availTotal++;
        availDefiniteCount++;
        if (f != f) {
            availNaN++;
            recordSite(availNaNSites, site);
        } else if (f == Math.POSITIVE_INFINITY) {
            availPosInf++;
            recordSite(availInfSites, site);
        } else if (f == Math.NEGATIVE_INFINITY) {
            availNegInf++;
            recordSite(availInfSites, site);
        } else {
            final a = f < 0 ? -f : f;
            if (a >= HUGE) {
                availHuge++;
                recordSite(availHugeSites, site);
            }
            if (f < 0) availNegative++;
            if (f < availMin) availMin = f;
            if (f > availMax) availMax = f;
        }
        return f;
    }

    /** Records a component of a concrete geometry value */
    public static function conc(f:Float):Void {
        concTotal++;
        if (f != f) {
            concNaN++;
        } else if (f == Math.POSITIVE_INFINITY) {
            concPosInf++;
        } else if (f == Math.NEGATIVE_INFINITY) {
            concNegInf++;
        } else {
            final a = f < 0 ? -f : f;
            if (a >= HUGE) concHuge++;
            if (a > concMaxAbs) concMaxAbs = a;
            if (f < concMin) concMin = f;
            if (f > concMax) concMax = f;
        }
    }

    public static function report():String {
        return 'taffy census (Null<Float> slots): total=$optTotal null=$optNull NaN=$optNaN +inf=$optPosInf -inf=$optNegInf |v|>=1e30: $optHuge  ==SENTINEL: $optSentinel  |v|>=1e9: $optOver1e9  |v|>=1e6: $optOver1e6  min=$optMin max=$optMax maxAbs=$optMaxAbs\n'
            + 'taffy census (concrete Float components): total=$concTotal NaN=$concNaN +inf=$concPosInf -inf=$concNegInf |v|>=1e30: $concHuge  min=$concMin max=$concMax maxAbs=$concMaxAbs'
            + (nanSites.length > 0 ? '\n  NaN sites:\n    ' + nanSites.join('\n    ') : '')
            + (infSites.length > 0 ? '\n  inf sites:\n    ' + infSites.join('\n    ') : '')
            + (hugeSites.length > 0 ? '\n  |v|>=1e30 sites:\n    ' + hugeSites.join('\n    ') : '')
            + '\ntaffy census (AvailableSpace): total=$availTotal MinContent=$availMinContent MaxContent=$availMaxContent Definite=$availDefiniteCount NaN=$availNaN +inf=$availPosInf -inf=$availNegInf |v|>=1e30: $availHuge negative=$availNegative min=$availMin max=$availMax'
            + (availNaNSites.length > 0 ? '\n  Definite(NaN) sites:\n    ' + availNaNSites.join('\n    ') : '')
            + (availInfSites.length > 0 ? '\n  Definite(inf) sites:\n    ' + availInfSites.join('\n    ') : '')
            + (availHugeSites.length > 0 ? '\n  Definite(|v|>=1e30) sites:\n    ' + availHugeSites.join('\n    ') : '');
    }

    #end

}
