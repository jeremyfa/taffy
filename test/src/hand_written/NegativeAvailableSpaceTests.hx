// Ported from taffy 0.15.0 (repository): tests/hand_written/negative_available_space.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.SizeOf;
import taffy.style.AvailableSpace;
import taffy.style.Dimension;
import taffy.style.Display;
import taffy.style.FlexDirection;
import taffy.style.LengthPercentageAuto;
import taffy.style.Style;
import taffy.tree.LayoutInput;
import taffy.tree.NodeId;
import taffy.style.AvailableSpace.Definite;

class NegativeAvailableSpaceTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("block_child_margins_exceed_container_width", blockChildMarginsExceedContainerWidth),
            new TestCase("flex_column_child_margins_exceed_container_width", flexColumnChildMarginsExceedContainerWidth),
            new TestCase("grid_child_margins_exceed_container_width", gridChildMarginsExceedContainerWidth),
        ];
    }

    static function isNegative(value:taffy.util.OptionalFloat):Bool {
        return value.isSome() && value.unwrap() < 0.0;
    }

    static function isNegativeAvail(value:AvailableSpace):Bool {
        return value.isDefinite() && value.definiteValue() < 0.0;
    }

    /**
     * Lays out a 20px wide container of the given display type with a single leaf whose
     * horizontal margins (40px) exceed the container width. Returns the leaf's final width
     * and every `LayoutInput` with a negative known dimension or available space that reached
     * the leaf's measure function.
     */
    static function layoutWithOversizedMargins(display:Display, flexDirection:FlexDirection, negativeInputs:Array<String>):Float {
        final taffy = newTestTree();
        final leaf = taffy.newLeafWithContext(st(s -> {
            s.margin = rectLPA(LengthPercentageAuto.length(30.0), LengthPercentageAuto.length(10.0), zero(), zero());
            s.size = new SizeOf<Dimension>(auto(), auto());
        }), TestNodeContext.zero());
        final root = taffy.newWithChildren(st(s -> {
            s.display = display;
            s.flexDirection = flexDirection;
            s.size = new SizeOf<Dimension>(length(20.0), auto());
            s.gridTemplateColumns = tracks("20px");
        }), [leaf]);

        taffy.computeLayoutWithMeasure(root, MAX_CONTENT, (inputs:LayoutInput, nodeId:NodeId, context:Null<TestNodeContext>, style:Style) -> {
            final known = inputs.knownDimensions;
            final avail = inputs.availableSpace;
            if (isNegative(known.width) || isNegative(known.height) || isNegativeAvail(avail.width) || isNegativeAvail(avail.height)) {
                negativeInputs.push('known=$known available=$avail');
            }
            return testMeasureFunction(inputs, nodeId, context, style);
        });

        return taffy.layout(leaf).size.width;
    }

    static function assertFlooredAtZero(display:Display, flexDirection:FlexDirection) {
        final negativeInputs:Array<String> = [];
        final leafWidth = layoutWithOversizedMargins(display, flexDirection, negativeInputs);
        Assert.isTrue(negativeInputs.length == 0, 'leaf received negative layout inputs: $negativeInputs');
        Assert.eq(leafWidth, 0.0);
    }

    static function blockChildMarginsExceedContainerWidth() {
        assertFlooredAtZero(Block, Row);
    }

    static function flexColumnChildMarginsExceedContainerWidth() {
        assertFlooredAtZero(Flex, Column);
    }

    static function gridChildMarginsExceedContainerWidth() {
        assertFlooredAtZero(Grid, Row);
    }

}
