// Ported from taffy 0.15.0 (repository): tests/hand_written/grid_percentage_rerun.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.SizeOf;
import taffy.style.AvailableSpace;
import taffy.style.Dimension;
import taffy.style.Style;
import taffy.tree.NodeId;
import taffy.tree.TaffyTree;
import taffy.style.AvailableSpace.Definite;
import taffy.geometry.SizeAvail;

/**
 * Percentage track sizing functions resolve against the grid container's size. When that size is
 * indefinite they are treated as auto while computing the container's size and then resolved against
 * that size. This must happen regardless of whether the available space is definite.
 */
class GridPercentageRerunTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("fit_content_percentage_indefinite_container_max_content_available_space", fitContentPercentageIndefiniteContainerMaxContentAvailableSpace),
            new TestCase("fit_content_percentage_indefinite_container_definite_available_space", fitContentPercentageIndefiniteContainerDefiniteAvailableSpace),
            new TestCase("percentage_rows_indefinite_container_max_content_available_space", percentageRowsIndefiniteContainerMaxContentAvailableSpace),
            new TestCase("percentage_rows_indefinite_container_definite_available_space", percentageRowsIndefiniteContainerDefiniteAvailableSpace),
        ];
    }

    /** Returns [container width, item width] */
    static function layoutFitContentPercentColumn(availableWidth:AvailableSpace):Array<Float> {
        final tree = newTestTree();
        final item = tree.newLeafWithContext(new Style(), TestNodeContext.ahemText("HH" + ZWS + "HH" + ZWS + "HH", Horizontal));
        final root = tree.newWithChildren(st(s -> {
            s.display = Grid;
            s.gridTemplateColumns = tracks("fit-content(50%)");
            s.gridTemplateRows = tracks("40px");
        }), [item]);
        tree.computeLayoutWithMeasure(root, new SizeAvail(availableWidth, MaxContent), testMeasureFunction);
        return [tree.layout(root).size.width, tree.layout(item).size.width];
    }

    static function fitContentPercentageIndefiniteContainerMaxContentAvailableSpace() {
        final r = layoutFitContentPercentColumn(MaxContent);
        Assert.eq(r[0], 60.0);
        Assert.eq(r[1], 30.0);
    }

    static function fitContentPercentageIndefiniteContainerDefiniteAvailableSpace() {
        final r = layoutFitContentPercentColumn(Definite(200.0));
        Assert.eq(r[0], 60.0);
        Assert.eq(r[1], 30.0);
    }

    /**
     * Returns [container height, row 1 height, row 2 height, row 3 height] for a grid with
     * `grid-template-rows: auto 20% auto` whose items are 20px, 60px and 20px tall respectively.
     */
    static function layoutPercentRowShrinkwrap(availableHeight:AvailableSpace):Array<Float> {
        final tree = new TaffyTree<Int>();
        final item = (height:Float) -> tree.newLeaf(st(s -> {
            s.size = new SizeOf<Dimension>(length(20.0), length(height));
        }));
        final a = item(20.0);
        final b = item(60.0);
        final c = item(20.0);
        final root = tree.newWithChildren(st(s -> {
            s.display = Grid;
            s.gridTemplateColumns = tracks("auto");
            s.gridTemplateRows = tracks("auto 20% auto");
        }), [a, b, c]);
        tree.computeLayout(root, new SizeAvail(Definite(200.0), availableHeight));
        final total = tree.layout(root).size.height;
        final y = (node:NodeId) -> tree.layout(node).location.y;
        return [total, y(b), y(c) - y(b), total - y(c)];
    }

    static function assertRows(r:Array<Float>) {
        Assert.eq(r[0], 100.0);
        Assert.eq(r[1], 40.0);
        Assert.eq(r[2], 20.0);
        Assert.eq(r[3], 40.0);
    }

    /**
     * Percentage rows must be re-resolved against the container's (first pass) height even when column sizing
     * is not re-run. The auto rows then stretch to fill the remaining space.
     */
    static function percentageRowsIndefiniteContainerMaxContentAvailableSpace() {
        assertRows(layoutPercentRowShrinkwrap(MaxContent));
    }

    static function percentageRowsIndefiniteContainerDefiniteAvailableSpace() {
        assertRows(layoutPercentRowShrinkwrap(Definite(500.0)));
    }

}
