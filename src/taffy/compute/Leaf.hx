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
import taffy.geometry.SizeOpt;
import taffy.util.OptionalFloat;
import taffy.geometry.SizeAvail;
import taffy.style.AvailableSpace.Definite;

using taffy.geometry.SizeOf;
using taffy.style.AvailableSpace;
using taffy.util.MaybeMath;
using taffy.util.Resolve;

/**
 * The measure function of a leaf node: `(knownDimensions, availableSpace) -> size`
 */
typedef LeafMeasureFunction = (knownDimensions:SizeOpt, availableSpace:SizeAvail) -> Size;

/**
 * The measure function of a leaf node as an object (`Leaf.computeLeafLayoutWithMeasurer`): a typed
 * call taking the known dimensions and the available space as values, where the function value
 * receives two size objects made for the call.
 */
interface LeafMeasurer {

    /**
     * Measures the leaf; the size is read back with `measuredWidth()` and
     * `measuredHeight()` (no size object per measure)
     */
    function measureLeafSize(knownWidth:OptionalFloat, knownHeight:OptionalFloat, availableWidth:AvailableSpace, availableHeight:AvailableSpace):Void;

    /** The width of the last `measureLeafSize()` */
    function measuredWidth():Float;

    /** The height of the last `measureLeafSize()` */
    function measuredHeight():Float;

}

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
        return computeLeafLayoutImpl(inputs, style, measureFunction, null);
    }

    /** `computeLeafLayout` with the measure function given as an object */
    public static function computeLeafLayoutWithMeasurer(inputs:LayoutInput, style:Style, measurer:LeafMeasurer):LayoutOutput {
        return computeLeafLayoutImpl(inputs, style, null, measurer);
    }

    static function computeLeafLayoutImpl(inputs:LayoutInput, style:Style, measureFunction:Null<LeafMeasureFunction>, measurer:Null<LeafMeasurer>):LayoutOutput {
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
        // Intermediate values are inline (single constructors) and allocate nothing
        final contentBox = style.boxSizing == ContentBox;
        final boxSizingAdjustment = new Size(contentBox ? pbSum.width : 0.0, contentBox ? pbSum.height : 0.0);

        // Resolve node's preferred/min/max sizes (width/heights) against the available space (percentages resolve to pixel values)
        // For ContentSize mode, we pretend that the node has no size styles as these should be ignored.
        // (The style sizes are resolved in both modes, and only used under InherentSize.)
        final inherentSize = sizingMode == InherentSize;
        final aspectRatio:OptionalFloat = inherentSize ? style.aspectRatio : OptionalFloat.NONE;
        final styleSize = style.size.maybeResolve(parentSize).maybeApplyAspectRatio(style.aspectRatio).maybeAddSize(boxSizingAdjustment);
        final styleMinSize = style.minSize.maybeResolve(parentSize).maybeApplyAspectRatio(style.aspectRatio).maybeAddSize(boxSizingAdjustment);
        final styleMaxSize = style.maxSize.maybeResolve(parentSize).maybeAddSize(boxSizingAdjustment);
        final nodeSize = new SizeOpt(
            inherentSize ? knownDimensions.width.or(styleSize.width) : knownDimensions.width,
            inherentSize ? knownDimensions.height.or(styleSize.height) : knownDimensions.height
        );
        final nodeMinSize = new SizeOpt(
            inherentSize ? styleMinSize.width : OptionalFloat.NONE,
            inherentSize ? styleMinSize.height : OptionalFloat.NONE
        );
        final nodeMaxSize = new SizeOpt(
            inherentSize ? styleMaxSize.width : OptionalFloat.NONE,
            inherentSize ? styleMaxSize.height : OptionalFloat.NONE
        );

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
            || (nodeSizeHeight.isSome() && nodeSizeHeight.unwrap() > 0.0)
            || (nodeMinSizeHeight.isSome() && nodeMinSizeHeight.unwrap() > 0.0);

        // Return early if both width and height are known
        if (runMode == ComputeSize && hasStylesPreventingBeingCollapsedThrough) {
            final width = nodeSize.width;
            final height = nodeSize.height;
            if (width.isSome() && height.isSome()) {
                final size = new Size(width.unwrap(), height.unwrap()).maybeClamp(nodeMinSize, nodeMaxSize).maybeMax(paddingBorder.sumAxes().toOptions());
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
        final availWidth = (knownDimensions.width.isSome() ? Definite(knownDimensions.width.unwrap()) : availableSpace.width)
            .maybeSet(knownDimensions.width)
            .maybeSet(nodeSize.width);
        final availHeight = (knownDimensions.height.isSome() ? Definite(knownDimensions.height.unwrap()) : availableSpace.height)
            .maybeSet(knownDimensions.height)
            .maybeSet(nodeSize.height);
        final measureAvailableWidth = availWidth.isDefinite() ? Definite(availWidth.definiteValue().maybeClampF(nodeMinSizeW, nodeMaxSizeW) - insetH) : availWidth;
        final measureAvailableHeight = availHeight.isDefinite() ? Definite(availHeight.definiteValue().maybeClampF(nodeMinSizeH, nodeMaxSizeH) - insetV) : availHeight;

        // Measure node
        final measureKnownDimensions = switch runMode {
            case ComputeSize: knownDimensions;
            case PerformLayout: SizeOpt.NONE;
            case PerformHiddenLayout: throw 'unreachable';
        };
        var measuredWidth:Float;
        var measuredHeight:Float;
        if (measurer != null) {
            measurer.measureLeafSize(measureKnownDimensions.width, measureKnownDimensions.height, measureAvailableWidth, measureAvailableHeight);
            measuredWidth = measurer.measuredWidth();
            measuredHeight = measurer.measuredHeight();
        }
        else {
            final measuredSize = measureFunction(measureKnownDimensions, new SizeAvail(measureAvailableWidth, measureAvailableHeight));
            measuredWidth = measuredSize.width;
            measuredHeight = measuredSize.height;
        }
        final clampedSize = knownDimensions
            .or(nodeSize)
            .unwrapOr(new Size(measuredWidth, measuredHeight).add(contentBoxInset.sumAxes()))
            .maybeClamp(nodeMinSize, nodeMaxSize);
        final size = new Size(
            clampedSize.width,
            Sys.f32Max(clampedSize.height, aspectRatio.isSome() ? clampedSize.width / aspectRatio.unwrap() : 0.0)
        ).maybeMax(paddingBorder.sumAxes().toOptions());

        // A scroll container's own padding at the end of the content is part of its scrollable
        // overflow region, so it is included in the overflow rect. Boxes that are not scroll
        // containers do not extend their overflow region by their own padding.
        final isScrollContainer = style.overflow.x.isScrollContainer() || style.overflow.y.isScrollContainer();
        final isRtl = style.direction.isRtl();
        final startPadding = isRtl ? padding.right : padding.left;
        final endPadding = isRtl ? padding.left : padding.right;
        final scrollableOverflowRect = new Rect(
            0.0,
            startPadding + measuredWidth + (isScrollContainer ? endPadding : 0.0),
            0.0,
            padding.top + measuredHeight + (isScrollContainer ? padding.bottom : 0.0)
        );

        return new LayoutOutput(
            size,
            scrollableOverflowRect,
            Baselines.NONE,
            CollapsibleMarginSet.ZERO,
            CollapsibleMarginSet.ZERO,
            !hasStylesPreventingBeingCollapsedThrough && size.height == 0.0 && measuredHeight == 0.0
        );
    }

}
