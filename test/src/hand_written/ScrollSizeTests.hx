// Ported from taffy 0.15.0 (repository): tests/hand_written/scroll_size.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.PointOf;
import taffy.geometry.RectOf;
import taffy.geometry.SizeOf;
import taffy.style.Dimension;
import taffy.style.Display;
import taffy.style.LengthPercentage;
import taffy.style.Overflow;
import taffy.tree.Layout;

/**
 * The maximum scroll offset is the content size less the size of the padding
 * box, so it must not depend on which side a border sits on, and must agree
 * across the layout algorithms.
 */
class ScrollSizeTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("scroll_height_does_not_depend_on_which_edge_the_border_is_on", scrollHeightDoesNotDependOnWhichEdgeTheBorderIsOn),
            new TestCase("scroll_height_is_the_content_beyond_the_padding_box", scrollHeightIsTheContentBeyondThePaddingBox),
            new TestCase("scrollable_overflow_excludes_the_containers_own_border", scrollableOverflowExcludesTheContainersOwnBorder),
            new TestCase("scrollable_overflow_includes_the_containers_own_padding", scrollableOverflowIncludesTheContainersOwnPadding),
            new TestCase("scrollable_overflow_excludes_the_own_padding_of_a_non_scroll_container", scrollableOverflowExcludesTheOwnPaddingOfANonScrollContainer),
            new TestCase("leaf_content_size_includes_the_containers_own_padding", leafContentSizeIncludesTheContainersOwnPadding),
            new TestCase("leaf_content_size_excludes_the_own_padding_of_a_non_scroll_container", leafContentSizeExcludesTheOwnPaddingOfANonScrollContainer),
            new TestCase("scroll_height_accounts_for_the_containers_own_padding", scrollHeightAccountsForTheContainersOwnPadding),
            new TestCase("grid_scrollable_overflow_includes_item_positions_in_overflowing_tracks", gridScrollableOverflowIncludesItemPositionsInOverflowingTracks),
            new TestCase("scroll_height_agrees_with_borders_and_padding_combined", scrollHeightAgreesWithBordersAndPaddingCombined),
        ];
    }

    static inline final CONTENT:Float = 1000.0;
    static inline final CONTAINER:Float = 200.0;
    static inline final BORDER:Float = 20.0;
    static inline final PADDING:Float = 20.0;

    static final DISPLAYS:Array<Display> = [Block, Flex, Grid];

    /** The (top, bottom) pairs used by the tests, for a given edge size */
    static function edgePairs(size:Float):Array<Array<Float>> {
        return [[size, 0.0], [0.0, size], [size, size], [0.0, 0.0]];
    }

    static function scrollerWithPadding(display:Display, border:RectOf<LengthPercentage>, padding:RectOf<LengthPercentage>):Layout {
        final tree = newTestTree();
        final child = tree.newLeaf(st(s -> {
            s.size = new SizeOf<Dimension>(length(100.0), length(CONTENT));
        }));
        final node = tree.newWithChildren(st(s -> {
            s.display = display;
            s.boxSizing = BorderBox;
            s.size = new SizeOf<Dimension>(length(300.0), length(CONTAINER));
            s.border = border;
            s.padding = padding;
            s.overflow = new PointOf<Overflow>(Scroll, Scroll);
        }), [child]);

        tree.computeLayout(node, MAX_CONTENT);
        return tree.layout(node);
    }

    static function scroller(display:Display, border:RectOf<LengthPercentage>):Layout {
        return scrollerWithPadding(display, border, edge(0.0, 0.0));
    }

    static function edge(top:Float, bottom:Float):RectOf<LengthPercentage> {
        return rectLP(
            LengthPercentage.length(0.0),
            LengthPercentage.length(0.0),
            LengthPercentage.length(top),
            LengthPercentage.length(bottom)
        );
    }

    static function scrollHeightDoesNotDependOnWhichEdgeTheBorderIsOn() {
        for (display in DISPLAYS) {
            final top = scroller(display, edge(BORDER, 0.0));
            final bottom = scroller(display, edge(0.0, BORDER));

            Assert.eq(top.scrollHeight(), bottom.scrollHeight(),
                '${displayName(display)}: border-top gave ${top.scrollHeight()} and border-bottom gave ${bottom.scrollHeight()}');
        }
    }

    static function scrollHeightIsTheContentBeyondThePaddingBox() {
        for (display in DISPLAYS) {
            for (pair in edgePairs(BORDER)) {
                final top = pair[0];
                final bottom = pair[1];
                final layout = scroller(display, edge(top, bottom));
                final paddingBox = CONTAINER - top - bottom;

                Assert.eq(layout.scrollHeight(), CONTENT - paddingBox, '${displayName(display)} with border $top/$bottom');
            }
        }
    }

    static function scrollableOverflowExcludesTheContainersOwnBorder() {
        for (display in DISPLAYS) {
            for (pair in edgePairs(BORDER)) {
                final top = pair[0];
                final bottom = pair[1];
                final layout = scroller(display, edge(top, bottom));

                Assert.eq(layout.scrollableOverflowRect.bottom, CONTENT, '${displayName(display)} with border $top/$bottom');
            }
        }
    }

    static function scrollableOverflowIncludesTheContainersOwnPadding() {
        for (display in DISPLAYS) {
            for (pair in edgePairs(PADDING)) {
                final top = pair[0];
                final bottom = pair[1];
                final layout = scrollerWithPadding(display, edge(0.0, 0.0), edge(top, bottom));

                Assert.eq(layout.scrollableOverflowRect.bottom, CONTENT + top + bottom, '${displayName(display)} with padding $top/$bottom');
            }
        }
    }

    static function scrollableOverflowExcludesTheOwnPaddingOfANonScrollContainer() {
        for (display in DISPLAYS) {
            for (pair in edgePairs(PADDING)) {
                final top = pair[0];
                final bottom = pair[1];
                final tree = newTestTree();
                final child = tree.newLeaf(st(s -> {
                    s.size = new SizeOf<Dimension>(length(100.0), length(CONTENT));
                }));
                final node = tree.newWithChildren(st(s -> {
                    s.display = display;
                    s.boxSizing = BorderBox;
                    s.size = new SizeOf<Dimension>(length(300.0), length(CONTAINER));
                    s.padding = edge(top, bottom);
                }), [child]);

                tree.computeLayout(node, MAX_CONTENT);
                final layout = tree.layout(node);

                // A box that is not a scroll container does not extend its scrollable overflow
                // region by its own padding: only the content contributes.
                Assert.eq(layout.scrollableOverflowRect.bottom, top + CONTENT, '${displayName(display)} with padding $top/$bottom');
            }
        }
    }

    static function measuredLeaf(overflow:Overflow, padding:RectOf<LengthPercentage>):Layout {
        final tree = newTestTree();
        final node = tree.newLeafWithContext(st(s -> {
            s.boxSizing = BorderBox;
            s.size = new SizeOf<Dimension>(length(300.0), length(CONTAINER));
            s.padding = padding;
            s.overflow = new PointOf<Overflow>(overflow, overflow);
        }), TestNodeContext.fixed(100.0, CONTENT));

        tree.computeLayoutWithMeasure(node, MAX_CONTENT, testMeasureFunction);
        return tree.layout(node);
    }

    static function leafContentSizeIncludesTheContainersOwnPadding() {
        for (pair in edgePairs(PADDING)) {
            final top = pair[0];
            final bottom = pair[1];
            final layout = measuredLeaf(Scroll, edge(top, bottom));

            Assert.eq(layout.scrollableOverflowRect.bottom, top + CONTENT + bottom, 'Leaf with padding $top/$bottom');
        }
    }

    static function leafContentSizeExcludesTheOwnPaddingOfANonScrollContainer() {
        for (pair in edgePairs(PADDING)) {
            final top = pair[0];
            final bottom = pair[1];
            final layout = measuredLeaf(Visible, edge(top, bottom));

            // A box that is not a scroll container does not extend its scrollable overflow
            // region by its own padding: only the content contributes.
            Assert.eq(layout.scrollableOverflowRect.bottom, top + CONTENT, 'Leaf with padding $top/$bottom');
        }
    }

    static function scrollHeightAccountsForTheContainersOwnPadding() {
        for (display in DISPLAYS) {
            for (pair in edgePairs(PADDING)) {
                final top = pair[0];
                final bottom = pair[1];
                final layout = scrollerWithPadding(display, edge(0.0, 0.0), edge(top, bottom));

                // The scrollable overflow region runs from the padding-box origin to the end of
                // the content plus the container's end-side padding.
                final expected = (top + CONTENT + bottom) - CONTAINER;
                Assert.eq(layout.scrollHeight(), expected, '${displayName(display)} with padding $top/$bottom');
            }
        }
    }

    /**
     * Items in overflowing rows must contribute their position within the container (not just
     * their size) to the container's content size.
     */
    static function gridScrollableOverflowIncludesItemPositionsInOverflowingTracks() {
        final tree = newTestTree();
        final child = () -> st(s -> {
            s.size = new SizeOf<Dimension>(length(100.0), length(500.0));
        });
        final c1 = tree.newLeaf(child());
        final c2 = tree.newLeaf(child());
        final node = tree.newWithChildren(st(s -> {
            s.display = Grid;
            s.size = new SizeOf<Dimension>(length(300.0), length(CONTAINER));
            s.overflow = new PointOf<Overflow>(Scroll, Scroll);
        }), [c1, c2]);

        tree.computeLayout(node, MAX_CONTENT);
        final layout = tree.layout(node);

        Assert.eq(layout.scrollableOverflowRect.bottom, 1000.0);
        Assert.eq(layout.scrollHeight(), 1000.0 - CONTAINER);
    }

    static function scrollHeightAgreesWithBordersAndPaddingCombined() {
        for (display in DISPLAYS) {
            final layout = scrollerWithPadding(display, edge(BORDER, BORDER), edge(PADDING, PADDING));

            final paddingBox = CONTAINER - BORDER - BORDER;
            final expected = (PADDING + CONTENT + PADDING) - paddingBox;
            Assert.eq(layout.scrollHeight(), expected, displayName(display));
        }
    }

}
