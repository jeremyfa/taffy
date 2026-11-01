// Ported from taffy 0.15.0: src/compute/common/scrollable_overflow.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.common;

import taffy.geometry.Point;
import taffy.geometry.PointOf;
import taffy.geometry.Rect;
import taffy.geometry.Size;
import taffy.style.Contain;
import taffy.style.Overflow;
import taffy.util.Sys;

/**
 * Scrollable overflow helpers
 */
class ScrollableOverflow {

    /**
     * Determine the rectangle that a given node contributes to its parent's scrollable overflow rectangle.
     *
     * `location` is the position of the node's border box measured from the parent's scroll origin
     * (logical start edge): callers pass coordinates that are mirrored for RTL.
     */
    public static function computeScrollableOverflowContribution(
        location:Point,
        size:Size,
        scrollableOverflowRect:Rect,
        overflow:PointOf<Overflow>,
        contain:Contain,
        parentIsScrollContainer:Bool
    ):Rect {
        final isScrollContainer = overflow.x.isScrollContainer() || overflow.y.isScrollContainer();
        final overflowIsContained = contain.containsScrollableOverflow();
        final propagatesX = !isScrollContainer && !overflowIsContained && overflow.x == Visible;
        final propagatesY = !isScrollContainer && !overflowIsContained && overflow.y == Visible;

        final endExtentWidth = propagatesX ? Sys.f32Max(size.width, scrollableOverflowRect.right) : size.width;
        final endExtentHeight = propagatesY ? Sys.f32Max(size.height, scrollableOverflowRect.bottom) : size.height;

        if (endExtentWidth <= 0.0 || endExtentHeight <= 0.0) {
            return Rect.ZERO;
        }

        final startExtentX = propagatesX ? Sys.f32Min(0.0, scrollableOverflowRect.left) : 0.0;
        final startExtentY = propagatesY ? Sys.f32Min(0.0, scrollableOverflowRect.top) : 0.0;

        final contribution = new Rect(
            location.x + startExtentX,
            location.x + endExtentWidth,
            location.y + startExtentY,
            location.y + endExtentHeight
        );

        final isWhollyUnreachable = contribution.right <= 0.0 || contribution.bottom <= 0.0;
        if (parentIsScrollContainer && isWhollyUnreachable) {
            return Rect.ZERO;
        }
        return contribution;
    }

}
