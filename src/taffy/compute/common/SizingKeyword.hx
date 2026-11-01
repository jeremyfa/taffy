// Ported from taffy 0.15.0: src/compute/common/sizing_keyword.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.common;

import taffy.geometry.AbsoluteAxis;
import taffy.geometry.LineOf;
import taffy.geometry.RectOf;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.AvailableSpace;
import taffy.style.CompactLength;
import taffy.style.Dimension;
import taffy.tree.LayoutPartialTree;
import taffy.tree.NodeId;
import taffy.tree.SizingMode;
import taffy.util.Sys;

using taffy.tree.LayoutPartialTree;

/**
 * How a sizing keyword resolves to a used size
 */
enum SizingKeywordResolution {

    /** The size is the result of measuring the item under the given available space constraint */
    Measure(availableSpace:AvailableSpace);

    /** The size resolves to an exact value without measuring the item */
    Exact(value:Float);

}

/**
 * Sizing keyword (`min-content`, `max-content`, `fit-content`, `stretch`) helpers
 */
class SizingKeyword {

    static final FALSE_LINE:LineOf<Bool> = new LineOf<Bool>(false, false);

    /**
     * Resolve an item's size style in one axis if it is a sizing keyword.
     *
     * - `stretchSize` is the size the item would take if stretched to fill the available space (available space minus margins).
     * - `percentResolutionBasis` is the size that percentages resolve against in this axis.
     *
     * Returns null if the size style is not a sizing keyword, or if it cannot be resolved in the current context.
     */
    public static function resolveSizingKeyword(style:Dimension, stretchSize:Null<Float>, percentResolutionBasis:Null<Float>):Null<SizingKeywordResolution> {
        return switch style.tag() {
            case CompactLength.MIN_CONTENT_TAG: Measure(MinContent);
            case CompactLength.MAX_CONTENT_TAG: Measure(MaxContent);
            case CompactLength.FIT_CONTENT_PX_TAG: Measure(Definite(style.value()));
            case CompactLength.FIT_CONTENT_PERCENT_TAG:
                percentResolutionBasis != null ? Measure(Definite((percentResolutionBasis : Float) * style.value())) : null;
            case CompactLength.FIT_CONTENT_KEYWORD_TAG:
                stretchSize != null ? Measure(Definite(stretchSize)) : null;
            case CompactLength.STRETCH_TAG:
                stretchSize != null ? Exact(stretchSize) : null;
            case _: null;
        }
    }

    /**
     * Resolve the sizing keywords on the size styles of an absolutely positioned item and return
     * the updated known dimensions.
     *
     * - `areaSize` is the size of the item's containing block.
     * - The stretch size in each axis is the containing block minus the item's insets and margins in that axis.
     */
    public static function resolveAbsoluteSizingKeywords(
        tree:LayoutPartialTree,
        node:NodeId,
        knownDimensions:SizeOf<Null<Float>>,
        sizeStyle:SizeOf<Dimension>,
        areaSize:Size,
        inset:RectOf<Null<Float>>,
        margin:RectOf<Null<Float>>,
        sizingMode:SizingMode
    ):SizeOf<Null<Float>> {
        final stretchWidth = Sys.f32Max(
            areaSize.width - nz(inset.left) - nz(inset.right) - nz(margin.left) - nz(margin.right),
            0.0
        );
        final stretchHeight = Sys.f32Max(
            areaSize.height - nz(inset.top) - nz(inset.bottom) - nz(margin.top) - nz(margin.bottom),
            0.0
        );

        final keywordWidth = knownDimensions.width == null ? resolveSizingKeyword(sizeStyle.width, stretchWidth, areaSize.width) : null;
        final keywordHeight = knownDimensions.height == null ? resolveSizingKeyword(sizeStyle.height, stretchHeight, areaSize.height) : null;

        // If both axes need to be measured then resolve them with a single measure call
        if (keywordWidth != null && keywordHeight != null) {
            switch [keywordWidth, keywordHeight] {
                case [Measure(availableWidth), Measure(availableHeight)]:
                    final measuredSize = tree.measureChildSizeBoth(
                        node,
                        new SizeOf<Null<Float>>(null, null),
                        areaSize.toOptions(),
                        new SizeOf<AvailableSpace>(availableWidth, availableHeight),
                        sizingMode,
                        FALSE_LINE
                    );
                    return measuredSize.toOptions();
                case _:
            }
        }

        var result = knownDimensions;
        if (keywordWidth != null) {
            final width:Float = switch keywordWidth {
                case Exact(width): width;
                case Measure(availableWidth):
                    tree.measureChildSize(
                        node,
                        result,
                        areaSize.toOptions(),
                        new SizeOf<AvailableSpace>(availableWidth, Definite(stretchHeight)),
                        sizingMode,
                        Horizontal,
                        FALSE_LINE
                    );
            }
            result = result.withWidth(width);
        }
        if (keywordHeight != null) {
            final height:Float = switch keywordHeight {
                case Exact(height): height;
                case Measure(availableHeight):
                    tree.measureChildSize(
                        node,
                        result,
                        areaSize.toOptions(),
                        new SizeOf<AvailableSpace>(result.width != null ? Definite(result.width) : Definite(stretchWidth), availableHeight),
                        sizingMode,
                        Vertical,
                        FALSE_LINE
                    );
            }
            result = result.withHeight(height);
        }
        return result;
    }

    static inline function nz(v:Null<Float>):Float {
        return v != null ? (v : Float) : 0.0;
    }

}
