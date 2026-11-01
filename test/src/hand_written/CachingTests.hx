// Ported from taffy 0.15.0 (repository): tests/hand_written/caching.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.SizeOf;
import taffy.style.AlignItems;
import taffy.style.Dimension;
import taffy.style.FlexDirection;
import taffy.style.Style;

class CachingTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("measure_count_flexbox", measureCountFlexbox),
            new TestCase("measure_count_grid", measureCountGrid),
            new TestCase("measure_count_nested_grid", measureCountNestedGrid),
            new TestCase("measure_count_grid_item_with_known_width", measureCountGridItemWithKnownWidth),
            new TestCase("measure_count_grid_item_in_fixed_track", measureCountGridItemInFixedTrack),
            new TestCase("measure_count_flex_in_grid", measureCountFlexInGrid),
            new TestCase("grid_block_item_height_not_polluted_by_width_measure", gridBlockItemHeightNotPollutedByWidthMeasure),
            new TestCase("grid_item_spanning_only_unaffected_tracks_is_not_measured", gridItemSpanningOnlyUnaffectedTracksIsNotMeasured),
        ];
    }

    static function nodeContext():TestNodeContext {
        return TestNodeContext.fixed(50.0, 50.0);
    }

    static function gridStyle():Style {
        return st(s -> {
            s.display = Grid;
        });
    }

    static function hhText():TestNodeContext {
        return TestNodeContext.ahemText("HH" + ZWS + "HH" + ZWS + "HH" + ZWS + "HH", Horizontal);
    }

    static function measureCountFlexbox() {
        final taffy = newTestTree();

        final leaf = taffy.newLeafWithContext(new Style(), nodeContext());

        var node = taffy.newWithChildren(Style.DEFAULT, [leaf]);
        for (_ in 0...100) {
            node = taffy.newWithChildren(Style.DEFAULT, [node]);
        }

        taffy.computeLayoutWithMeasure(node, MAX_CONTENT, testMeasureFunction);

        Assert.eqInt(taffy.getNodeContext(leaf).count, 7);
    }

    static function measureCountGrid() {
        final taffy = newTestTree();

        final leaf = taffy.newLeafWithContext(gridStyle(), nodeContext());

        var node = taffy.newWithChildren(Style.DEFAULT, [leaf]);
        for (_ in 0...100) {
            node = taffy.newWithChildren(Style.DEFAULT, [node]);
        }

        taffy.computeLayoutWithMeasure(node, MAX_CONTENT, testMeasureFunction);
        Assert.eqInt(taffy.getNodeContext(leaf).count, 7);
    }

    /**
     * A grid container that is only asked for its width (e.g. because it is an item of another
     * grid whose columns are being sized) must not size its rows.
     */
    static function measureCountNestedGrid() {
        final taffy = newTestTree();

        // The leaf's min-content width (20), max-content width (80) and final width (50) all differ, so
        // measuring its height at each of the first two widths can never be served from the cache.
        final leaf = taffy.newLeafWithContext(new Style(), hhText());
        final inner = taffy.newWithChildren(gridStyle(), [leaf]);
        final middle = taffy.newWithChildren(gridStyle(), [inner]);
        final outer = taffy.newWithChildren(stFrom(gridStyle(), s -> {
            s.size = new SizeOf<Dimension>(length(50.0), auto());
        }), [middle]);

        taffy.computeLayoutWithMeasure(outer, MAX_CONTENT, testMeasureFunction);
        Assert.eqSize(taffy.layout(leaf).size, 50.0, 20.0);
        Assert.eqInt(taffy.getNodeContext(leaf).count, 6);
    }

    /**
     * A grid item whose size in the axis being measured is already known (here: a definite width) does not
     * need to be measured to determine its contribution to the size of the tracks in that axis.
     */
    static function measureCountGridItemWithKnownWidth() {
        final taffy = newTestTree();

        final leaf = taffy.newLeafWithContext(st(s -> {
            s.size = new SizeOf<Dimension>(length(40.0), auto());
        }), hhText());
        final grid = taffy.newWithChildren(gridStyle(), [leaf]);

        taffy.computeLayoutWithMeasure(grid, MAX_CONTENT, testMeasureFunction);
        Assert.eqSize(taffy.layout(grid).size, 40.0, 20.0);
        Assert.eqSize(taffy.layout(leaf).size, 40.0, 20.0);
        Assert.eqInt(taffy.getNodeContext(leaf).count, 3);
    }

    /**
     * A grid item in a track that is not intrinsically sized does not contribute to the size of that track, so
     * it does not need to be measured when sizing the tracks.
     */
    static function measureCountGridItemInFixedTrack() {
        final taffy = newTestTree();

        final leaf = taffy.newLeafWithContext(st(s -> {
            s.justifySelf = AlignItems.START;
            s.gridColumn = gridLine(1);
        }), hhText());
        final sibling = taffy.newLeaf(st(s -> {
            s.size = new SizeOf<Dimension>(length(50.0), length(50.0));
            s.gridColumn = gridLine(2);
        }));
        final grid = taffy.newWithChildren(st(s -> {
            s.display = Grid;
            s.gridTemplateColumns = tracks("100px auto");
        }), [leaf, sibling]);

        taffy.computeLayoutWithMeasure(grid, MAX_CONTENT, testMeasureFunction);
        Assert.eqSize(taffy.layout(grid).size, 150.0, 50.0);
        Assert.eqSize(taffy.layout(leaf).size, 80.0, 50.0);
        Assert.eqInt(taffy.getNodeContext(leaf).count, 3);
    }

    /**
     * A flex container that is only asked for its main size (e.g. because it is an item of a grid
     * whose tracks are being sized) must not measure the cross size of its items.
     */
    static function measureCountFlexInGrid() {
        final cases:Array<{direction:FlexDirection, expected:Int}> = [{direction: Row, expected: 10}, {direction: Column, expected: 11}];
        for (c in cases) {
            final taffy = newTestTree();

            final leaf = taffy.newLeafWithContext(new Style(), hhText());
            final flex = taffy.newWithChildren(st(s -> {
                s.display = Flex;
                s.flexDirection = c.direction;
            }), [leaf]);
            final grid = taffy.newWithChildren(st(s -> {
                s.display = Grid;
                s.size = new SizeOf<Dimension>(length(50.0), auto());
            }), [flex]);

            taffy.computeLayoutWithMeasure(grid, MAX_CONTENT, testMeasureFunction);
            final count = taffy.getNodeContext(leaf).count;
            Assert.eqSize(taffy.layout(leaf).size, 50.0, 20.0);
            Assert.eqInt(count, c.expected);
        }
    }

    /**
     * A node's size measured for one axis must not be returned from the cache when the other
     * axis is queried, as the size in the non-requested axis is not guaranteed to be valid.
     */
    static function gridBlockItemHeightNotPollutedByWidthMeasure() {
        final taffy = newTestTree();

        final itemStyle = (row:Int) -> st(s -> {
            s.display = Block;
            s.gridRow = placement(Line(row), Line(row + 1));
            s.gridColumn = placement(Line(1), Line(2));
        });

        // Each grid item is a block container wrapping a measured leaf. The block layout
        // algorithm short-circuits width-only measures without computing a height, so a
        // subsequent height query must not reuse that cached result.
        final makeItem = (row:Int) -> {
            final leaf = taffy.newLeafWithContext(new Style(), TestNodeContext.fixed(100.0, 19.0));
            return taffy.newWithChildren(itemStyle(row), [leaf]);
        };
        final a = makeItem(1);
        final b = makeItem(2);
        final c = makeItem(3);

        final container = taffy.newWithChildren(st(s -> {
            s.display = Grid;
            // The `auto` column is required to trigger intrinsic (width) sizing of the
            // items before the row-sizing (height) pass.
            s.gridTemplateColumns = tracks("60% auto");
            s.size = new SizeOf<Dimension>(length(1000.0), auto());
        }), [a, b, c]);

        taffy.computeLayoutWithMeasure(container, definite(1000.0, 1000.0), testMeasureFunction);

        final nodes = [a, b, c];
        for (index in 0...nodes.length) {
            final layout = taffy.layout(nodes[index]);
            Assert.eq(layout.size.height, 19.0);
            Assert.eq(layout.location.y, 19.0 * index);
        }
    }

    /**
     * An item whose spanned tracks cannot receive its min-/max-content contribution in any
     * intrinsic track sizing step (definite min, flexible max) must not be measured for it.
     */
    static function gridItemSpanningOnlyUnaffectedTracksIsNotMeasured() {
        final taffy = newTestTree();

        final text = TestNodeContext.ahemText("HH HH HH HH", Horizontal);
        final leafStyle = st(s -> {
            s.gridColumn = placement(Line(2), Line(3));
        });
        final leaf = taffy.newLeafWithContext(leafStyle, text);
        final grid = taffy.newWithChildren(st(s -> {
            s.display = Grid;
            s.size = new SizeOf<Dimension>(length(400.0), length(50.0));
            s.gridTemplateColumns = tracks("100px minmax(0px, 1fr)");
            s.gridTemplateRows = tracks("50px");
        }), [leaf]);

        taffy.computeLayoutWithMeasure(grid, MAX_CONTENT, testMeasureFunction);

        // Only the final layout pass measures the leaf; track sizing does not.
        Assert.eq(taffy.layout(leaf).size.width, 300.0);
        Assert.eqInt(taffy.getNodeContext(leaf).count, 1);
    }

}
