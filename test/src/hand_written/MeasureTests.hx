// Ported from taffy 0.15.0 (repository): tests/hand_written/measure.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.compute.Leaf;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.AlignItems;
import taffy.style.Dimension;
import taffy.style.LengthPercentage;
import taffy.style.LengthPercentageAuto;
import taffy.style.Style;
import taffy.tree.LayoutInput;
import taffy.tree.LayoutOutput;
import taffy.tree.NodeId;
import taffy.tree.TaffyTree;

class MeasureTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("measure_root", measureRoot),
            new TestCase("measure_child", measureChild),
            new TestCase("measure_child_constraint", measureChildConstraint),
            new TestCase("measure_child_constraint_padding_parent", measureChildConstraintPaddingParent),
            new TestCase("measure_child_with_flex_grow", measureChildWithFlexGrow),
            new TestCase("measure_child_with_flex_shrink", measureChildWithFlexShrink),
            new TestCase("remeasure_child_after_growing", remeasureChildAfterGrowing),
            new TestCase("remeasure_child_after_shrinking", remeasureChildAfterShrinking),
            new TestCase("remeasure_child_after_stretching", remeasureChildAfterStretching),
            new TestCase("width_overrides_measure", widthOverridesMeasure),
            new TestCase("height_overrides_measure", heightOverridesMeasure),
            new TestCase("flex_basis_overrides_measure", flexBasisOverridesMeasure),
            new TestCase("stretch_overrides_measure", stretchOverridesMeasure),
            new TestCase("explicit_min_main_size_skips_min_content_measurement", explicitMinMainSizeSkipsMinContentMeasurement),
            new TestCase("measure_absolute_child", measureAbsoluteChild),
            new TestCase("ignore_invalid_measure", ignoreInvalidMeasure),
        ];
    }

    static function hundredHundred():TestNodeContext {
        return TestNodeContext.fixed(100.0, 100.0);
    }

    static function hundredFifty():TestNodeContext {
        return TestNodeContext.fixed(100.0, 50.0);
    }

    static function fiftyFifty():TestNodeContext {
        return TestNodeContext.fixed(50.0, 50.0);
    }

    static function sized(width:Dimension, height:Dimension):SizeOf<Dimension> {
        return new SizeOf<Dimension>(width, height);
    }

    static function measureRoot() {
        final taffy = newTestTree();
        final node = taffy.newLeafWithContext(new Style(), hundredHundred());
        taffy.computeLayoutWithMeasure(node, MAX_CONTENT, testMeasureFunction);

        Assert.eq(taffy.layout(node).size.width, 100.0);
        Assert.eq(taffy.layout(node).size.height, 100.0);
    }

    static function measureChild() {
        final taffy = newTestTree();

        final child = taffy.newLeafWithContext(new Style(), hundredHundred());

        final node = taffy.newWithChildren(new Style(), [child]);
        taffy.computeLayoutWithMeasure(node, MAX_CONTENT, testMeasureFunction);

        Assert.eq(taffy.layout(node).size.width, 100.0);
        Assert.eq(taffy.layout(node).size.height, 100.0);

        Assert.eq(taffy.layout(child).size.width, 100.0);
        Assert.eq(taffy.layout(child).size.height, 100.0);
    }

    static function measureChildConstraint() {
        final taffy = newTestTree();
        final child = taffy.newLeafWithContext(new Style(), hundredHundred());

        final node = taffy.newWithChildren(st(s -> {
            s.size = sized(Dimension.length(50.0), auto());
        }), [child]);

        taffy.computeLayoutWithMeasure(node, MAX_CONTENT, testMeasureFunction);

        // Parent
        Assert.eq(taffy.layout(node).size.width, 50.0);
        Assert.eq(taffy.layout(node).size.height, 100.0);
        // Child
        Assert.eq(taffy.layout(child).size.width, 100.0);
        Assert.eq(taffy.layout(child).size.height, 100.0);
    }

    static function measureChildConstraintPaddingParent() {
        final taffy = newTestTree();
        final child = taffy.newLeafWithContext(new Style(), hundredHundred());

        final node = taffy.newWithChildren(st(s -> {
            s.size = sized(Dimension.length(50.0), auto());
            s.padding = rectLP(
                LengthPercentage.length(10.0),
                LengthPercentage.length(10.0),
                LengthPercentage.length(10.0),
                LengthPercentage.length(10.0)
            );
        }), [child]);
        taffy.computeLayoutWithMeasure(node, MAX_CONTENT, testMeasureFunction);

        Assert.eq(taffy.layout(node).location.x, 0.0);
        Assert.eq(taffy.layout(node).location.y, 0.0);
        Assert.eq(taffy.layout(node).size.width, 50.0);
        Assert.eq(taffy.layout(node).size.height, 120.0);

        Assert.eq(taffy.layout(child).location.x, 10.0);
        Assert.eq(taffy.layout(child).location.y, 10.0);
        Assert.eq(taffy.layout(child).size.width, 100.0);
        Assert.eq(taffy.layout(child).size.height, 100.0);
    }

    static function measureChildWithFlexGrow() {
        final taffy = newTestTree();
        final child0 = taffy.newLeaf(st(s -> {
            s.size = sized(Dimension.length(50.0), Dimension.length(50.0));
        }));

        final child1 = taffy.newLeafWithContext(st(s -> {
            s.flexGrow = 1.0;
        }), fiftyFifty());

        final node = taffy.newWithChildren(st(s -> {
            s.size = sized(Dimension.length(100.0), auto());
        }), [child0, child1]);

        taffy.computeLayoutWithMeasure(node, MAX_CONTENT, testMeasureFunction);

        Assert.eq(taffy.layout(child1).size.width, 50.0);
        Assert.eq(taffy.layout(child1).size.height, 50.0);
    }

    static function measureChildWithFlexShrink() {
        final taffy = newTestTree();
        final child0 = taffy.newLeaf(st(s -> {
            s.size = sized(Dimension.length(50.0), Dimension.length(50.0));
            s.flexShrink = 0.0;
        }));

        final child1 = taffy.newLeafWithContext(new Style(), hundredFifty());

        final node = taffy.newWithChildren(st(s -> {
            s.size = sized(Dimension.length(100.0), auto());
        }), [child0, child1]);

        taffy.computeLayoutWithMeasure(node, MAX_CONTENT, testMeasureFunction);

        Assert.eq(taffy.layout(child1).size.width, 100.0);
        Assert.eq(taffy.layout(child1).size.height, 50.0);
    }

    static function remeasureChildAfterGrowing() {
        final taffy = newTestTree();
        final child0 = taffy.newLeaf(st(s -> {
            s.size = sized(Dimension.length(50.0), Dimension.length(50.0));
        }));

        final child1 = taffy.newLeafWithContext(st(s -> {
            s.flexGrow = 1.0;
        }), TestNodeContext.aspectRatio(10.0, 2.0));

        final node = taffy.newWithChildren(st(s -> {
            s.size = sized(Dimension.length(100.0), auto());
            s.alignItems = AlignItems.START;
        }), [child0, child1]);

        taffy.computeLayoutWithMeasure(node, MAX_CONTENT, testMeasureFunction);

        Assert.eq(taffy.layout(child1).size.width, 50.0);
        Assert.eq(taffy.layout(child1).size.height, 100.0);
    }

    static function remeasureChildAfterShrinking() {
        final taffy = newTestTree();

        final child0 = taffy.newLeaf(st(s -> {
            s.size = sized(Dimension.length(50.0), Dimension.length(50.0));
            s.flexShrink = 0.0;
        }));

        final child1 = taffy.newLeafWithContext(new Style(), TestNodeContext.aspectRatio(100.0, 2.0));

        final node = taffy.newWithChildren(st(s -> {
            s.size = sized(Dimension.length(100.0), auto());
            s.alignItems = AlignItems.START;
        }), [child0, child1]);

        taffy.computeLayoutWithMeasure(node, MAX_CONTENT, testMeasureFunction);

        Assert.eq(taffy.layout(child1).size.width, 100.0);
        Assert.eq(taffy.layout(child1).size.height, 200.0);
    }

    static function customMeasureFunction(inputs:LayoutInput, nodeId:NodeId, nodeContext:Null<Int>, style:Style):LayoutOutput {
        return Leaf.computeLeafLayout(inputs, style, (knownDimensions, availableSpace) -> {
            final height:Float = knownDimensions.height != null ? knownDimensions.height : 50.0;
            final width:Float = knownDimensions.width != null ? knownDimensions.width : height;
            return new Size(width, height);
        });
    }

    static function remeasureChildAfterStretching() {
        final taffy = new TaffyTree<Int>();

        final child = taffy.newLeafWithContext(new Style(), 0);

        final node = taffy.newWithChildren(st(s -> {
            s.size = sized(Dimension.length(100.0), Dimension.length(100.0));
        }), [child]);

        taffy.computeLayoutWithMeasure(node, MAX_CONTENT, customMeasureFunction);

        Assert.eq(taffy.layout(child).size.width, 100.0);
        Assert.eq(taffy.layout(child).size.height, 100.0);
    }

    static function widthOverridesMeasure() {
        final taffy = newTestTree();
        final child = taffy.newLeafWithContext(st(s -> {
            s.size = sized(Dimension.length(50.0), auto());
        }), hundredHundred());

        final node = taffy.newWithChildren(new Style(), [child]);
        taffy.computeLayoutWithMeasure(node, MAX_CONTENT, testMeasureFunction);

        Assert.eq(taffy.layout(child).size.width, 50.0);
        Assert.eq(taffy.layout(child).size.height, 100.0);
    }

    static function heightOverridesMeasure() {
        final taffy = newTestTree();
        final child = taffy.newLeafWithContext(st(s -> {
            s.size = sized(auto(), Dimension.length(50.0));
        }), hundredHundred());

        final node = taffy.newWithChildren(new Style(), [child]);
        taffy.computeLayoutWithMeasure(node, MAX_CONTENT, testMeasureFunction);

        Assert.eq(taffy.layout(child).size.width, 100.0);
        Assert.eq(taffy.layout(child).size.height, 50.0);
    }

    static function flexBasisOverridesMeasure() {
        final taffy = newTestTree();
        final child0 = taffy.newLeaf(st(s -> {
            s.flexBasis = Dimension.length(50.0);
            s.flexGrow = 1.0;
        }));

        final child1 = taffy.newLeafWithContext(st(s -> {
            s.flexBasis = Dimension.length(50.0);
            s.flexGrow = 1.0;
        }), hundredHundred());

        final node = taffy.newWithChildren(st(s -> {
            s.size = sized(Dimension.length(200.0), Dimension.length(100.0));
        }), [child0, child1]);

        taffy.computeLayoutWithMeasure(node, MAX_CONTENT, testMeasureFunction);

        Assert.eq(taffy.layout(child0).size.width, 100.0);
        Assert.eq(taffy.layout(child0).size.height, 100.0);
        Assert.eq(taffy.layout(child1).size.width, 100.0);
        Assert.eq(taffy.layout(child1).size.height, 100.0);
    }

    static function stretchOverridesMeasure() {
        final taffy = newTestTree();
        final child = taffy.newLeafWithContext(new Style(), fiftyFifty());

        final node = taffy.newWithChildren(st(s -> {
            s.size = sized(Dimension.length(100.0), Dimension.length(100.0));
        }), [child]);

        taffy.computeLayoutWithMeasure(node, MAX_CONTENT, testMeasureFunction);

        Assert.eq(taffy.layout(child).size.width, 50.0);
        Assert.eq(taffy.layout(child).size.height, 100.0);
    }

    static function assertNotMinContent(inputs:LayoutInput, nodeId:NodeId, context:Null<Int>, style:Style):LayoutOutput {
        switch inputs.availableSpace.width {
            case MinContent: Assert.isTrue(false, "available width must not be MinContent");
            case _:
        }
        return LayoutOutput.fromOuterSize(new Size(10.0, 10.0));
    }

    static function explicitMinMainSizeSkipsMinContentMeasurement() {
        final taffy = new TaffyTree<Int>();
        final child = taffy.newLeafWithContext(st(s -> {
            s.minSize = new SizeOf<LengthPercentageAuto>(length(10.0), auto());
        }), 0);
        final root = taffy.newWithChildren(new Style(), [child]);

        taffy.computeLayoutWithMeasure(root, MAX_CONTENT, assertNotMinContent);
    }

    static function measureAbsoluteChild() {
        final taffy = newTestTree();
        final child = taffy.newLeafWithContext(st(s -> {
            s.position = Absolute;
        }), fiftyFifty());

        final node = taffy.newWithChildren(st(s -> {
            s.size = sized(Dimension.length(100.0), Dimension.length(100.0));
        }), [child]);

        taffy.computeLayoutWithMeasure(node, MAX_CONTENT, testMeasureFunction);

        Assert.eq(taffy.layout(child).size.width, 50.0);
        Assert.eq(taffy.layout(child).size.height, 50.0);
    }

    static function ignoreInvalidMeasure() {
        final taffy = newTestTree();
        final child = taffy.newLeaf(st(s -> {
            s.flexGrow = 1.0;
        }));

        final node = taffy.newWithChildren(st(s -> {
            s.size = sized(Dimension.length(100.0), Dimension.length(100.0));
        }), [child]);

        taffy.computeLayoutWithMeasure(node, MAX_CONTENT, testMeasureFunction);

        Assert.eq(taffy.layout(child).size.width, 100.0);
        Assert.eq(taffy.layout(child).size.height, 100.0);
    }

}
