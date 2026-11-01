// Ported from taffy 0.15.0 (repository): tests/hand_written/scrollable_overflow.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.PointOf;
import taffy.geometry.Rect;
import taffy.geometry.SizeOf;
import taffy.style.Dimension;
import taffy.style.Direction;
import taffy.style.Display;
import taffy.style.LengthPercentageAuto;
import taffy.style.Overflow;
import taffy.tree.Layout;

/**
 * The scrollable overflow rectangle captures start-side (negative) overflow as well as
 * end-side overflow. Boxes wholly in the unreachable scrollable overflow region are
 * excluded for scroll containers, while boxes only partially in the unreachable region
 * contribute their whole border box.
 */
class ScrollableOverflowTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("wholly_unreachable_boxes_are_excluded_for_scroll_containers", whollyUnreachableBoxesAreExcludedForScrollContainers),
            new TestCase("wholly_unreachable_boxes_contribute_to_non_scroll_containers", whollyUnreachableBoxesContributeToNonScrollContainers),
            new TestCase("partially_unreachable_boxes_contribute_their_whole_border_box", partiallyUnreachableBoxesContributeTheirWholeBorderBox),
            new TestCase("end_side_overflow_is_captured_and_scrollable", endSideOverflowIsCapturedAndScrollable),
            new TestCase("absolute_only_containers_include_scroll_container_end_padding", absoluteOnlyContainersIncludeScrollContainerEndPadding),
            new TestCase("scroll_container_in_one_axis_clips_both_axes", scrollContainerInOneAxisClipsBothAxes),
            new TestCase("clip_in_one_axis_does_not_clip_the_other", clipInOneAxisDoesNotClipTheOther),
            new TestCase("wholly_unreachable_boxes_are_excluded_for_rtl_scroll_containers", whollyUnreachableBoxesAreExcludedForRtlScrollContainers),
            new TestCase("end_side_overflow_is_captured_for_rtl_scroll_containers", endSideOverflowIsCapturedForRtlScrollContainers),
        ];
    }

    static inline final CONTAINER:Float = 200.0;
    static inline final CHILD:Float = 50.0;

    static final DISPLAYS:Array<Display> = [Block, Flex, Grid];

    static function optLength(value:Null<Float>):LengthPercentageAuto {
        return value != null ? length(value) : auto();
    }

    static function containerWithAbsoluteChild(display:Display, overflow:Overflow, direction:Direction, insetLeft:Null<Float>, insetRight:Null<Float>):Layout {
        final tree = newTestTree();
        final child = tree.newLeaf(st(s -> {
            s.position = Absolute;
            s.inset = rectLPA(optLength(insetLeft), optLength(insetRight), length(0.0), auto());
            s.size = new SizeOf<Dimension>(length(CHILD), length(CHILD));
        }));
        final node = tree.newWithChildren(st(s -> {
            s.display = display;
            s.direction = direction;
            s.position = Relative;
            s.size = new SizeOf<Dimension>(length(CONTAINER), length(CONTAINER));
            s.overflow = new PointOf<Overflow>(overflow, overflow);
        }), [child]);

        tree.computeLayout(node, MAX_CONTENT);
        return tree.layout(node);
    }

    static function whollyUnreachableBoxesAreExcludedForScrollContainers() {
        for (display in DISPLAYS) {
            // Child entirely before the scroll origin (x from -100 to -50)
            final layout = containerWithAbsoluteChild(display, Scroll, Ltr, -100.0, null);

            Assert.eqRect(layout.scrollableOverflowRect, Rect.ZERO, displayName(display));
            Assert.eq(layout.scrollWidth(), 0.0, displayName(display));
        }
    }

    static function whollyUnreachableBoxesContributeToNonScrollContainers() {
        for (display in DISPLAYS) {
            // A box that is not a scroll container has no unreachable region of its own, so
            // start-side overflow is captured in its scrollable overflow rect.
            final layout = containerWithAbsoluteChild(display, Visible, Ltr, -100.0, null);

            Assert.eq(layout.scrollableOverflowRect.left, -100.0, displayName(display));
        }
    }

    static function partiallyUnreachableBoxesContributeTheirWholeBorderBox() {
        for (display in DISPLAYS) {
            // Child straddling the scroll origin (x from -25 to 25): its whole border box is
            // part of the scrollable overflow area, even though the negative part is unreachable.
            final layout = containerWithAbsoluteChild(display, Scroll, Ltr, -25.0, null);

            Assert.eq(layout.scrollableOverflowRect.left, -25.0, displayName(display));
            Assert.eq(layout.scrollableOverflowRect.right, 25.0, displayName(display));
            // Only the reachable extent counts towards the scroll width
            Assert.eq(layout.scrollWidth(), 0.0, displayName(display));
        }
    }

    static function endSideOverflowIsCapturedAndScrollable() {
        for (display in DISPLAYS) {
            // Child extending past the end edge (x from 200 to 250)
            final layout = containerWithAbsoluteChild(display, Scroll, Ltr, CONTAINER, null);

            Assert.eq(layout.scrollableOverflowRect.right, CONTAINER + CHILD, displayName(display));
            Assert.eq(layout.scrollWidth(), CHILD, displayName(display));
        }
    }

    static function absoluteOnlyContainersIncludeScrollContainerEndPadding() {
        for (display in DISPLAYS) {
            final tree = newTestTree();
            final abs = tree.newLeaf(st(s -> {
                s.position = Absolute;
                s.inset = rectLPA(length(0.0), auto(), length(0.0), auto());
                s.size = new SizeOf<Dimension>(length(5.0), length(5.0));
            }));
            final node = tree.newWithChildren(st(s -> {
                s.display = display;
                s.position = Relative;
                s.overflow = new PointOf<Overflow>(Scroll, Scroll);
                s.padding = rectLP(length(0.0), length(20.0), length(0.0), length(30.0));
                s.size = new SizeOf<Dimension>(length(CONTAINER), length(CONTAINER));
            }), [abs]);

            tree.computeLayout(node, MAX_CONTENT);
            final layout = tree.layout(node);

            Assert.eq(layout.scrollableOverflowRect.right, 20.0, displayName(display));
            Assert.eq(layout.scrollableOverflowRect.bottom, 30.0, displayName(display));
        }
    }

    static function nestedOverflowLayout(display:Display, childOverflow:PointOf<Overflow>):Layout {
        final tree = newTestTree();
        // Grandchild overflowing the child in the y axis (extends to y=300 in a 200-high child)
        final grandchild = tree.newLeaf(st(s -> {
            s.position = Absolute;
            s.inset = rectLPA(length(0.0), auto(), length(CONTAINER), auto());
            s.size = new SizeOf<Dimension>(length(CHILD), length(CHILD));
        }));
        final child = tree.newWithChildren(st(s -> {
            s.display = display;
            s.position = Relative;
            s.size = new SizeOf<Dimension>(length(CONTAINER), length(CONTAINER));
            s.overflow = childOverflow;
        }), [grandchild]);
        final node = tree.newWithChildren(st(s -> {
            s.display = display;
            s.size = new SizeOf<Dimension>(length(CONTAINER), length(CONTAINER));
        }), [child]);

        tree.computeLayout(node, MAX_CONTENT);
        return tree.layout(node);
    }

    static function scrollContainerInOneAxisClipsBothAxes() {
        for (display in DISPLAYS) {
            // `Hidden`/`Scroll` in either axis makes the child a scroll container, which clips
            // overflow in both axes: the grandchild's y overflow must not propagate.
            final layout = nestedOverflowLayout(display, new PointOf<Overflow>(Hidden, Visible));

            Assert.eq(layout.scrollableOverflowRect.bottom, CONTAINER, displayName(display));
        }
    }

    static function clipInOneAxisDoesNotClipTheOther() {
        for (display in DISPLAYS) {
            // `Clip` does not establish a scroll container: overflow in the other (visible) axis
            // still propagates.
            final layout = nestedOverflowLayout(display, new PointOf<Overflow>(Clip, Visible));

            Assert.eq(layout.scrollableOverflowRect.bottom, CONTAINER + CHILD, displayName(display));
        }
    }

    static function whollyUnreachableBoxesAreExcludedForRtlScrollContainers() {
        for (display in DISPLAYS) {
            // In RTL the scroll origin is the top-right corner: a child entirely past the
            // *right* edge is wholly unreachable.
            final layout = containerWithAbsoluteChild(display, Scroll, Rtl, null, -100.0);

            Assert.eqRect(layout.scrollableOverflowRect, Rect.ZERO, displayName(display));
            Assert.eq(layout.scrollWidth(), 0.0, displayName(display));
        }
    }

    static function endSideOverflowIsCapturedForRtlScrollContainers() {
        for (display in DISPLAYS) {
            // In RTL, overflow past the *left* edge is reachable end-side overflow.
            final layout = containerWithAbsoluteChild(display, Scroll, Rtl, -CHILD, null);

            Assert.eq(layout.scrollableOverflowRect.right, CONTAINER + CHILD, displayName(display));
            Assert.eq(layout.scrollWidth(), CHILD, displayName(display));
        }
    }

}
