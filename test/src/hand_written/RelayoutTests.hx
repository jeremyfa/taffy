// Ported from taffy 0.15.0 (repository): tests/hand_written/relayout.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.SizeOf;
import taffy.style.AlignContent;
import taffy.style.AlignItems;
import taffy.style.Dimension;
import taffy.style.Display;
import taffy.style.LengthPercentageAuto;
import taffy.style.Style;
import taffy.tree.Layout;
import taffy.tree.NodeId;
import taffy.tree.TaffyTree;

class RelayoutTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("relayout", relayout),
            new TestCase("toggle_root_display_none", toggleRootDisplayNone),
            new TestCase("toggle_root_display_none_with_children", toggleRootDisplayNoneWithChildren),
            new TestCase("toggle_flex_child_display_none", toggleFlexChildDisplayNone),
            new TestCase("toggle_flex_container_display_none", toggleFlexContainerDisplayNone),
            new TestCase("toggle_grid_child_display_none", toggleGridChildDisplayNone),
            new TestCase("toggle_grid_container_display_none", toggleGridContainerDisplayNone),
            new TestCase("relayout_is_stable_with_rounding", relayoutIsStableWithRounding),
            new TestCase("block_child_does_not_keep_collapsed_margin_as_flex_item", blockChildDoesNotKeepCollapsedMarginAsFlexItem),
            new TestCase("block_child_does_not_keep_collapsed_margin_as_grid_item", blockChildDoesNotKeepCollapsedMarginAsGridItem),
            new TestCase("flex_base_size_is_not_answered_by_an_inherent_size_measurement", flexBaseSizeIsNotAnsweredByAnInherentSizeMeasurement),
            new TestCase("a_percentage_height_is_not_reused_after_its_containing_block_loses_its_height", aPercentageHeightIsNotReusedAfterItsContainingBlockLosesItsHeight),
        ];
    }

    static function sized(width:Dimension, height:Dimension):SizeOf<Dimension> {
        return new SizeOf<Dimension>(width, height);
    }

    static function assertZeroLayout(layout:Layout, ?pos:haxe.PosInfos) {
        Assert.eq(layout.location.x, 0.0, null, pos);
        Assert.eq(layout.location.y, 0.0, null, pos);
        Assert.eq(layout.size.width, 0.0, null, pos);
        Assert.eq(layout.size.height, 0.0, null, pos);
    }

    static function assert100Layout(layout:Layout, ?pos:haxe.PosInfos) {
        Assert.eq(layout.location.x, 0.0, null, pos);
        Assert.eq(layout.location.y, 0.0, null, pos);
        Assert.eq(layout.size.width, 100.0, null, pos);
        Assert.eq(layout.size.height, 100.0, null, pos);
    }

    static function relayout() {
        final taffy = newTestTree();
        final node1 = taffy.newLeaf(st(s -> {
            s.size = sized(length(8.0), length(80.0));
        }));
        final node0 = taffy.newWithChildren(st(s -> {
            s.alignSelf = AlignItems.CENTER;
            s.size = sized(Dimension.AUTO, Dimension.AUTO);
        }), [node1]);
        final node = taffy.newWithChildren(st(s -> {
            s.size = sized(Dimension.percent(1.0), Dimension.percent(1.0));
        }), [node0]);
        taffy.computeLayout(node, definite(100.0, 100.0));
        final initial = taffy.layout(node).location;
        final initial0 = taffy.layout(node0).location;
        final initial1 = taffy.layout(node1).location;
        for (_ in 1...10) {
            taffy.computeLayout(node, definite(100.0, 100.0));
            Assert.eqPoint(taffy.layout(node).location, initial.x, initial.y);
            Assert.eqPoint(taffy.layout(node0).location, initial0.x, initial0.y);
            Assert.eqPoint(taffy.layout(node1).location, initial1.x, initial1.y);
        }
    }

    static function hiddenStyle():Style {
        return st(s -> {
            s.display = Display.None;
            s.size = sized(length(100.0), length(100.0));
        });
    }

    static function displayStyle(display:Display):Style {
        return st(s -> {
            s.display = display;
            s.size = sized(length(100.0), length(100.0));
        });
    }

    static function toggleRootDisplayNone() {
        // Setup
        final taffy = newTestTree();
        final node = taffy.newLeaf(hiddenStyle());

        // Layout 1 (None)
        taffy.computeLayout(node, MAX_CONTENT);
        assertZeroLayout(taffy.layout(node));

        // Layout 2 (Flex)
        taffy.setStyle(node, displayStyle(Flex));
        taffy.computeLayout(node, MAX_CONTENT);
        assert100Layout(taffy.layout(node));

        // Layout 3 (None)
        taffy.setStyle(node, hiddenStyle());
        taffy.computeLayout(node, MAX_CONTENT);
        assertZeroLayout(taffy.layout(node));
    }

    static function toggleRootDisplayNoneWithChildren() {
        final taffy = newTestTree();

        final child = taffy.newLeaf(st(s -> {
            s.size = sized(length(800.0), length(100.0));
        }));

        final parent = taffy.newWithChildren(st(s -> {
            s.size = sized(length(800.0), length(100.0));
        }), [child]);

        final root = taffy.newWithChildren(new Style(), [parent]);
        taffy.computeLayout(root, MAX_CONTENT);
        Assert.eq(taffy.layout(child).size.width, 800.0);
        Assert.eq(taffy.layout(child).size.height, 100.0);

        taffy.setStyle(root, st(s -> {
            s.display = Display.None;
        }));
        taffy.computeLayout(root, MAX_CONTENT);
        Assert.eq(taffy.layout(child).size.width, 0.0);
        Assert.eq(taffy.layout(child).size.height, 0.0);

        taffy.setStyle(root, new Style());
        taffy.computeLayout(root, MAX_CONTENT);
        Assert.eq(taffy.layout(parent).size.width, 800.0);
        Assert.eq(taffy.layout(parent).size.height, 100.0);
        Assert.eq(taffy.layout(child).size.width, 800.0);
        Assert.eq(taffy.layout(child).size.height, 100.0);
    }

    /** Toggles the display of a child of a `display` container (Rust `toggle_flex_child_display_none` / `toggle_grid_child_display_none`) */
    static function toggleChildDisplayNone(display:Display) {
        // Setup
        final taffy = newTestTree();
        final node = taffy.newLeaf(hiddenStyle());
        final root = taffy.newWithChildren(displayStyle(display), [node]);

        // Layout 1 (None)
        taffy.computeLayout(root, MAX_CONTENT);
        assertZeroLayout(taffy.layout(node));

        // Layout 2 (Flex)
        taffy.setStyle(node, displayStyle(display));
        taffy.computeLayout(root, MAX_CONTENT);
        assert100Layout(taffy.layout(node));

        // Layout 3 (None)
        taffy.setStyle(node, hiddenStyle());
        taffy.computeLayout(root, MAX_CONTENT);
        assertZeroLayout(taffy.layout(node));
    }

    /** Toggles the display of a container (Rust `toggle_flex_container_display_none` / `toggle_grid_container_display_none`) */
    static function toggleContainerDisplayNone(display:Display) {
        // Setup
        final taffy = newTestTree();
        final node = taffy.newLeaf(hiddenStyle());
        final root = taffy.newWithChildren(hiddenStyle(), [node]);

        // Layout 1 (None)
        taffy.computeLayout(root, MAX_CONTENT);
        assertZeroLayout(taffy.layout(root));

        // Layout 2 (Flex)
        taffy.setStyle(root, displayStyle(display));
        taffy.computeLayout(root, MAX_CONTENT);
        assert100Layout(taffy.layout(root));

        // Layout 3 (None)
        taffy.setStyle(root, hiddenStyle());
        taffy.computeLayout(root, MAX_CONTENT);
        assertZeroLayout(taffy.layout(root));
    }

    static function toggleFlexChildDisplayNone() {
        toggleChildDisplayNone(Flex);
    }

    static function toggleFlexContainerDisplayNone() {
        toggleContainerDisplayNone(Flex);
    }

    static function toggleGridChildDisplayNone() {
        toggleChildDisplayNone(Grid);
    }

    static function toggleGridContainerDisplayNone() {
        toggleContainerDisplayNone(Grid);
    }

    static function relayoutIsStableWithRounding() {
        final taffy = newTestTree();
        taffy.enableRounding();

        // <div style="width: 1920px; height: 1080px">
        //     <div style="width: 100%; left: 1.5px">
        //         <div style="width: 150px; justify-content: end">
        //             <div style="min-width: 300px" />
        //         </div>
        //     </div>
        // </div>

        final inner = taffy.newLeaf(st(s -> {
            s.minSize = new SizeOf<LengthPercentageAuto>(length(300.0), auto());
        }));
        final wrapper = taffy.newWithChildren(st(s -> {
            s.size = sized(length(150.0), auto());
            s.justifyContent = AlignContent.END;
        }), [inner]);
        final outer = taffy.newWithChildren(st(s -> {
            s.size = sized(percent(1.0), auto());
            s.position = Relative;
            s.inset = rectLPA(length(1.5), auto(), auto(), auto());
        }), [wrapper]);
        final root = taffy.newWithChildren(st(s -> {
            s.size = sized(length(1920.0), length(1080.0));
        }), [outer]);

        // Compute and assert initial layout.

        taffy.computeLayout(root, MAX_CONTENT);

        final initialRootLayout = taffy.layout(root);
        Assert.eq(initialRootLayout.location.x, 0.0);
        Assert.eq(initialRootLayout.location.y, 0.0);
        Assert.eq(initialRootLayout.size.width, 1920.0);
        Assert.eq(initialRootLayout.size.height, 1080.0);

        final initialOuterLayout = taffy.layout(outer);
        Assert.eq(initialOuterLayout.location.x, 2.0);
        Assert.eq(initialOuterLayout.location.y, 0.0);
        Assert.eq(initialOuterLayout.size.width, 1920.0);
        Assert.eq(initialOuterLayout.size.height, 1080.0);

        final initialWrapperLayout = taffy.layout(wrapper);
        Assert.eq(initialWrapperLayout.location.x, 0.0);
        Assert.eq(initialWrapperLayout.location.y, 0.0);
        Assert.eq(initialWrapperLayout.size.width, 150.0);
        Assert.eq(initialWrapperLayout.size.height, 1080.0);

        final initialInnerLayout = taffy.layout(inner);
        Assert.eq(initialInnerLayout.location.x, -150.0);
        Assert.eq(initialInnerLayout.location.y, 0.0);
        Assert.eq(initialInnerLayout.size.width, 300.0);
        Assert.eq(initialInnerLayout.size.height, 1080.0);

        // Recompute and assert that new layout marks initial layout each time
        for (_ in 0...5) {
            taffy.markDirty(root);
            taffy.computeLayout(root, MAX_CONTENT);

            final rootLayout = taffy.layout(root);
            Assert.eq(initialRootLayout.location.x, rootLayout.location.x);
            Assert.eq(initialRootLayout.location.y, rootLayout.location.y);
            Assert.eq(initialRootLayout.size.width, rootLayout.size.width);
            Assert.eq(initialRootLayout.size.height, rootLayout.size.height);
            final outerLayout = taffy.layout(outer);
            Assert.eq(initialOuterLayout.location.x, outerLayout.location.x);
            Assert.eq(initialOuterLayout.location.y, outerLayout.location.y);
            Assert.eq(initialOuterLayout.size.width, outerLayout.size.width);
            Assert.eq(initialOuterLayout.size.height, outerLayout.size.height);
            final wrapperLayout = taffy.layout(wrapper);
            Assert.eq(initialWrapperLayout.location.x, wrapperLayout.location.x);
            Assert.eq(initialWrapperLayout.location.x, wrapperLayout.location.y);
            Assert.eq(initialWrapperLayout.size.width, wrapperLayout.size.width);
            Assert.eq(initialWrapperLayout.size.height, wrapperLayout.size.height);
            final innerLayout = taffy.layout(inner);
            Assert.eq(initialInnerLayout.location.x, innerLayout.location.x);
            Assert.eq(initialInnerLayout.location.y, innerLayout.location.y);
            Assert.eq(initialInnerLayout.size.width, innerLayout.size.width);
            Assert.eq(initialInnerLayout.size.height, innerLayout.size.height);
        }
    }

    /**
     * Lays out the tree that `build` makes with `before`, restyles the node that `build` returns first
     * with `after` and lays the tree out again. Returns the unrounded layout of every node that `build`
     * returns, alongside those of a fresh tree built with `after` directly. `build` returns the root last.
     */
    static function relayoutAndFresh(before:Style, after:Style, build:(TaffyTree<TestNodeContext>, Style) -> Array<NodeId>):{relaid:Array<Layout>, fresh:Array<Layout>} {
        final layouts = (tree:TaffyTree<TestNodeContext>, ids:Array<NodeId>) -> [for (id in ids) tree.unroundedLayout(id)];

        final tree = newTestTree();
        final ids = build(tree, before);
        final root = ids[ids.length - 1];
        tree.computeLayout(root, MAX_CONTENT);
        tree.setStyle(ids[0], after.clone());
        tree.computeLayout(root, MAX_CONTENT);

        final fresh = newTestTree();
        final freshIds = build(fresh, after);
        fresh.computeLayout(freshIds[freshIds.length - 1], MAX_CONTENT);

        return {relaid: layouts(tree, ids), fresh: layouts(fresh, freshIds)};
    }

    /**
     * The outer box becomes `container`. The inner box's margin collapses through the middle box
     * only while the middle box is in a block formatting context with its parent: as a flex or grid item
     * the middle box establishes an independent formatting context, which contains the margin.
     */
    static function relayoutBlockParentAs(container:Style) {
        final size = sized(length(100.0), length(200.0));
        final block = st(s -> {
            s.display = Block;
            s.size = size;
        });
        final containerStyle = stFrom(container, s -> {
            s.size = size;
        });

        final r = relayoutAndFresh(block, containerStyle, (tree, rootStyle) -> {
            final inner = tree.newLeaf(st(s -> {
                s.display = Block;
                s.size = sized(auto(), length(10.0));
                s.margin = rectLPA(zero(), zero(), length(20.0), zero());
            }));
            final middle = tree.newWithChildren(st(s -> {
                s.display = Block;
                s.size = sized(auto(), length(50.0));
            }), [inner]);
            final root = tree.newWithChildren(rootStyle, [middle]);
            return [root, middle, inner, root];
        });

        Assert.eq(r.fresh[1].location.y, 0.0, "the item is at the top of its container");
        Assert.eq(r.fresh[2].location.y, 20.0, "the item contains its child's margin");
        Assert.eqLayouts(r.relaid, r.fresh);
    }

    /**
     * A flex container lays its items out with `SizingMode.ContentSize` and without collapsible
     * margins. The block container it was before used `SizingMode.InherentSize` and collapsible margins.
     */
    static function blockChildDoesNotKeepCollapsedMarginAsFlexItem() {
        relayoutBlockParentAs(st(s -> {
            s.display = Flex;
            s.flexDirection = Column;
        }));
    }

    /**
     * A grid container lays its items out with `SizingMode.InherentSize`, as the block container it
     * was before did: only `verticalMarginsAreCollapsible` differs between the two layout inputs.
     */
    static function blockChildDoesNotKeepCollapsedMarginAsGridItem() {
        relayoutBlockParentAs(st(s -> {
            s.display = Grid;
        }));
    }

    /**
     * The outer box (a grid) then becomes `display: flex`. The grid container measured the first item with
     * `SizingMode.InherentSize`, which applies the item's `min-width`. The flex container measures
     * the same item's flex base size with `SizingMode.ContentSize`, which does not: both items
     * have a flex base size of zero and grow equally.
     */
    static function flexBaseSizeIsNotAnsweredByAnInherentSizeMeasurement() {
        final container = (display:Display) -> st(s -> {
            s.display = display;
            s.size = sized(length(100.0), auto());
        });

        final r = relayoutAndFresh(container(Grid), container(Flex), (tree, rootStyle) -> {
            final first = tree.newLeaf(st(s -> {
                s.display = Grid;
                s.flexGrow = 1.0;
                s.size = sized(auto(), length(20.0));
                s.minSize = new SizeOf<LengthPercentageAuto>(length(40.0), auto());
            }));
            final second = tree.newLeaf(st(s -> {
                s.display = Block;
                s.flexGrow = 1.0;
                s.size = sized(auto(), length(20.0));
            }));
            final root = tree.newWithChildren(rootStyle, [first, second]);
            return [root, first, second, root];
        });

        Assert.eq(r.fresh[1].size.width, 50.0);
        Assert.eq(r.fresh[2].size.width, 50.0);
        Assert.eqLayouts(r.relaid, r.fresh);
    }

    static function aPercentageHeightIsNotReusedAfterItsContainingBlockLosesItsHeight() {
        // <div style="display:flex;flex-direction:column;width:78px">
        //   <div style="width:78px;height:62px">
        //     <div style="display:flex;width:31px;height:86%"> <div style="height:19px"></div>
        // </div></div></div>, then the middle block's height becomes auto: the item's
        // percentage no longer resolves (CSS 2.1 10.5) and it is 19px tall, not 53.32px.
        final block = (height:Dimension) -> st(s -> {
            s.display = Block;
            s.size = sized(Dimension.length(78.0), height);
        });
        final r = relayoutAndFresh(block(Dimension.length(62.0)), block(Dimension.auto()), (tree, middleStyle) -> {
            final leaf = tree.newLeaf(st(s -> {
                s.display = Block;
                s.size = sized(Dimension.auto(), Dimension.length(19.0));
            }));
            final item = tree.newWithChildren(st(s -> {
                s.display = Flex;
                s.size = sized(Dimension.length(31.0), Dimension.percent(0.86));
            }), [leaf]);
            final middle = tree.newWithChildren(middleStyle, [item]);
            final root = tree.newWithChildren(st(s -> {
                s.display = Flex;
                s.flexDirection = Column;
                s.size = sized(Dimension.length(78.0), Dimension.auto());
            }), [middle]);
            return [middle, item, leaf, root];
        });
        Assert.eq(r.fresh[1].size.height, 19.0);
        Assert.eqLayouts(r.relaid, r.fresh);
    }

}
