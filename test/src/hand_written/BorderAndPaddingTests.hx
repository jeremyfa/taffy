// Ported from taffy 0.15.0 (repository): tests/hand_written/border_and_padding.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.RectOf;
import taffy.style.LengthPercentage;

/**
 * Every test of this file is `#[ignore]`d upstream: they are ported but only run by `ignored()`,
 * not by `tests()`.
 */
class BorderAndPaddingTests {

    public static function tests():Array<TestCase> {
        return [];
    }

    /** The tests marked `#[ignore]` upstream */
    public static function ignored():Array<TestCase> {
        return [
            new TestCase("border_on_a_single_axis_doesnt_increase_size", borderOnASingleAxisDoesntIncreaseSize),
            new TestCase("padding_on_a_single_axis_doesnt_increase_size", paddingOnASingleAxisDoesntIncreaseSize),
            new TestCase("border_and_padding_on_a_single_axis_doesnt_increase_size", borderAndPaddingOnASingleAxisDoesntIncreaseSize),
            new TestCase("vertical_border_and_padding_percentage_values_use_available_space_correctly", verticalBorderAndPaddingPercentageValuesUseAvailableSpaceCorrectly),
        ];
    }

    static function arrToRect(items:Array<LengthPercentage>):RectOf<LengthPercentage> {
        return new RectOf<LengthPercentage>(items[0], items[1], items[2], items[3]);
    }

    static function singleSide(i:Int):RectOf<LengthPercentage> {
        final lengths = [LengthPercentage.ZERO, LengthPercentage.ZERO, LengthPercentage.ZERO, LengthPercentage.ZERO];
        lengths[i] = LengthPercentage.length(10.0);
        return arrToRect(lengths);
    }

    static function borderOnASingleAxisDoesntIncreaseSize() {
        for (i in 0...4) {
            final taffy = newTestTree();
            final node = taffy.newLeaf(st(s -> {
                s.border = singleSide(i);
            }));

            taffy.computeLayout(node, definite(100.0, 100.0));

            final layout = taffy.layout(node);
            Assert.eq(layout.size.width * layout.size.height, 0.0);
        }
    }

    static function paddingOnASingleAxisDoesntIncreaseSize() {
        for (i in 0...4) {
            final taffy = newTestTree();
            final node = taffy.newLeaf(st(s -> {
                s.padding = singleSide(i);
            }));

            taffy.computeLayout(node, definite(100.0, 100.0));

            final layout = taffy.layout(node);
            Assert.eq(layout.size.width * layout.size.height, 0.0);
        }
    }

    static function borderAndPaddingOnASingleAxisDoesntIncreaseSize() {
        for (i in 0...4) {
            final taffy = newTestTree();
            final rect = singleSide(i);
            final node = taffy.newLeaf(st(s -> {
                s.border = rect;
                s.padding = rect;
            }));

            taffy.computeLayout(node, definite(100.0, 100.0));
            final layout = taffy.layout(node);
            Assert.eq(layout.size.width * layout.size.height, 0.0);
        }
    }

    static function verticalBorderAndPaddingPercentageValuesUseAvailableSpaceCorrectly() {
        final taffy = newTestTree();

        final node = taffy.newLeaf(st(s -> {
            s.padding = rectLP(percent(1.0), zero(), percent(1.0), zero());
        }));

        taffy.computeLayout(node, definite(200.0, 100.0));

        final layout = taffy.layout(node);
        Assert.eq(layout.size.width, 200.0);
        Assert.eq(layout.size.height, 200.0);
    }

}
