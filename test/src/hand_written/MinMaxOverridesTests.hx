// Ported from taffy 0.15.0 (repository): tests/hand_written/min_max_overrides.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.SizeOf;
import taffy.style.Dimension;
import taffy.style.LengthPercentageAuto;

class MinMaxOverridesTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("min_overrides_max", minOverridesMax),
            new TestCase("max_overrides_size", maxOverridesSize),
            new TestCase("min_overrides_size", minOverridesSize),
        ];
    }

    static function minOverridesMax() {
        final taffy = newTestTree();

        final child = taffy.newLeaf(st(s -> {
            s.size = new SizeOf<Dimension>(Dimension.length(50.0), Dimension.length(50.0));
            s.minSize = new SizeOf<LengthPercentageAuto>(LengthPercentageAuto.length(100.0), LengthPercentageAuto.length(100.0));
            s.maxSize = new SizeOf<LengthPercentageAuto>(LengthPercentageAuto.length(10.0), LengthPercentageAuto.length(10.0));
        }));

        taffy.computeLayout(child, definite(100.0, 100.0));

        Assert.eqSize(taffy.layout(child).size, 100.0, 100.0);
    }

    static function maxOverridesSize() {
        final taffy = newTestTree();

        final child = taffy.newLeaf(st(s -> {
            s.size = new SizeOf<Dimension>(Dimension.length(50.0), Dimension.length(50.0));
            s.maxSize = new SizeOf<LengthPercentageAuto>(LengthPercentageAuto.length(10.0), LengthPercentageAuto.length(10.0));
        }));

        taffy.computeLayout(child, definite(100.0, 100.0));

        Assert.eqSize(taffy.layout(child).size, 10.0, 10.0);
    }

    static function minOverridesSize() {
        final taffy = newTestTree();

        final child = taffy.newLeaf(st(s -> {
            s.size = new SizeOf<Dimension>(Dimension.length(50.0), Dimension.length(50.0));
            s.minSize = new SizeOf<LengthPercentageAuto>(LengthPercentageAuto.length(100.0), LengthPercentageAuto.length(100.0));
        }));

        taffy.computeLayout(child, definite(100.0, 100.0));

        Assert.eqSize(taffy.layout(child).size, 100.0, 100.0);
    }

}
