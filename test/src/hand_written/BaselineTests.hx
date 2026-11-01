// Ported from taffy 0.15.0 (repository): tests/hand_written/baseline.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.PointOf;
import taffy.geometry.Rect;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.AlignItems;
import taffy.style.Dimension;
import taffy.style.Overflow;
import taffy.style.Style;
import taffy.tree.Baselines;
import taffy.tree.LayoutInput;
import taffy.tree.LayoutOutput;
import taffy.tree.NodeId;
import taffy.tree.TaffyTree;

/**
 * A node context that pairs an intrinsic size with a first-baseline offset
 * (measured from the node's top edge in the block axis).
 */
private class BaselineContext {

    public final size:Size;

    public final baselineY:Null<Float>;

    public function new(size:Size, baselineY:Null<Float>) {
        this.size = size;
        this.baselineY = baselineY;
    }

}

class BaselineTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("flex_baseline_alignment_uses_measure_function_baseline", flexBaselineAlignmentUsesMeasureFunctionBaseline),
            new TestCase("block_scroll_container_child_without_baseline_synthesizes_from_border_box", blockScrollContainerChildWithoutBaselineSynthesizesFromBorderBox),
            new TestCase("block_non_scroll_container_child_without_baseline_contributes_nothing", blockNonScrollContainerChildWithoutBaselineContributesNothing),
            new TestCase("block_scroll_container_child_baseline_is_clamped_to_border_box", blockScrollContainerChildBaselineIsClampedToBorderBox),
            new TestCase("flex_baseline_is_ignored_when_alignment_is_not_baseline", flexBaselineIsIgnoredWhenAlignmentIsNotBaseline),
        ];
    }

    static function baselineMeasureFunction(inputs:LayoutInput, nodeId:NodeId, context:Null<BaselineContext>, style:Style):LayoutOutput {
        if (context == null)
            return LayoutOutput.hidden();
        return LayoutOutput.fromSizesAndBaselines(context.size, Rect.ZERO, Baselines.fromFirst(context.baselineY));
    }

    static function flexRoot(alignItems:AlignItems, width:Float, height:Float):Style {
        return st(s -> {
            s.display = Flex;
            s.flexDirection = Row;
            s.alignItems = alignItems;
            s.size = new SizeOf<Dimension>(length(width), length(height));
        });
    }

    /** A block of width 40 with a bottom padding of 20 */
    static function paddedBlock():Style {
        return st(s -> {
            s.display = Block;
            s.size = new SizeOf<Dimension>(length(40.0), auto());
            s.padding = rectLP(zero(), zero(), zero(), length(20.0));
        });
    }

    /**
     * Two flex items with different intrinsic baselines are aligned along their baselines
     * when the container uses `align-items: baseline`.
     */
    static function flexBaselineAlignmentUsesMeasureFunctionBaseline() {
        final taffy = new TaffyTree<BaselineContext>();

        // Child A: 50x50 box with baseline 40px from the top
        final childA = taffy.newLeafWithContext(new Style(), new BaselineContext(new Size(50.0, 50.0), 40.0));
        // Child B: 30x30 box with baseline 20px from the top
        final childB = taffy.newLeafWithContext(new Style(), new BaselineContext(new Size(30.0, 30.0), 20.0));

        final root = taffy.newWithChildren(flexRoot(AlignItems.BASELINE, 200.0, 100.0), [childA, childB]);

        taffy.computeLayoutWithMeasure(root, MAX_CONTENT, baselineMeasureFunction);

        final layoutA = taffy.layout(childA);
        final layoutB = taffy.layout(childB);

        // Child A sets the max baseline (40 px from its top), so it sits at the top of the line.
        Assert.eq(layoutA.location.y, 0.0);
        // Child B is shifted down by (40 - 20) = 20 px so its baseline aligns with child A's.
        Assert.eq(layoutB.location.y, 20.0);

        // Sanity-check: both children's baselines now sit at y = 40 in the container.
        Assert.eq(layoutA.location.y + 40.0, layoutB.location.y + 20.0);
    }

    /**
     * A block container child that is a scroll container and has no baseline of its own
     * synthesizes a baseline from its border-box bottom edge, which propagates to the
     * block container's first baseline.
     */
    static function blockScrollContainerChildWithoutBaselineSynthesizesFromBorderBox() {
        final taffy = new TaffyTree<BaselineContext>();

        // An empty `overflow: hidden` block, 30x30
        final scrollChild = taffy.newLeafWithContext(st(s -> {
            s.display = Block;
            s.overflow = new PointOf<Overflow>(Hidden, Hidden);
            s.size = new SizeOf<Dimension>(length(30.0), length(30.0));
        }), new BaselineContext(new Size(30.0, 30.0), null));

        // A block container wrapping the scroll container, with bottom padding so that the
        // synthesized baseline (30) differs from the wrapper's border-box bottom edge (50).
        final itemA = taffy.newWithChildren(paddedBlock(), [scrollChild]);

        // Reference item: 40x80 box with baseline 10px from the top
        final itemB = taffy.newLeafWithContext(new Style(), new BaselineContext(new Size(40.0, 80.0), 10.0));

        final root = taffy.newWithChildren(flexRoot(AlignItems.BASELINE, 200.0, 120.0), [itemA, itemB]);

        taffy.computeLayoutWithMeasure(root, MAX_CONTENT, baselineMeasureFunction);

        // Item A's baseline is synthesized at the scroll container's bottom border edge (30),
        // not at item A's own bottom edge (50). Item A sets the max baseline, so it sits at
        // the top and item B is shifted down by (30 - 10) = 20px.
        Assert.eq(taffy.layout(itemA).location.y, 0.0);
        Assert.eq(taffy.layout(itemB).location.y, 20.0);
    }

    /**
     * A block container child that is NOT a scroll container and has no baseline
     * contributes no baseline to its block container parent.
     */
    static function blockNonScrollContainerChildWithoutBaselineContributesNothing() {
        final taffy = new TaffyTree<BaselineContext>();

        // An empty `overflow: visible` block, 30x30
        final plainChild = taffy.newLeafWithContext(st(s -> {
            s.display = Block;
            s.size = new SizeOf<Dimension>(length(30.0), length(30.0));
        }), new BaselineContext(new Size(30.0, 30.0), null));

        final itemA = taffy.newWithChildren(paddedBlock(), [plainChild]);

        // Reference item: 40x80 box with baseline 10px from the top
        final itemB = taffy.newLeafWithContext(new Style(), new BaselineContext(new Size(40.0, 80.0), 10.0));

        final root = taffy.newWithChildren(flexRoot(AlignItems.BASELINE, 200.0, 120.0), [itemA, itemB]);

        taffy.computeLayoutWithMeasure(root, MAX_CONTENT, baselineMeasureFunction);

        // Item A has no baseline, so the flexbox algorithm synthesizes one at its border-box
        // bottom edge (50). Item B is shifted down by (50 - 10) = 40px.
        Assert.eq(taffy.layout(itemA).location.y, 0.0);
        Assert.eq(taffy.layout(itemB).location.y, 40.0);
    }

    /**
     * A block container child that is a scroll container contributes its content baseline
     * clamped to its border box, so baselines of clipped content cannot leak below the
     * child's border-box bottom edge.
     */
    static function blockScrollContainerChildBaselineIsClampedToBorderBox() {
        final taffy = new TaffyTree<BaselineContext>();

        // Content with a baseline 48px from the top, inside a 30px tall scroll container
        final content = taffy.newLeafWithContext(st(s -> {
            s.display = Block;
        }), new BaselineContext(new Size(30.0, 60.0), 48.0));

        final scrollChild = taffy.newWithChildren(st(s -> {
            s.display = Block;
            s.overflow = new PointOf<Overflow>(Hidden, Hidden);
            s.size = new SizeOf<Dimension>(length(30.0), length(30.0));
        }), [content]);

        final itemA = taffy.newWithChildren(paddedBlock(), [scrollChild]);

        // Reference item: 40x80 box with baseline 10px from the top
        final itemB = taffy.newLeafWithContext(new Style(), new BaselineContext(new Size(40.0, 80.0), 10.0));

        final root = taffy.newWithChildren(flexRoot(AlignItems.BASELINE, 200.0, 120.0), [itemA, itemB]);

        taffy.computeLayoutWithMeasure(root, MAX_CONTENT, baselineMeasureFunction);

        // The content baseline (48) is clamped to the scroll container's border-box height (30).
        // Item A's baseline is 30, so item B is shifted down by (30 - 10) = 20px.
        Assert.eq(taffy.layout(itemA).location.y, 0.0);
        Assert.eq(taffy.layout(itemB).location.y, 20.0);
    }

    /**
     * Sanity-check: without `align-items: baseline`, items align at the cross-start edge
     * regardless of the baseline reported by the measure function.
     */
    static function flexBaselineIsIgnoredWhenAlignmentIsNotBaseline() {
        final taffy = new TaffyTree<BaselineContext>();

        final childA = taffy.newLeafWithContext(new Style(), new BaselineContext(new Size(50.0, 50.0), 40.0));
        final childB = taffy.newLeafWithContext(new Style(), new BaselineContext(new Size(30.0, 30.0), 20.0));

        final root = taffy.newWithChildren(flexRoot(AlignItems.FLEX_START, 200.0, 100.0), [childA, childB]);

        taffy.computeLayoutWithMeasure(root, MAX_CONTENT, baselineMeasureFunction);

        Assert.eq(taffy.layout(childA).location.y, 0.0);
        Assert.eq(taffy.layout(childB).location.y, 0.0);
    }

}
