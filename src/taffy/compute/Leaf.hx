// Ported from taffy 0.15.0: src/compute/leaf.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute;

import taffy.geometry.Rect;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.AvailableSpace;
import taffy.style.BoxSizing;
import taffy.style.Overflow;
import taffy.style.Style;
import taffy.tree.Baselines;
import taffy.tree.CollapsibleMarginSet;
import taffy.tree.LayoutInput;
import taffy.tree.LayoutOutput;
import taffy.util.Sys;

using taffy.geometry.SizeOf;
using taffy.style.AvailableSpace;
using taffy.util.MaybeMath;
using taffy.util.Resolve;

/**
 * The measure function of a leaf node: `(knownDimensions, availableSpace) -> size`
 */
typedef LeafMeasureFunction = (knownDimensions:SizeOf<Null<Float>>, availableSpace:SizeOf<AvailableSpace>) -> Size;

/**
 * Computes the layout of leaf nodes
 */
class Leaf {

    /**
     * Compute the size of a leaf node (node with no children)
     *
     * A definite `inputs.availableSpace` is treated as the space available to the node's border box:
     * the caller is expected to have already subtracted the node's margins from it.
     *
     * Note: the Rust version also takes a `resolve_calc_value` closure. `calc()` is not supported by this port.
     */
    public static function computeLeafLayout(inputs:LayoutInput, style:Style, measureFunction:LeafMeasureFunction):LayoutOutput {
        final knownDimensions = inputs.knownDimensions;
        final parentSize = inputs.parentSize;
        final availableSpace = inputs.availableSpace;
        final sizingMode = inputs.sizingMode;
        final runMode = inputs.runMode;

        // Note: both horizontal and vertical percentage padding/borders are resolved against the container's inline size (i.e. width).
        final padding = style.padding.resolveOrZero(parentSize.width);
        final border = style.border.resolveOrZero(parentSize.width);
        final paddingBorder = padding.add(border);
        final pbSum = paddingBorder.sumAxes();
        final boxSizingAdjustment = style.boxSizing == ContentBox ? pbSum : Size.ZERO;

        // Resolve node's preferred/min/max sizes (width/heights) against the available space (percentages resolve to pixel values)
        // For ContentSize mode, we pretend that the node has no size styles as these should be ignored.
        var nodeSize:SizeOf<Null<Float>>;
        var nodeMinSize:SizeOf<Null<Float>>;
        var nodeMaxSize:SizeOf<Null<Float>>;
        var aspectRatio:Null<Float>;
        switch sizingMode {
            case ContentSize:
                nodeSize = knownDimensions;
                nodeMinSize = OptionSizeTools.NONE;
                nodeMaxSize = OptionSizeTools.NONE;
                aspectRatio = null;
            case InherentSize:
                aspectRatio = style.aspectRatio;
                final styleSize = style.size.maybeResolve(parentSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);
                final styleMinSize = style.minSize.maybeResolve(parentSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);
                final styleMaxSize = style.maxSize.maybeResolve(parentSize).maybeAddSize(boxSizingAdjustment);
                nodeSize = knownDimensions.or(styleSize);
                nodeMinSize = styleMinSize;
                nodeMaxSize = styleMaxSize;
        }

        // Scrollbar gutters are reserved when the `overflow` property is set to `Overflow.Scroll`.
        // However, the axis are switched (transposed) because a node that scrolls vertically needs
        // *horizontal* space to be reserved for a scrollbar
        final scrollbarGutterX = style.overflow.y == Scroll ? style.scrollbarWidth : 0.0;
        final scrollbarGutterY = style.overflow.x == Scroll ? style.scrollbarWidth : 0.0;

        // TODO: make side configurable based on the `direction` property
        final contentBoxInset = new Rect(
            paddingBorder.left,
            paddingBorder.right + scrollbarGutterX,
            paddingBorder.top,
            paddingBorder.bottom + scrollbarGutterY
        );

        final nodeSizeHeight = nodeSize.height;
        final nodeMinSizeHeight = nodeMinSize.height;
        final hasStylesPreventingBeingCollapsedThrough = !style.isBlock()
            || style.overflow.x.isScrollContainer()
            || style.overflow.y.isScrollContainer()
            || style.position.isOutOfFlow()
            || style.contain.establishesIndependentFormattingContext()
            || padding.top > 0.0
            || padding.bottom > 0.0
            || border.top > 0.0
            || border.bottom > 0.0
            || (nodeSizeHeight != null && nodeSizeHeight > 0.0)
            || (nodeMinSizeHeight != null && nodeMinSizeHeight > 0.0);

        // Return early if both width and height are known
        if (runMode == ComputeSize && hasStylesPreventingBeingCollapsedThrough) {
            final width = nodeSize.width;
            final height = nodeSize.height;
            if (width != null && height != null) {
                final size = new Size(width, height).maybeClamp(nodeMinSize, nodeMaxSize).maybeMax(paddingBorder.sumAxes().toOptions());
                return new LayoutOutput(size, Rect.ZERO, Baselines.NONE, CollapsibleMarginSet.ZERO, CollapsibleMarginSet.ZERO, false);
            }
        }

        // Compute available space
        final nodeMinSizeW = nodeMinSize.width;
        final nodeMaxSizeW = nodeMaxSize.width;
        final nodeMinSizeH = nodeMinSize.height;
        final nodeMaxSizeH = nodeMaxSize.height;
        final insetH = contentBoxInset.horizontalAxisSum();
        final insetV = contentBoxInset.verticalAxisSum();
        final availWidth = (knownDimensions.width != null ? Definite(knownDimensions.width) : availableSpace.width)
            .maybeSet(knownDimensions.width)
            .maybeSet(nodeSize.width);
        final availHeight = (knownDimensions.height != null ? Definite(knownDimensions.height) : availableSpace.height)
            .maybeSet(knownDimensions.height)
            .maybeSet(nodeSize.height);
        final measureAvailableSpace = new SizeOf<AvailableSpace>(
            switch availWidth {
                case Definite(size): Definite(size.maybeClampF(nodeMinSizeW, nodeMaxSizeW) - insetH);
                case _: availWidth;
            },
            switch availHeight {
                case Definite(size): Definite(size.maybeClampF(nodeMinSizeH, nodeMaxSizeH) - insetV);
                case _: availHeight;
            }
        );

        // Measure node
        final measuredSize = measureFunction(
            switch runMode {
                case ComputeSize: knownDimensions;
                case PerformLayout: OptionSizeTools.NONE;
                case PerformHiddenLayout: throw 'unreachable';
            },
            measureAvailableSpace
        );
        final clampedSize = knownDimensions
            .or(nodeSize)
            .unwrapOr(measuredSize.add(contentBoxInset.sumAxes()))
            .maybeClamp(nodeMinSize, nodeMaxSize);
        var size = new Size(
            clampedSize.width,
            Sys.f32Max(clampedSize.height, aspectRatio != null ? clampedSize.width / (aspectRatio : Float) : 0.0)
        );
        size = size.maybeMax(paddingBorder.sumAxes().toOptions());

        // A scroll container's own padding at the end of the content is part of its scrollable
        // overflow region, so it is included in the overflow rect. Boxes that are not scroll
        // containers do not extend their overflow region by their own padding.
        final isScrollContainer = style.overflow.x.isScrollContainer() || style.overflow.y.isScrollContainer();
        final isRtl = style.direction.isRtl();
        final startPadding = isRtl ? padding.right : padding.left;
        final endPadding = isRtl ? padding.left : padding.right;
        final scrollableOverflowRect = new Rect(
            0.0,
            startPadding + measuredSize.width + (isScrollContainer ? endPadding : 0.0),
            0.0,
            padding.top + measuredSize.height + (isScrollContainer ? padding.bottom : 0.0)
        );

        return new LayoutOutput(
            size,
            scrollableOverflowRect,
            Baselines.NONE,
            CollapsibleMarginSet.ZERO,
            CollapsibleMarginSet.ZERO,
            !hasStylesPreventingBeingCollapsedThrough && size.height == 0.0 && measuredSize.height == 0.0
        );
    }

}
