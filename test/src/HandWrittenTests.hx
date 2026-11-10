// Ported from taffy 0.15.0 (repository): tests/hand_written.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package;

import hand_written.TestHelpers.TestCase;

/**
 * Port of the tests of tests/hand_written in the taffy repository.
 * Each test runs in its own try/catch; failures are reported as `<file>.<test_name> (<message>)`.
 */
class HandWrittenTests {

    static function modules():Array<{name:String, tests:Array<TestCase>}> {
        return [
            {name: "absolute_replaced", tests: hand_written.AbsoluteReplacedTests.tests()},
            {name: "adversarial_styles", tests: hand_written.AdversarialStylesTests.tests()},
            {name: "baseline", tests: hand_written.BaselineTests.tests()},
            {name: "block_margin", tests: hand_written.BlockMarginTests.tests()},
            {name: "block_replaced", tests: hand_written.BlockReplacedTests.tests()},
            {name: "border_and_padding", tests: hand_written.BorderAndPaddingTests.tests()},
            {name: "caching", tests: hand_written.CachingTests.tests()},
            {name: "compressible_replaced", tests: hand_written.CompressibleReplacedTests.tests()},
            {name: "cutoff", tests: hand_written.CutoffTests.tests()},
            {name: "detailed_grid_info", tests: hand_written.DetailedGridInfoTests.tests()},
            {name: "flex_line_count", tests: hand_written.FlexLineCountTests.tests()},
            {name: "floats", tests: hand_written.FloatsTests.tests()},
            {name: "grid_percentage_rerun", tests: hand_written.GridPercentageRerunTests.tests()},
            {name: "initial_containing_block", tests: hand_written.InitialContainingBlockTests.tests()},
            {name: "measure", tests: hand_written.MeasureTests.tests()},
            {name: "min_max_overrides", tests: hand_written.MinMaxOverridesTests.tests()},
            {name: "negative_available_space", tests: hand_written.NegativeAvailableSpaceTests.tests()},
            {name: "oof_hoisting", tests: hand_written.OofHoistingTests.tests()},
            {name: "position", tests: hand_written.PositionTests.tests()},
            {name: "relayout", tests: hand_written.RelayoutTests.tests()},
            {name: "root_constraints", tests: hand_written.RootConstraintsTests.tests()},
            {name: "rounding", tests: hand_written.RoundingTests.tests()},
            {name: "safe_alignment", tests: hand_written.SafeAlignmentTests.tests()},
            {name: "scroll_size", tests: hand_written.ScrollSizeTests.tests()},
            {name: "scrollable_overflow", tests: hand_written.ScrollableOverflowTests.tests()},
            {name: "scratch_reuse", tests: hand_written.ScratchReuseTests.tests()},
        ];
    }

    public static function run():{passed:Int, total:Int, failures:Array<String>} {
        var passed = 0;
        var total = 0;
        final failures:Array<String> = [];
        for (module in modules()) {
            for (test in module.tests) {
                total++;
                final name = module.name + "." + test.name;
                #if taffy_census
                final censusBefore = taffy.util.Census.optNaN + taffy.util.Census.optPosInf + taffy.util.Census.optNegInf;
                #end
                try {
                    test.fn();
                    passed++;
                }
                catch (e:haxe.Exception) {
                    failures.push(name + " (" + e.message + ")");
                }
                catch (e:Dynamic) {
                    failures.push(name + " (" + Std.string(e) + ")");
                }
                #if taffy_census
                final censusAfter = taffy.util.Census.optNaN + taffy.util.Census.optPosInf + taffy.util.Census.optNegInf;
                if (censusAfter != censusBefore)
                    FileIO.println('  census: ' + (censusAfter - censusBefore) + ' NaN/inf optional values in ' + name);
                #end
            }
        }
        return {passed: passed, total: total, failures: failures};
    }

}
