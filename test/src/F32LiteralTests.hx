package;

import taffy.f32test.LiteralProbe;
import taffy.util.F32;

/**
 * The `F32` macro must make every float literal of the taffy package an
 * exact f32 value on every target. On hxcpp a `fround(literal)` call could be
 * folded away by the analyzer and leave a double (`0.000001` and `0.01` in
 * `TrackSizing`); the macro now writes the rounded value itself.
 */
class F32LiteralTests {

    public static function run():{passed:Int, total:Int, failures:Array<String>} {
        final tests:Array<{name:String, fn:Void->Void}> = [
            {name: "probe_literals_are_f32", fn: probeLiteralsAreF32},
            #if taffy_literal_check
            {name: "every_taffy_literal_is_f32", fn: everyTaffyLiteralIsF32},
            #end
        ];
        final failures:Array<String> = [];
        var passed = 0;
        for (test in tests) {
            try {
                test.fn();
                passed++;
            }
            catch (e:Dynamic) {
                failures.push('f32_literals ${test.name}: $e');
            }
        }
        return {passed: passed, total: tests.length, failures: failures};
    }

    static function check(cond:Bool, message:String):Void {
        if (!cond)
            throw message;
    }

    /** The f32 value of `text`, rounded at run time from a value the compiler cannot fold */
    static function single(text:String):Float {
        return F32.fround(Std.parseFloat(text));
    }

    static function probeLiteralsAreF32():Void {
        check(LiteralProbe.localConstant() == single("0.000001"), 'THRESHOLD 0.000001 compiled as ${LiteralProbe.localConstant()}');
        check(LiteralProbe.localConstant() != Std.parseFloat("0.000001"), '0.000001 stayed a double');
        // A space strictly between the double 0.01 and its f32 value: the
        // comparison gives opposite answers with the two thresholds
        final threshold01 = single("0.01");
        final double01 = Std.parseFloat("0.01");
        check(threshold01 != double01, '0.01 is not an f32 value');
        final between = (double01 + threshold01) / 2;
        check(between != double01 && between != threshold01, 'test value between the double and the f32 of 0.01');
        check(LiteralProbe.comparedConstant(between) == (between <= threshold01), 'THRESHOLD 0.01 compared as a double');
        check(LiteralProbe.scaled(Std.parseFloat("3")) == F32.fround(Std.parseFloat("3") * single("0.1")), 'value * 0.1 does not use the f32 of 0.1');
        check(LiteralProbe.exact() == single("1.17549435e-38"), 'f32::MIN_POSITIVE literal');
    }

    #if taffy_literal_check
    static function everyTaffyLiteralIsF32():Void {
        final failures = taffy.util.LiteralCheck.failures();
        check(failures.length == 0, failures.join('; '));
        final classes = taffy.util.LiteralCheck.classes;
        for (name in ['taffy.compute.grid.TrackSizing', 'taffy.compute.FlexboxLayout', 'taffy.compute.BlockLayout'])
            check(classes.indexOf(name) != -1, '$name registered no literal');
    }
    #end

}
