// Ported from taffy 0.15.0 (repository): tests/hand_written/flex_line_count.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.AlignContent;
import taffy.style.AlignItems;
import taffy.style.Dimension;
import taffy.style.FlexWrap;
import taffy.style.LengthPercentage;
import taffy.style.Style;

class FlexLineCountTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("wrap_line_count_divides_cross_available_space", wrapLineCountDividesCrossAvailableSpace),
            new TestCase("wrap_reverse_line_count_divides_cross_available_space", wrapReverseLineCountDividesCrossAvailableSpace),
            new TestCase("nowrap_line_count_has_no_effect", nowrapLineCountHasNoEffect),
            new TestCase("wrap_line_count_divides_fit_content_cross_size", wrapLineCountDividesFitContentCrossSize),
            new TestCase("nowrap_line_count_does_not_divide_fit_content_cross_size", nowrapLineCountDoesNotDivideFitContentCrossSize),
        ];
    }

    static function text():String {
        return "HHHHHHHHHH" + ZWS + "HHHHHHHHHH" + ZWS + "HHHHHHHHHH";
    }

    static function containerStyle(flexWrap:FlexWrap):Style {
        return st(s -> {
            s.display = Flex;
            s.flexDirection = Column;
            s.flexWrap = flexWrap;
            s.flexLineCount = 2;
            s.size = new SizeOf<Dimension>(Dimension.length(210.0), Dimension.length(100.0));
            s.gap = new SizeOf<LengthPercentage>(LengthPercentage.length(10.0), LengthPercentage.ZERO);
            s.alignItems = AlignItems.START;
            s.alignContent = AlignContent.START;
        });
    }

    static function measureTextChild(flexWrap:FlexWrap):Size {
        final taffy = newTestTree();
        final child = taffy.newLeafWithContext(new Style(), TestNodeContext.ahemText(text(), Horizontal));
        final container = taffy.newWithChildren(containerStyle(flexWrap), [child]);
        taffy.computeLayoutWithMeasure(container, MAX_CONTENT, testMeasureFunction);
        return taffy.layout(child).size;
    }

    // A multi-line container with `flex-line-count: 2` measures content against the cross-axis
    // available space divided between the requested number of lines (after subtracting the
    // cross-axis gaps): (210 - 10) / 2 = 100.
    static function wrapLineCountDividesCrossAvailableSpace() {
        Assert.eqSize(measureTextChild(Wrap), 100.0, 30.0);
    }

    static function wrapReverseLineCountDividesCrossAvailableSpace() {
        Assert.eqSize(measureTextChild(WrapReverse), 100.0, 30.0);
    }

    // `flex-line-count` has no effect on `nowrap` containers.
    static function nowrapLineCountHasNoEffect() {
        Assert.eqSize(measureTextChild(NoWrap), 210.0, 20.0);
    }

    static function measureFitContentChild(flexWrap:FlexWrap):Size {
        final taffy = newTestTree();
        final childStyle = st(s -> {
            s.size = new SizeOf<Dimension>(Dimension.fitContent(), auto());
        });
        final child = taffy.newLeafWithContext(childStyle, TestNodeContext.ahemText(text(), Horizontal));
        final container = taffy.newWithChildren(containerStyle(flexWrap), [child]);
        taffy.computeLayoutWithMeasure(container, MAX_CONTENT, testMeasureFunction);
        return taffy.layout(child).size;
    }

    // A bare `fit-content` cross size is also measured against the divided cross-axis
    // available space, not the full container cross size.
    static function wrapLineCountDividesFitContentCrossSize() {
        Assert.eqSize(measureFitContentChild(Wrap), 100.0, 30.0);
    }

    static function nowrapLineCountDoesNotDivideFitContentCrossSize() {
        Assert.eqSize(measureFitContentChild(NoWrap), 210.0, 20.0);
    }

}
