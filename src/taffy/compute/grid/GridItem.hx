// Ported from taffy 0.15.0: src/compute/grid/types/grid_item.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.grid;

import taffy.compute.grid.GridCoordinates.IntLine;

import taffy.compute.common.SizingKeyword;
import taffy.geometry.AbstractAxis;
import taffy.geometry.LineOf;
import taffy.geometry.PointOf;
import taffy.geometry.Rect;
import taffy.geometry.RectOf;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.AlignItems;
import taffy.style.AlignItemsKeyword;
import taffy.style.AvailableSpace;
import taffy.style.BoxSizing;
import taffy.style.Dimension;
import taffy.style.LengthPercentage;
import taffy.style.LengthPercentageAuto;
import taffy.style.Overflow;
import taffy.style.Style;
import taffy.tree.LayoutPartialTree;
import taffy.tree.NodeId;
import taffy.tree.OofCandidates;
import taffy.util.MaybeMath;
import taffy.util.Sys;
import taffy.geometry.SizeOpt;
import taffy.util.OptionalFloat;
import taffy.geometry.SizeAvail;
import taffy.style.AvailableSpace.Definite;

using taffy.geometry.SizeOf;
using taffy.util.Resolve;

/**
 * Represents a single grid item
 */
class GridItem {

    /** Track size estimate: the definite value of the max track sizing function (resolved against the parent size) */
    public static inline final ESTIMATE_MAX_TRACK_DEFINITE_VALUE:Int = 0;

    /** Track size estimate: the base size of the track */
    public static inline final ESTIMATE_BASE_SIZE:Int = 1;

    static final FALSE_LINE:LineOf<Bool> = new LineOf<Bool>(false, false);

    /** The id of the node that this item represents */
    public final node:NodeId;

    /** The index of the item in the children array */
    public final sourceOrder:Int;

    /**
     * The item's definite row-start and row-end, as resolved by the placement algorithm
     * (in origin-zero coordinates). Set by the placement algorithm.
     */
    public var row:IntLine;

    /**
     * The items definite column-start and column-end, as resolved by the placement algorithm
     * (in origin-zero coordinates). Set by the placement algorithm.
     */
    public var column:IntLine;

    /** Is it a compressible replaced element? https://drafts.csswg.org/css-sizing-3/#min-content-zero */
    public final isCompressibleReplaced:Bool;

    /** Whether the item is a replaced element. Such items are not stretched by `normal` alignment. */
    public final isReplaced:Bool;

    /** The item's overflow style */
    public final overflow:PointOf<Overflow>;

    /** The item's box_sizing style */
    public final boxSizing:BoxSizing;

    /** The item's size style */
    public final size:SizeOf<Dimension>;

    /** The item's min_size style */
    public final minSize:SizeOf<LengthPercentageAuto>;

    /** The item's max_size style */
    public final maxSize:SizeOf<LengthPercentageAuto>;

    /** The item's aspect_ratio style */
    public final aspectRatio:OptionalFloat;

    /** The item's padding style */
    public final padding:RectOf<LengthPercentage>;

    /** The item's border style */
    public final border:RectOf<LengthPercentage>;

    /** The item's margin style */
    public final margin:RectOf<LengthPercentageAuto>;

    /** The item's align_self property, or the parent's align_items property if it is not set */
    public final alignSelf:AlignItems;

    /** The item's justify_self property, or the parent's justify_items property if it is not set */
    public final justifySelf:AlignItems;

    /** The items first baseline (horizontal) */
    public var baseline:OptionalFloat = OptionalFloat.NONE;

    /**
     * Shim for baseline alignment that acts like an extra top margin
     * TODO: Support last baseline and vertical text baselines
     */
    public var baselineShim:Float = 0.0;

    /**
     * The item's definite row-start and row-end (same as `row` field, except in a different coordinate system)
     * (as indexes into the GridTrack arrays)
     */
    public var rowIndexes:IntLine = IntLine.ZERO;

    /**
     * The items definite column-start and column-end (same as `column` field, except in a different coordinate system)
     * (as indexes into the GridTrack arrays)
     */
    public var columnIndexes:IntLine = IntLine.ZERO;

    /** Whether the item crosses a flexible row */
    public var crossesFlexibleRow:Bool = false;

    /** Whether the item crosses a flexible column */
    public var crossesFlexibleColumn:Bool = false;

    /** Whether the item crosses a intrinsic row */
    public var crossesIntrinsicRow:Bool = false;

    /** Whether the item crosses a intrinsic column */
    public var crossesIntrinsicColumn:Bool = false;

    // Caches for intrinsic size computation. These caches are only valid for a single run of the track-sizing algorithm.

    /** Cache for the known_dimensions input to intrinsic sizing computation */
    public var gridAreaSizeCache:Null<SizeOpt> = null;

    /**
     * Cache for the known_dimensions passed to the child when computing its intrinsic contributions, stored along with
     * the grid area size it was computed for (null if empty). Must be cleared whenever `baselineShim` changes.
     */
    public var knownDimensionsCacheGridAreaSize:Null<SizeOpt> = null;

    /** The cached known dimensions (see `knownDimensionsCacheGridAreaSize`) */
    public var knownDimensionsCacheValue:Null<SizeOpt> = null;

    /** Cache for the min-content size (width) */
    public var minContentContributionCacheWidth:OptionalFloat = OptionalFloat.NONE;

    /** Cache for the min-content size (height) */
    public var minContentContributionCacheHeight:OptionalFloat = OptionalFloat.NONE;

    /** Cache for the minimum contribution (width) */
    public var minimumContributionCacheWidth:OptionalFloat = OptionalFloat.NONE;

    /** Cache for the minimum contribution (height) */
    public var minimumContributionCacheHeight:OptionalFloat = OptionalFloat.NONE;

    /** Cache for the max-content size (width) */
    public var maxContentContributionCacheWidth:OptionalFloat = OptionalFloat.NONE;

    /** Cache for the max-content size (height) */
    public var maxContentContributionCacheHeight:OptionalFloat = OptionalFloat.NONE;

    /** Final y position. Used to compute baseline alignment for the container. */
    public var yPosition:Float = 0.0;

    /** Final height. Used to compute baseline alignment for the container. */
    public var height:Float = 0.0;

    /** Out-of-flow candidates bubbled out of this item's subtree (anchors relative to the container's border box) */
    public var oofCandidates:OofCandidates;

    /** Create a new item from its style. Its placement (`row`/`column`) is filled in by the placement algorithm. */
    public function new(node:NodeId, style:Style, parentAlignItems:AlignItems, parentJustifyItems:AlignItems, sourceOrder:Int) {
        this.node = node;
        this.sourceOrder = sourceOrder;
        row = IntLine.ZERO;
        column = IntLine.ZERO;
        isCompressibleReplaced = style.isCompressibleReplaced();
        isReplaced = style.isReplaced();
        overflow = style.overflow;
        boxSizing = style.boxSizing;
        size = style.size;
        minSize = style.minSize;
        maxSize = style.maxSize;
        aspectRatio = style.aspectRatio;
        padding = style.padding;
        border = style.border;
        margin = style.margin;
        alignSelf = style.alignSelf != null ? (style.alignSelf : AlignItems) : parentAlignItems;
        justifySelf = style.justifySelf != null ? (style.justifySelf : AlignItems) : parentJustifyItems;
        oofCandidates = new OofCandidates();
    }

    /** Create a new item from its style (Rust `GridItem::new_with_style_and_order`) */
    public static inline function newWithStyleAndOrder(node:NodeId, style:Style, parentAlignItems:AlignItems, parentJustifyItems:AlignItems,
            sourceOrder:Int):GridItem {
        return new GridItem(node, style, parentAlignItems, parentJustifyItems, sourceOrder);
    }

    /** Whether the item has an auto margin in the block axis */
    public inline function hasAutoBlockMargin():Bool {
        return margin.top.isAuto() || margin.bottom.isAuto();
    }

    /**
     * Whether the item's block size depends on the size of its row(s), creating a cyclic
     * dependency with baseline alignment (which affects row sizing). Per
     * https://www.w3.org/TR/css-grid-1/#row-align such items do not participate in baseline
     * alignment and are aligned using their fallback alignment instead.
     */
    public inline function hasCyclicBlockSizeDependency():Bool {
        return size.height.intoRaw().usesPercentage() && (crossesIntrinsicRow || crossesFlexibleRow);
    }

    /**
     * Returns true if the item participates in baseline alignment: it has `align-self: baseline`
     * and neither of its block-axis margins are `auto`.
     * See https://www.w3.org/TR/css-align-3/#baseline-align-self
     */
    public inline function participatesInBaselineAlignment():Bool {
        return alignSelf.keyword == AlignItemsKeyword.Baseline && !hasAutoBlockMargin() && !hasCyclicBlockSizeDependency();
    }

    /** This item's placement in the specified axis in OriginZero coordinates */
    public inline function placement(axis:AbstractAxis):IntLine {
        return axis == Block ? row : column;
    }

    /** This item's placement in the specified axis as GridTrack array indices */
    public inline function placementIndexes(axis:AbstractAxis):IntLine {
        return axis == Block ? rowIndexes : columnIndexes;
    }

    /**
     * The start (inclusive) of the range of GridTrack array indices covering all the tracks and lines that this item
     * spans excluding the lines that bound it.
     */
    public inline function trackRangeStart(axis:AbstractAxis):Int {
        return placementIndexes(axis).start + 1;
    }

    /** The end (exclusive) of the range of GridTrack array indices returned by `trackRangeStart` */
    public inline function trackRangeEnd(axis:AbstractAxis):Int {
        return placementIndexes(axis).end;
    }

    /** Returns the number of tracks that this item spans in the specified axis */
    public inline function span(axis:AbstractAxis):Int {
        return axis == Block ? row.span() : column.span();
    }

    /** Returns the pre-computed value indicating whether the grid item crosses a flexible track in the specified axis */
    public inline function crossesFlexibleTrack(axis:AbstractAxis):Bool {
        return axis == Inline ? crossesFlexibleColumn : crossesFlexibleRow;
    }

    /** Returns the pre-computed value indicating whether the grid item crosses an intrinsic track in the specified axis */
    public inline function crossesIntrinsicTrack(axis:AbstractAxis):Bool {
        return axis == Inline ? crossesIntrinsicColumn : crossesIntrinsicRow;
    }

    /**
     * For an item spanning multiple tracks, the upper limit used to calculate its limited min-/max-content contribution is the
     * sum of the fixed max track sizing functions of any tracks it spans, and is applied if it only spans such tracks.
     */
    public function spannedTrackLimit(axis:AbstractAxis, axisTracks:Array<GridTrack>, axisParentSize:OptionalFloat):OptionalFloat {
        var limit = 0.0;
        for (i in trackRangeStart(axis)...trackRangeEnd(axis)) {
            final value = axisTracks[i].maxTrackSizingFunction.definiteLimit(axisParentSize);
            if (value.isNone())
                return OptionalFloat.NONE;
            limit += value.unwrap();
        }
        return OptionalFloat.some(limit);
    }

    /**
     * Similar to the spannedTrackLimit, but excludes FitContent arguments from the limit.
     * Used to clamp the automatic minimum contributions of an item
     */
    public function spannedFixedTrackLimit(axis:AbstractAxis, axisTracks:Array<GridTrack>, axisParentSize:OptionalFloat):OptionalFloat {
        var limit = 0.0;
        for (i in trackRangeStart(axis)...trackRangeEnd(axis)) {
            final value = axisTracks[i].maxTrackSizingFunction.definiteValue(axisParentSize);
            if (value.isNone())
                return OptionalFloat.NONE;
            limit += value.unwrap();
        }
        return OptionalFloat.some(limit);
    }

    /**
     * Retrieve the known_dimensions for the given grid area size from the cache or compute them.
     * The min-content and max-content contributions of an item are both computed from the same known_dimensions.
     */
    inline function knownDimensionsCached(tree:LayoutPartialTree, gridAreaSize:SizeOpt):SizeOpt {
        final cachedSize = knownDimensionsCacheGridAreaSize;
        return if (cachedSize != null && cachedSize.equals(gridAreaSize)) {
            knownDimensionsCacheValue;
        }
        else {
            final kd = knownDimensions(tree, gridAreaSize);
            knownDimensionsCacheGridAreaSize = gridAreaSize;
            knownDimensionsCacheValue = kd;
            kd;
        }
    }

    /** Clear the known dimensions cache */
    public inline function clearKnownDimensionsCache():Void {
        knownDimensionsCacheGridAreaSize = null;
        knownDimensionsCacheValue = null;
    }

    /** Whether the given self-alignment stretches the item: `stretch`, or `normal` unless the item is replaced */
    inline function isStretchAligned(alignment:AlignItems):Bool {
        return switch alignment.keyword {
            case Stretch: true;
            case Normal: !isReplaced;
            case _: false;
        }
    }

    /**
     * Compute the known_dimensions to be passed to the child sizing functions
     * The key thing that is being done here is applying stretch alignment, which is necessary to
     * allow percentage sizes further down the tree to resolve properly in some cases
     */
    function knownDimensions(tree:LayoutPartialTree, gridAreaSize:SizeOpt):SizeOpt {
        final margins = marginsAxisSumsWithBaselineShims(gridAreaSize.width, tree);

        final aspectRatio = this.aspectRatio;
        // CSS resolves percentage padding and border against the inline size of the containing
        // block. For a grid item under intrinsic measurement, that inline-size basis is the grid
        // area's width when it is definite.
        // Spec:
        // https://www.w3.org/TR/css-grid-1/#item-margins
        // https://www.w3.org/TR/CSS22/box.html#padding-properties
        final padding = this.padding.resolveOrZero(gridAreaSize.width);
        final border = this.border.resolveOrZero(gridAreaSize.width);
        final paddingBorderSize = padding.add(border).sumAxes();
        final boxSizingAdjustment = boxSizing == ContentBox ? paddingBorderSize : Size.ZERO;
        final inherentSize = size.maybeResolve(gridAreaSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);
        final minSize = this.minSize.maybeResolve(gridAreaSize)
            .maybeApplyAspectRatio(aspectRatio)
            .maybeAddSize(boxSizingAdjustment)
            // The size of the item is floored by its padding and border
            .or(paddingBorderSize.toOptions())
            .maybeMaxSize(paddingBorderSize);
        final maxSize = this.maxSize.maybeResolve(gridAreaSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);

        final gridAreaMinusItemMarginsSize = gridAreaSize.maybeSubSize(margins).maybeMaxSize(Size.ZERO);

        // If node is absolutely positioned and width is not set explicitly, then deduce it
        // from left, right and container_content_box if both are set.
        var width:OptionalFloat = inherentSize.width;
        if (width.isNone()) {
            // A width that is a sizing keyword is not auto, so it does not stretch. The stretch
            // keyword resolves to an exact width; the others resolve during content measurement.
            if (size.width.isSizingKeyword()) {
                switch SizingKeyword.resolveSizingKeyword(size.width, gridAreaMinusItemMarginsSize.width, gridAreaSize.width) {
                    case Exact(w): width = OptionalFloat.some(w);
                    case _:
                }
            }
            // Apply width based on stretch alignment if:
            //  - Alignment style is "stretch" or "normal". Note that "normal" is treated as "stretch"
            //    here regardless of whether the item has a preferred size or aspect ratio in this axis,
            //    which differs from the rule used when the item is finally aligned (see `alignAndPositionItem`).
            //    Replaced elements are not stretched by "normal".
            //  - The node is not absolutely positioned
            //  - The node does not have auto margins in this axis.
            else if (!margin.left.isAuto() && !margin.right.isAuto() && isStretchAligned(justifySelf)) {
                width = gridAreaMinusItemMarginsSize.width;
            }
        }
        // Reapply aspect ratio after stretch and absolute position width adjustments
        final s1 = new SizeOpt(width, inherentSize.height).maybeApplyAspectRatio(aspectRatio);
        width = s1.width;
        var height:OptionalFloat = s1.height;

        if (height.isNone()) {
            // A height that is a sizing keyword is not auto, so it does not stretch. The stretch
            // keyword resolves to an exact height; the others resolve during content measurement.
            if (size.height.isSizingKeyword()) {
                switch SizingKeyword.resolveSizingKeyword(size.height, gridAreaMinusItemMarginsSize.height, gridAreaSize.height) {
                    case Exact(h): height = OptionalFloat.some(h);
                    case _:
                }
            }
            // Apply height based on stretch alignment if:
            //  - Alignment style is "stretch" or "normal" (see the note on width above)
            //  - The node is not absolutely positioned
            //  - The node does not have auto margins in this axis.
            else if (!margin.top.isAuto() && !margin.bottom.isAuto() && isStretchAligned(alignSelf)) {
                height = gridAreaMinusItemMarginsSize.height;
            }
        }
        // Reapply aspect ratio after stretch and absolute position height adjustments
        final s2 = new SizeOpt(width, height).maybeApplyAspectRatio(aspectRatio);

        // Clamp size by min and max width/height
        return s2.maybeClamp(minSize, maxSize);
    }

    /** Sum the track size estimates of the passed tracks (null if any estimate is null) */
    static function sumTrackSizeEstimates(tracks:Array<GridTrack>, start:Int, end:Int, estimate:Int, parentSize:OptionalFloat):OptionalFloat {
        var sum = 0.0;
        for (i in start...end) {
            final track = tracks[i];
            final value = trackSizeEstimate(track, estimate, parentSize);
            if (value.isNone())
                return OptionalFloat.NONE;
            sum += value.unwrap() + track.contentAlignmentAdjustment;
        }
        return OptionalFloat.some(sum);
    }

    /** Compute a track size estimate (`ESTIMATE_MAX_TRACK_DEFINITE_VALUE` or `ESTIMATE_BASE_SIZE`) */
    public static inline function trackSizeEstimate(track:GridTrack, estimate:Int, parentSize:OptionalFloat):OptionalFloat {
        return estimate == ESTIMATE_BASE_SIZE ? OptionalFloat.some(track.baseSize) : track.maxTrackSizingFunction.definiteValue(parentSize);
    }

    /**
     * Returns the grid area's size in the specified axis when every spanned track has a definite fixed size.
     *
     * During intrinsic sizing, percentages on grid items resolve against the size of the grid area,
     * not the grid container. If the spanned tracks in an axis are not all definite yet, the grid
     * area is still indefinite in that axis and percentage-dependent values must stay unresolved here.
     *
     * In the other axis, the size is computed from estimates based on either the max track sizing function
     * or the provisional base size in the opposite axis to the one currently being sized
     * (`estimate` is `ESTIMATE_MAX_TRACK_DEFINITE_VALUE` or `ESTIMATE_BASE_SIZE`).
     * https://www.w3.org/TR/css-grid-1/#algo-overview
     */
    public function gridAreaSize(axis:AbstractAxis, axisTracks:Array<GridTrack>, otherAxisTracks:Array<GridTrack>,
            availableSpace:SizeOpt, estimate:Int):SizeOpt {
        var axisSize:OptionalFloat = OptionalFloat.some(0.0);
        final axisAvailable = availableSpace.get(axis);
        for (i in trackRangeStart(axis)...trackRangeEnd(axis)) {
            final track = axisTracks[i];
            final minSize = track.minTrackSizingFunction.definiteValue(axisAvailable);
            if (minSize.isNone()) {
                axisSize = OptionalFloat.NONE;
                break;
            }
            final maxSize = track.maxTrackSizingFunction.definiteValue(axisAvailable);
            if (maxSize.isNone()) {
                axisSize = OptionalFloat.NONE;
                break;
            }
            if (minSize.unwrap() == maxSize.unwrap()) {
                axisSize = OptionalFloat.some(axisSize.unwrap() + track.baseSize);
            }
            else {
                axisSize = OptionalFloat.NONE;
                break;
            }
        }

        final other = axis.other();
        final otherSize = sumTrackSizeEstimates(otherAxisTracks, trackRangeStart(other), trackRangeEnd(other), estimate, availableSpace.get(other));

        return axis == Inline ? new SizeOpt(axisSize, otherSize) : new SizeOpt(otherSize, axisSize);
    }

    /** Retrieve the grid area size from the cache or compute it using the passed parameters */
    public function gridAreaSizeCached(axis:AbstractAxis, axisTracks:Array<GridTrack>, otherAxisTracks:Array<GridTrack>,
            availableSpace:SizeOpt, estimate:Int):SizeOpt {
        final cached = gridAreaSizeCache;
        if (cached != null)
            return cached;
        final size = gridAreaSize(axis, axisTracks, otherAxisTracks, availableSpace, estimate);
        gridAreaSizeCache = size;
        return size;
    }

    /**
     * Compute the item's resolved margins for size contributions. Horizontal percentage margins always resolve
     * to zero if the container size is indefinite as otherwise this would introduce a cyclic dependency.
     */
    public inline function marginsAxisSumsWithBaselineShims(innerNodeWidth:OptionalFloat, tree:LayoutPartialTree):Size {
        return new Size(
            margin.left.resolveOrZero(OptionalFloat.some(0.0)) + margin.right.resolveOrZero(OptionalFloat.some(0.0)),
            margin.top.resolveOrZero(innerNodeWidth) + baselineShim + margin.bottom.resolveOrZero(innerNodeWidth)
        );
    }

    /** Compute the item's min content contribution from the provided parameters */
    public function minContentContribution(axis:AbstractAxis, tree:LayoutPartialTree, gridAreaSize:SizeOpt,
            availableSpace:SizeOpt):Float {
        final knownDimensions = knownDimensionsCached(tree, gridAreaSize);
        // If the item's size in the axis being measured is already known then that size is its contribution,
        // and we can avoid calling into the child entirely.
        final known = knownDimensions.get(axis);
        if (known.isSome())
            return known.unwrap();
        // The child sees the grid area as its containing block during intrinsic measurement, so
        // percentage box properties resolve against the grid area when that size is definite.
        // Spec:
        // https://www.w3.org/TR/css-grid-1/#grid-item-sizing
        // https://www.w3.org/TR/css-grid-1/#algo-overview
        final space = availableSpaceMinusMargins(gridAreaSize, availableSpace, tree);
        return LayoutPartialTreeExt.measureChildSize(
            tree,
            node,
            knownDimensions,
            gridAreaSize,
            keywordAdjustedAvailableSpace(gridAreaSize, new SizeAvail(
                space.width.isSome() ? Definite(space.width.unwrap()) : MinContent,
                space.height.isSome() ? Definite(space.height.unwrap()) : MinContent
            ), tree),
            InherentSize,
            axis.asAbsNaive(),
            FALSE_LINE
        );
    }

    /** Retrieve the item's min content contribution from the cache or compute it using the provided parameters */
    public inline function minContentContributionCached(axis:AbstractAxis, tree:LayoutPartialTree, gridAreaSize:SizeOpt,
            availableSpace:SizeOpt):Float {
        final cached = axis == Inline ? minContentContributionCacheWidth : minContentContributionCacheHeight;
        return if (cached.isSome()) {
            cached.unwrap();
        }
        else {
            final size = minContentContribution(axis, tree, gridAreaSize, availableSpace);
            if (axis == Inline)
                minContentContributionCacheWidth = OptionalFloat.some(size);
            else
                minContentContributionCacheHeight = OptionalFloat.some(size);
            size;
        }
    }

    /** Compute the item's max content contribution from the provided parameters */
    public function maxContentContribution(axis:AbstractAxis, tree:LayoutPartialTree, gridAreaSize:SizeOpt,
            availableSpace:SizeOpt):Float {
        final knownDimensions = knownDimensionsCached(tree, gridAreaSize);
        // If the item's size in the axis being measured is already known then that size is its contribution,
        // and we can avoid calling into the child entirely.
        final known = knownDimensions.get(axis);
        if (known.isSome())
            return known.unwrap();
        // See the min-content path above. Max-content measurement uses the same containing-block
        // basis so percentage-dependent item geometry is measured from the grid area rather than
        // from the container.
        final space = availableSpaceMinusMargins(gridAreaSize, availableSpace, tree);
        return LayoutPartialTreeExt.measureChildSize(
            tree,
            node,
            knownDimensions,
            gridAreaSize,
            keywordAdjustedAvailableSpace(gridAreaSize, new SizeAvail(
                space.width.isSome() ? Definite(space.width.unwrap()) : MaxContent,
                space.height.isSome() ? Definite(space.height.unwrap()) : MaxContent
            ), tree),
            InherentSize,
            axis.asAbsNaive(),
            FALSE_LINE
        );
    }

    /**
     * Subtract the item's margins (and baseline shim) from the definite axes of the space available
     * to the item's margin box, giving the available space that is passed to the item.
     * As when the item is laid out into its final position, margins resolve against the width
     * of the grid area and `auto` margins are treated as zero.
     */
    inline function availableSpaceMinusMargins(gridAreaSize:SizeOpt, availableSpace:SizeOpt,
            tree:LayoutPartialTree):SizeOpt {
        return if (availableSpace.width.isNone() && availableSpace.height.isNone()) {
            availableSpace;
        }
        else {
            final margin = this.margin.resolveOrZero(gridAreaSize.width);
            new SizeOpt(
                availableSpace.width.isSome() ? OptionalFloat.some(Sys.f32Max(availableSpace.width.unwrap() - margin.horizontalAxisSum(), 0.0)) : OptionalFloat.NONE,
                availableSpace.height.isSome() ? OptionalFloat.some(Sys.f32Max(availableSpace.height.unwrap() - margin.verticalAxisSum() - baselineShim, 0.0)) : OptionalFloat.NONE
            );
        }
    }

    /**
     * Override the available space in each axis whose size style is a sizing keyword that
     * measures the item under a specific available space constraint
     * (min-content, max-content, fit-content, fit-content(...))
     */
    function keywordAdjustedAvailableSpace(gridAreaSize:SizeOpt, availableSpace:SizeAvail,
            tree:LayoutPartialTree):SizeAvail {
        if (!size.width.isSizingKeyword() && !size.height.isSizingKeyword())
            return availableSpace;
        final margins = marginsAxisSumsWithBaselineShims(gridAreaSize.width, tree);
        var adjusted = availableSpace;
        for (axis in [AbstractAxis.Inline, AbstractAxis.Block]) {
            final sizeStyle = size.get(axis);
            if (!sizeStyle.isSizingKeyword())
                continue;
            final stretchSize = gridAreaSize.get(axis).maybeSub(OptionalFloat.some(margins.get(axis))).maybeMax(OptionalFloat.some(0.0));
            switch SizingKeyword.resolveSizingKeyword(sizeStyle, stretchSize, gridAreaSize.get(axis)) {
                case Measure(available):
                    adjusted = adjusted.with(axis, available);
                case _:
            }
        }
        return adjusted;
    }

    /** Retrieve the item's max content contribution from the cache or compute it using the provided parameters */
    public inline function maxContentContributionCached(axis:AbstractAxis, tree:LayoutPartialTree, gridAreaSize:SizeOpt,
            availableSpace:SizeOpt):Float {
        final cached = axis == Inline ? maxContentContributionCacheWidth : maxContentContributionCacheHeight;
        return if (cached.isSome()) {
            cached.unwrap();
        }
        else {
            final size = maxContentContribution(axis, tree, gridAreaSize, availableSpace);
            if (axis == Inline)
                maxContentContributionCacheWidth = OptionalFloat.some(size);
            else
                maxContentContributionCacheHeight = OptionalFloat.some(size);
            size;
        }
    }

    /**
     * The minimum contribution of an item is the smallest outer size it can have.
     * Specifically:
     *   - If the item's computed preferred size behaves as auto or depends on the size of its containing block in the relevant axis:
     *     Its minimum contribution is the outer size that would result from assuming the item's used minimum size as its preferred size;
     *   - Else the item's minimum contribution is its min-content contribution.
     *
     * Because the minimum contribution often depends on the size of the item's content, it is considered a type of intrinsic size contribution.
     * See: https://www.w3.org/TR/css-grid-1/#min-size-auto
     */
    public function minimumContribution(tree:LayoutPartialTree, axis:AbstractAxis, axisTracks:Array<GridTrack>, gridAreaSize:SizeOpt,
            innerNodeSize:SizeOpt):Float {
        final padding = this.padding.resolveOrZero(gridAreaSize.width);
        final border = this.border.resolveOrZero(gridAreaSize.width);
        final paddingBorderSize = padding.add(border).sumAxes();
        final boxSizingAdjustment = boxSizing == ContentBox ? paddingBorderSize : Size.ZERO;

        final preferred = size.maybeResolve(gridAreaSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment).get(axis);
        if (preferred.isSome()) {
            // A definite preferred size is clamped by the minimum and maximum sizes. For a compressible replaced
            // element, an indefinite percentage maximum size is resolved against zero.
            final minSizeStyle = minSize.get(axis);
            final maxSizeStyle = maxSize.get(axis);
            if (minSizeStyle.isAuto() && maxSizeStyle.isAuto())
                return preferred.unwrap();
            final basis = gridAreaSize.get(axis);
            final maxSizeBasis:OptionalFloat = isCompressibleReplaced ? (basis.isSome() ? basis : OptionalFloat.some(0.0)) : basis;
            final adjustment = boxSizingAdjustment.get(axis);
            final min = minSizeStyle.maybeResolve(basis);
            final max = maxSizeStyle.maybeResolve(maxSizeBasis);
            return MaybeMath.maybeClampF(preferred.unwrap(), min.maybeAdd(OptionalFloat.some(adjustment)), max.maybeAdd(OptionalFloat.some(adjustment)));
        }

        // A preferred size that is a sizing keyword other than `stretch` does not behave as auto,
        // so the minimum contribution is the min-content contribution.
        final sizeStyle = size.get(axis);
        if (sizeStyle.isSizingKeyword() && !sizeStyle.isStretch())
            return minContentContributionCached(axis, tree, gridAreaSize, gridAreaSize);

        final zeroedGridAreaSize = new SizeOpt(
            gridAreaSize.width.isSome() ? gridAreaSize.width : OptionalFloat.some(0.0),
            gridAreaSize.height.isSome() ? gridAreaSize.height : OptionalFloat.some(0.0)
        );
        final resolvedMinSize = minSize.maybeResolve(zeroedGridAreaSize).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment).get(axis);
        if (resolvedMinSize.isSome())
            return resolvedMinSize.unwrap();

        final automaticMinSize = (axis == Inline ? overflow.x : overflow.y).maybeIntoAutomaticMinSize();
        if (automaticMinSize.isSome())
            return automaticMinSize.unwrap();

        // Automatic minimum size. See https://www.w3.org/TR/css-grid-1/#min-size-auto

        // To provide a more reasonable default minimum size for grid items, the used value of its automatic minimum size
        // in a given axis is the content-based minimum size if all of the following are true:
        final rangeStart = trackRangeStart(axis);
        final rangeEnd = trackRangeEnd(axis);

        // it is not a scroll container (handled above)

        // it spans at least one track in that axis whose min track sizing function is auto
        final axisInnerNodeSize = innerNodeSize.get(axis);
        var spansAutoMinTrack = false;
        var spansFlexibleTrack = false;
        for (i in rangeStart...rangeEnd) {
            final track = axisTracks[i];
            if (track.minTrackSizingFunction.behavesAsAuto(axisInnerNodeSize))
                spansAutoMinTrack = true;
            if (track.maxTrackSizingFunction.isFr())
                spansFlexibleTrack = true;
        }

        // if it spans more than one track in that axis, none of those tracks are flexible
        final onlySpanOneTrack = rangeEnd - rangeStart == 1;
        final useContentBasedMinimum = spansAutoMinTrack && (onlySpanOneTrack || !spansFlexibleTrack);

        // Otherwise, the automatic minimum size is zero, as usual.
        if (useContentBasedMinimum) {
            var minimumContribution = minContentContributionCached(axis, tree, gridAreaSize, gridAreaSize);

            // If the item is a compressible replaced element, and has a definite preferred size or maximum size in the
            // relevant axis, the size suggestion is capped by those sizes; for this purpose, any indefinite percentages
            // in these sizes are resolved against zero (and considered definite).
            if (isCompressibleReplaced) {
                final s = size.get(axis).maybeResolve(OptionalFloat.some(0.0));
                final m = maxSize.get(axis).maybeResolve(OptionalFloat.some(0.0));
                minimumContribution = MaybeMath.maybeMinF(MaybeMath.maybeMinF(minimumContribution, s), m);
            }

            // The content-based minimum size is additionally clamped by the sum of any fixed max track sizing
            // functions of the tracks the item spans. Note that this clamp does not apply to explicitly specified
            // preferred or minimum sizes, and that the argument to fit-content() does not clamp the content-based
            // minimum size in the same way as a fixed max track sizing function. The clamp is a stretch fit into
            // the limit, so it does not shrink the item below its padding + border.
            final limit = spannedFixedTrackLimit(axis, axisTracks, axisInnerNodeSize);
            return MaybeMath.maybeMinF(minimumContribution, limit.isSome() ? OptionalFloat.some(Sys.f32Max(limit.unwrap(), paddingBorderSize.get(axis))) : OptionalFloat.NONE);
        }
        else {
            return 0.0;
        }
    }

    /** Retrieve the item's minimum contribution from the cache or compute it using the provided parameters */
    public inline function minimumContributionCached(tree:LayoutPartialTree, axis:AbstractAxis, axisTracks:Array<GridTrack>,
            gridAreaSize:SizeOpt, innerNodeSize:SizeOpt):Float {
        final cached = axis == Inline ? minimumContributionCacheWidth : minimumContributionCacheHeight;
        return if (cached.isSome()) {
            cached.unwrap();
        }
        else {
            final size = minimumContribution(tree, axis, axisTracks, gridAreaSize, innerNodeSize);
            if (axis == Inline)
                minimumContributionCacheWidth = OptionalFloat.some(size);
            else
                minimumContributionCacheHeight = OptionalFloat.some(size);
            size;
        }
    }

}
