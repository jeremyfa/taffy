// Ported from taffy 0.15.0: src/compute/grid/track_sizing.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.grid;

import taffy.compute.grid.GridCoordinates.IntLine;

import haxe.ds.ArraySort;
import taffy.geometry.AbstractAxis;
import taffy.geometry.LineOf;
import taffy.geometry.SizeOf;
import taffy.style.AlignContent;
import taffy.style.AlignContentKeyword;
import taffy.style.AvailableSpace;
import taffy.style.CompactLength;
import taffy.tree.LayoutPartialTree;
import taffy.util.MaybeMath;
import taffy.util.Sys;

using taffy.geometry.SizeOf;
using taffy.style.AvailableSpace;

/**
 * This class captures a bunch of variables which are used to compute the intrinsic sizes of children so that those variables
 * don't have to be passed around all over the place below. It then has methods that implement the intrinsic sizing computations
 */
class IntrinsicSizeMeasurer {

    /** The layout tree */
    final tree:LayoutPartialTree;

    /** The tracks in the opposite axis to the one we are currently sizing */
    final otherAxisTracks:Array<GridTrack>;

    /**
     * Which estimate of an other-axis track's size is passed to the child size measurement functions
     * (`GridItem.ESTIMATE_MAX_TRACK_DEFINITE_VALUE` or `GridItem.ESTIMATE_BASE_SIZE`)
     */
    final getTrackSizeEstimate:Int;

    /** The axis we are currently sizing */
    final axis:AbstractAxis;

    /** The available grid space */
    final innerNodeSize:SizeOf<Null<Float>>;

    public inline function new(tree:LayoutPartialTree, otherAxisTracks:Array<GridTrack>, getTrackSizeEstimate:Int, axis:AbstractAxis,
            innerNodeSize:SizeOf<Null<Float>>) {
        this.tree = tree;
        this.otherAxisTracks = otherAxisTracks;
        this.getTrackSizeEstimate = getTrackSizeEstimate;
        this.axis = axis;
        this.innerNodeSize = innerNodeSize;
    }

    /**
     * Compute the available_space to be passed to the child sizing functions
     * These are estimates based on either the max track sizing function or the provisional base size in the opposite
     * axis to the one currently being sized.
     * https://www.w3.org/TR/css-grid-1/#algo-overview
     */
    inline function gridAreaSize(item:GridItem, axisTracks:Array<GridTrack>):SizeOf<Null<Float>> {
        return item.gridAreaSizeCached(axis, axisTracks, otherAxisTracks, innerNodeSize, getTrackSizeEstimate);
    }

    /** Retrieve the item's min content contribution from the cache or compute it using the provided parameters */
    public function minContentContribution(item:GridItem, axisTracks:Array<GridTrack>):Float {
        final gridAreaSize = gridAreaSize(item, axisTracks);
        final availableSpace = gridAreaSize.with(axis, null);
        final marginAxisSums = item.marginsAxisSumsWithBaselineShims(availableSpace.width, tree);
        final contribution = item.minContentContributionCached(axis, tree, gridAreaSize, availableSpace);
        return contribution + marginAxisSums.get(axis);
    }

    /** Retrieve the item's max content contribution from the cache or compute it using the provided parameters */
    public function maxContentContribution(item:GridItem, axisTracks:Array<GridTrack>):Float {
        final gridAreaSize = gridAreaSize(item, axisTracks);
        final availableSpace = gridAreaSize.with(axis, null);
        final marginAxisSums = item.marginsAxisSumsWithBaselineShims(availableSpace.width, tree);
        final contribution = item.maxContentContributionCached(axis, tree, gridAreaSize, availableSpace);
        return contribution + marginAxisSums.get(axis);
    }

    /**
     * The minimum contribution of an item is the smallest outer size it can have.
     * Specifically:
     *   - If the item's computed preferred size behaves as auto or depends on the size of its containing block in the relevant axis:
     *     Its minimum contribution is the outer size that would result from assuming the item's used minimum size as its preferred size;
     *   - Else the item's minimum contribution is its min-content contribution.
     *
     * Because the minimum contribution often depends on the size of the item's content, it is considered a type of intrinsic size contribution.
     */
    public function minimumContribution(item:GridItem, axisTracks:Array<GridTrack>):Float {
        final gridAreaSize = gridAreaSize(item, axisTracks);
        final availableSpace = gridAreaSize.with(axis, null);
        final marginAxisSums = item.marginsAxisSumsWithBaselineShims(availableSpace.width, tree);
        final contribution = item.minimumContributionCached(tree, axis, axisTracks, gridAreaSize, innerNodeSize);
        return contribution + marginAxisSums.get(axis);
    }

}

/**
 * Implements the track sizing algorithm
 * https://www.w3.org/TR/css-grid-1/#layout-algorithm
 */
class TrackSizing {

    // Track predicates (the `track_is_affected` closures of the Rust code). The low 4 bits of a filter.

    /** The track has an intrinsic min track sizing function (no definite min value) */
    static inline final P_INTRINSIC_MIN:Int = 0;
    /** The track has a `min-content` or `max-content` min track sizing function */
    static inline final P_MIN_OR_MAX_CONTENT_MIN:Int = 1;
    /** The track has an `auto` min track sizing function and not a `min-content` max track sizing function */
    static inline final P_AUTO_MIN:Int = 2;
    /** The track has a `max-content` min track sizing function */
    static inline final P_MAX_CONTENT_MIN:Int = 3;
    /** The track has an intrinsic max track sizing function (no definite max value) */
    static inline final P_INTRINSIC_MAX:Int = 4;
    /** The track has a max-content alike max track sizing function (or a percentage one with an indefinite container size) */
    static inline final P_MAX_CONTENT_MAX:Int = 5;
    /** Every track */
    static inline final P_ALL:Int = 6;
    /** `P_AUTO_MIN || P_MAX_CONTENT_MIN` */
    static inline final P_AUTO_OR_MAX_CONTENT_MIN:Int = 7;
    static inline final P_MASK:Int = 15;

    /** Filter flag: the track must also be flexible */
    static inline final F_FLEXIBLE:Int = 16;
    /** Filter flag: the track must also have an intrinsic max track sizing function */
    static inline final F_MAX_INTRINSIC:Int = 32;
    /** Filter flag: the track must also have a `max-content` or `fit-content()` max track sizing function */
    static inline final F_MAX_OR_FIT_CONTENT:Int = 64;
    /** Filter flag: the track must also be infinitely growable (or have an infinite growth limit) */
    static inline final F_GROWABLE:Int = 128;

    // Track limits

    /** The growth limit */
    static inline final L_GROWTH_LIMIT:Int = 0;
    /** The growth limit capped by the `fit-content()` limit */
    static inline final L_FIT_CONTENT_LIMITED_GROWTH_LIMIT:Int = 1;
    /** Infinity */
    static inline final L_INFINITY:Int = 2;
    /** The `fit-content()` limit */
    static inline final L_FIT_CONTENT_LIMIT:Int = 3;

    // Affected track properties

    /** The base size */
    static inline final A_BASE_SIZE:Int = 0;
    /** The growth limit (or the base size if the growth limit is infinite) */
    static inline final A_GROWTH_LIMIT_OR_BASE_SIZE:Int = 1;

    // Intrinsic contribution types

    /** It's a minimum size's space being distributed */
    static inline final CONTRIBUTION_MINIMUM:Int = 0;
    /** It's a maximum size's space being distributed */
    static inline final CONTRIBUTION_MAXIMUM:Int = 1;

    static final FALSE_LINE:LineOf<Bool> = new LineOf<Bool>(false, false);

    static inline function trackMatches(track:GridTrack, filter:Int, axisInnerNodeSize:Null<Float>):Bool {
        final predicate = filter & P_MASK;
        var matches = switch predicate {
            case P_INTRINSIC_MIN: track.minTrackSizingFunction.definiteValue(axisInnerNodeSize) == null;
            case P_MIN_OR_MAX_CONTENT_MIN: track.minTrackSizingFunction.isMinOrMaxContent();
            case P_AUTO_MIN: hasAutoMinTrackSizingFunction(track);
            case P_MAX_CONTENT_MIN: track.minTrackSizingFunction.isMaxContent();
            case P_INTRINSIC_MAX: !track.maxTrackSizingFunction.hasDefiniteValue(axisInnerNodeSize);
            case P_MAX_CONTENT_MAX:
                track.maxTrackSizingFunction.isMaxContentAlike() || (track.maxTrackSizingFunction.usesPercentage() && axisInnerNodeSize == null);
            case P_AUTO_OR_MAX_CONTENT_MIN: hasAutoMinTrackSizingFunction(track) || track.minTrackSizingFunction.isMaxContent();
            case _: true;
        }
        if (matches && filter > P_MASK) {
            if ((filter & F_FLEXIBLE) != 0 && !track.isFlexible())
                matches = false;
            else if ((filter & F_MAX_INTRINSIC) != 0 && !track.maxTrackSizingFunction.isIntrinsic())
                matches = false;
            else if ((filter & F_MAX_OR_FIT_CONTENT) != 0 && !track.maxTrackSizingFunction.isMaxOrFitContent())
                matches = false;
            else if ((filter & F_GROWABLE) != 0 && !(track.infinitelyGrowable || track.growthLimit == Math.POSITIVE_INFINITY))
                matches = false;
        }
        return matches;
    }

    /**
     * Whether a track:
     *   - has an Auto MIN track sizing function
     *   - Does not have a MinContent MAX track sizing function
     *
     * The latter condition was added in order to match Chrome. But I believe it is due to the provision
     * under minmax here https://www.w3.org/TR/css-grid-1/#track-sizes which states that:
     *
     *    "If the max is less than the min, then the max will be floored by the min (essentially yielding minmax(min, min))"
     */
    static inline function hasAutoMinTrackSizingFunction(track:GridTrack):Bool {
        return track.minTrackSizingFunction.isAuto() && !track.maxTrackSizingFunction.isMinContent();
    }

    static inline function trackLimit(track:GridTrack, limit:Int):Float {
        return switch limit {
            case L_GROWTH_LIMIT: track.growthLimit;
            case L_FIT_CONTENT_LIMITED_GROWTH_LIMIT: track.fitContentLimitedGrowthLimit();
            case L_INFINITY: Math.POSITIVE_INFINITY;
            case _: track.fitContentLimit();
        }
    }

    static inline function trackAffectedProperty(track:GridTrack, property:Int):Float {
        return property == A_BASE_SIZE ? track.baseSize : (track.growthLimit == Math.POSITIVE_INFINITY ? track.baseSize : track.growthLimit);
    }

    static inline function trackDistributionProportion(track:GridTrack, useFlexFactor:Bool):Float {
        return useFlexFactor ? track.flexFactor() : 1.0;
    }

    /** Whether any track spanned by the item in the specified axis satisfies the filter */
    static inline function spansTrackMatching(item:GridItem, axis:AbstractAxis, axisTracks:Array<GridTrack>, filter:Int,
            axisInnerNodeSize:Null<Float>):Bool {
        var result = false;
        for (i in item.trackRangeStart(axis)...item.trackRangeEnd(axis)) {
            if (trackMatches(axisTracks[i], filter, axisInnerNodeSize)) {
                result = true;
                break;
            }
        }
        return result;
    }

    /**
     * When applying the track sizing algorithm and estimating the size in the other axis for content sizing items
     * we should take into account align-content/justify-content if both the grid container and all items in the
     * other axis have definite sizes. This function computes such a per-gutter additional size adjustment.
     */
    public static function computeAlignmentGutterAdjustment(alignment:AlignContent, axisInnerNodeSize:Null<Float>, getTrackSizeEstimate:Int,
            tracks:Array<GridTrack>):Float {
        if (tracks.length <= 1)
            return 0.0;

        // As items never cross the outermost gutters in a grid, we can simplify our calculations by
        // treating Start and End the same. The safety modifier doesn't influence gutter weight;
        // overflow fallback is handled when offsets are computed.
        final outerGutterWeight = switch alignment.keyword {
            case Start | FlexStart | End | FlexEnd | Center: 1;
            // Normal is resolved to Stretch in `computeGridLayout`
            case Normal | Stretch: 0;
            case SpaceBetween: 0;
            case SpaceAround: 1;
            case SpaceEvenly: 1;
        }

        final innerGutterWeight = switch alignment.keyword {
            case FlexStart | Start | FlexEnd | End | Center | Normal | Stretch: 0;
            case SpaceBetween: 1;
            case SpaceAround: 2;
            case SpaceEvenly: 1;
        }

        if (innerGutterWeight == 0)
            return 0.0;

        if (axisInnerNodeSize != null) {
            final size:Float = axisInnerNodeSize;
            var trackSizeSum:Null<Float> = 0.0;
            for (track in tracks) {
                final estimate = GridItem.trackSizeEstimate(track, getTrackSizeEstimate, size);
                if (estimate == null) {
                    trackSizeSum = null;
                    break;
                }
                trackSizeSum = (trackSizeSum : Float) + (estimate : Float);
            }
            final freeSpace = trackSizeSum != null ? Sys.f32Max(0.0, size - (trackSizeSum : Float)) : 0.0;

            final weightedTrackCount = (Std.int((tracks.length - 3) / 2) * innerGutterWeight) + (2 * outerGutterWeight);

            return (freeSpace / weightedTrackCount) * innerGutterWeight;
        }

        return 0.0;
    }

    /** Convert origin-zero coordinates track placement in grid track vector indexes */
    public static function resolveItemTrackIndexes(items:Array<GridItem>, columnCounts:TrackCounts, rowCounts:TrackCounts):Void {
        for (item in items) {
            item.columnIndexes = new IntLine(
                GridCoordinates.intoTrackVecIndex(item.column.start, columnCounts),
                GridCoordinates.intoTrackVecIndex(item.column.end, columnCounts)
            );
            item.rowIndexes = new IntLine(
                GridCoordinates.intoTrackVecIndex(item.row.start, rowCounts),
                GridCoordinates.intoTrackVecIndex(item.row.end, rowCounts)
            );
        }
    }

    /** Determine (in each axis) whether the item crosses any flexible tracks */
    public static function determineIfItemCrossesFlexibleOrIntrinsicTracks(items:Array<GridItem>, columns:Array<GridTrack>, rows:Array<GridTrack>):Void {
        for (item in items) {
            var flexibleColumn = false;
            var intrinsicColumn = false;
            for (i in item.trackRangeStart(Inline)...item.trackRangeEnd(Inline)) {
                if (columns[i].isFlexible())
                    flexibleColumn = true;
                if (columns[i].hasIntrinsicSizingFunction())
                    intrinsicColumn = true;
            }
            var flexibleRow = false;
            var intrinsicRow = false;
            for (i in item.trackRangeStart(Block)...item.trackRangeEnd(Block)) {
                if (rows[i].isFlexible())
                    flexibleRow = true;
                if (rows[i].hasIntrinsicSizingFunction())
                    intrinsicRow = true;
            }
            item.crossesFlexibleColumn = flexibleColumn;
            item.crossesIntrinsicColumn = intrinsicColumn;
            item.crossesFlexibleRow = flexibleRow;
            item.crossesIntrinsicRow = intrinsicRow;
        }
    }

    /**
     * Track sizing algorithm
     * Note: Gutters are treated as empty fixed-size tracks for the purpose of the track sizing algorithm.
     *
     * `getTrackSizeEstimate` is `GridItem.ESTIMATE_MAX_TRACK_DEFINITE_VALUE` or `GridItem.ESTIMATE_BASE_SIZE`.
     */
    public static function trackSizingAlgorithm(tree:LayoutPartialTree, axis:AbstractAxis, axisMinSize:Null<Float>, axisMaxSize:Null<Float>,
            axisAlignment:AlignContent, otherAxisAlignment:AlignContent, availableGridSpace:SizeOf<AvailableSpace>, innerNodeSize:SizeOf<Null<Float>>,
            axisTracks:Array<GridTrack>, otherAxisTracks:Array<GridTrack>, items:Array<GridItem>, getTrackSizeEstimate:Int,
            hasBaselineAlignedItem:Bool):Void {
        // 11.4 Initialise Track sizes
        // Initialize each track's base size and growth limit.
        final percentageBasis = MaybeMath.or(innerNodeSize.get(axis), axisMinSize);
        initializeTrackSizes(axisTracks, percentageBasis);

        // Resolve fit-content() limits against the container's inner size (these are fixed for the rest of this pass)
        final axisInnerNodeSize = innerNodeSize.get(axis);
        for (track in axisTracks)
            track.resolveFitContentLimit(axisInnerNodeSize);

        // 11.5.1 Shim item baselines
        if (hasBaselineAlignedItem)
            resolveItemBaselines(tree, axis, items, innerNodeSize);

        // If all tracks have a fixed min track sizing function and base_size = growth_limit,
        // then the track sizes are already final and we can skip the rest of this function.
        // Note that tracks with an intrinsic min track sizing function can still grow beyond
        // a fixed growth limit (e.g. minmax(auto, 0px)), so they cannot be skipped.
        var allFinal = true;
        for (track in axisTracks) {
            if (!(track.baseSize == track.growthLimit && track.minTrackSizingFunction.definiteValue(percentageBasis) != null)) {
                allFinal = false;
                break;
            }
        }
        if (allFinal)
            return;

        // Pre-computations for 11.5 Resolve Intrinsic Track Sizes

        // Compute an additional amount to add to each spanned gutter when computing item's estimated size in the
        // in the opposite axis based on the alignment, container size, and estimated track sizes in that axis
        final gutterAlignmentAdjustment = computeAlignmentGutterAdjustment(otherAxisAlignment, innerNodeSize.get(axis.other()), getTrackSizeEstimate,
            otherAxisTracks);
        if (otherAxisTracks.length > 3) {
            final len = otherAxisTracks.length;
            var i = 2;
            while (i < len) {
                otherAxisTracks[i].contentAlignmentAdjustment = gutterAlignmentAdjustment;
                i += 2;
            }
        }

        // 11.5 Resolve Intrinsic Track Sizes
        resolveIntrinsicTrackSizes(tree, axis, axisTracks, otherAxisTracks, items, availableGridSpace.get(axis), innerNodeSize, getTrackSizeEstimate);

        // 11.6. Maximise Tracks
        // Distributes free space (if any) to tracks with FINITE growth limits, up to their limits.
        maximiseTracks(axisTracks, availableGridSpace.get(axis));

        // For the purpose of the final two expansion steps ("Expand Flexible Tracks" and "Stretch auto Tracks"), we only want to expand
        // into space generated by the grid container's size (as defined by either it's preferred size style or by it's parent node through
        // something like stretch alignment), not just any available space. To do this we map definite available space to AvailableSpace::MaxContent
        // in the case that inner_node_size is None. A min-content constraint in the block axis is also mapped to AvailableSpace::MaxContent,
        // as the min-content block size of a grid container is its max-content block size.
        final axisInner = innerNodeSize.get(axis);
        final axisAvailableSpaceForExpansion:AvailableSpace = if (axisInner != null) {
            Definite(axisInner);
        }
        else {
            switch availableGridSpace.get(axis) {
                case MinContent if (axis == Inline): MinContent;
                case _: MaxContent;
            }
        }

        // 11.7. Expand Flexible Tracks
        // This step sizes flexible tracks using the largest value it can assign to an fr without exceeding the available space.
        expandFlexibleTracks(tree, axis, axisTracks, otherAxisTracks, items, axisMinSize, axisMaxSize, axisAvailableSpaceForExpansion, innerNodeSize,
            getTrackSizeEstimate);

        // 11.8. Stretch auto Tracks
        // This step expands tracks that have an auto max track sizing function by dividing any remaining positive, definite free space equally amongst them.
        if (axisAlignment == AlignContent.STRETCH)
            stretchAutoTracks(axisTracks, axisMinSize, axisAvailableSpaceForExpansion);
    }

    /**
     * Add any planned base size increases to the base size after a round of distributing space to base sizes
     * Reset the planed base size increase to zero ready for the next round.
     */
    static inline function flushPlannedBaseSizeIncreases(tracks:Array<GridTrack>):Void {
        for (track in tracks) {
            track.baseSize += track.baseSizePlannedIncrease;
            track.baseSizePlannedIncrease = 0.0;
        }
    }

    /**
     * Add any planned growth limit increases to the growth limit after a round of distributing space to growth limits
     * Reset the planed growth limit increase to zero ready for the next round.
     */
    static inline function flushPlannedGrowthLimitIncreases(tracks:Array<GridTrack>, setInfinitelyGrowable:Bool):Void {
        for (track in tracks) {
            if (track.growthLimitPlannedIncrease > 0.0) {
                track.growthLimit = if (track.growthLimit == Math.POSITIVE_INFINITY) {
                    track.baseSize + track.growthLimitPlannedIncrease;
                }
                else {
                    track.growthLimit + track.growthLimitPlannedIncrease;
                }
                track.infinitelyGrowable = setInfinitelyGrowable;
            }
            else {
                track.infinitelyGrowable = false;
            }
            track.growthLimitPlannedIncrease = 0.0;
        }
    }

    /**
     * 11.4 Initialise Track sizes
     * Initialize each track's base size and growth limit.
     */
    static inline function initializeTrackSizes(axisTracks:Array<GridTrack>, axisInnerNodeSize:Null<Float>):Void {
        for (track in axisTracks) {
            // For each track, if the track's min track sizing function is:
            // - A fixed sizing function
            //     Resolve to an absolute length and use that size as the track's initial base size.
            //     Note: Indefinite lengths cannot occur, as they're treated as auto.
            // - An intrinsic sizing function
            //     Use an initial base size of zero.
            final baseSize = track.minTrackSizingFunction.definiteValue(axisInnerNodeSize);
            track.baseSize = baseSize != null ? (baseSize : Float) : 0.0;

            // For each track, if the track's max track sizing function is:
            // - A fixed sizing function
            //     Resolve to an absolute length and use that size as the track's initial growth limit.
            // - An intrinsic sizing function
            //     Use an initial growth limit of infinity.
            // - A flexible sizing function
            //     Use an initial growth limit of infinity.
            final growthLimit = track.maxTrackSizingFunction.definiteValue(axisInnerNodeSize);
            track.growthLimit = growthLimit != null ? (growthLimit : Float) : Math.POSITIVE_INFINITY;

            // In all cases, if the growth limit is less than the base size, increase the growth limit to match the base size.
            if (track.growthLimit < track.baseSize)
                track.growthLimit = track.baseSize;
        }
    }

    /** 11.5.1 Shim baseline-aligned items so their intrinsic size contributions reflect their baseline alignment. */
    static function resolveItemBaselines(tree:LayoutPartialTree, axis:AbstractAxis, allItems:Array<GridItem>, innerNodeSize:SizeOf<Null<Float>>):Void {
        // Sort items by track in the other axis (row) start position so that we can iterate items in groups which
        // are in the same track in the other axis (row)
        final otherAxis = axis.other();
        final items = allItems.copy();
        ArraySort.sort(items, (a, b) -> a.placement(otherAxis).start - b.placement(otherAxis).start);

        // Iterate over grid rows
        var rowStartIndex = 0;
        while (rowStartIndex < items.length) {
            // Get the row index of the current row
            final currentRow = items[rowStartIndex].placement(otherAxis).start;

            // Find the item index of the first item that is in a different row (or the end of the list)
            var rowEndIndex = rowStartIndex + 1;
            while (rowEndIndex < items.length && items[rowEndIndex].placement(otherAxis).start == currentRow)
                rowEndIndex++;

            final rowStart = rowStartIndex;
            rowStartIndex = rowEndIndex;

            // Count how many items in *this row* are baseline aligned
            // If a row has one or zero items participating in baseline alignment then baseline alignment is a no-op
            // for those items and we skip further computations for that row
            var rowBaselineItemCount = 0;
            for (i in rowStart...rowEndIndex) {
                if (items[i].participatesInBaselineAlignment())
                    rowBaselineItemCount++;
            }
            if (rowBaselineItemCount <= 1)
                continue;

            // Compute the baselines of all items in the row participating in baseline alignment
            for (i in rowStart...rowEndIndex) {
                final item = items[i];
                if (!item.participatesInBaselineAlignment())
                    continue;

                final measuredSizeAndBaselines = LayoutPartialTreeExt.performChildLayout(tree, item.node, OptionSizeTools.NONE, innerNodeSize,
                    AvailableSpaceSizeTools.MIN_CONTENT, InherentSize, FALSE_LINE);

                final baseline = measuredSizeAndBaselines.baselines.first;
                final height = measuredSizeAndBaselines.size.height;

                // Scroll containers' baselines are determined from their content as if scrolled to the
                // initial position, but are additionally clamped to their border box.
                // See https://github.com/w3c/csswg-drafts/issues/7660
                final resolvedBaseline = if (item.overflow.y.isScrollContainer()) {
                    Sys.f32Max(Sys.f32Min(baseline != null ? (baseline : Float) : height, height), 0.0);
                }
                else {
                    baseline != null ? (baseline : Float) : height;
                }

                item.baseline = resolvedBaseline + item.margin.top.resolveOrZero(innerNodeSize.width);
            }

            // Compute the max baseline of all items in the row participating in baseline alignment
            var rowMaxBaseline = Math.NEGATIVE_INFINITY;
            for (i in rowStart...rowEndIndex) {
                final item = items[i];
                if (item.participatesInBaselineAlignment()) {
                    final b = item.baseline != null ? (item.baseline : Float) : 0.0;
                    if (b > rowMaxBaseline)
                        rowMaxBaseline = b;
                }
            }

            // Compute the baseline shim for each item in the row participating in baseline alignment
            for (i in rowStart...rowEndIndex) {
                final item = items[i];
                if (item.participatesInBaselineAlignment()) {
                    item.baselineShim = rowMaxBaseline - (item.baseline != null ? (item.baseline : Float) : 0.0);
                    item.clearKnownDimensionsCache();
                }
            }
        }
    }

    /** 11.5 Resolve Intrinsic Track Sizes */
    static function resolveIntrinsicTrackSizes(tree:LayoutPartialTree, axis:AbstractAxis, axisTracks:Array<GridTrack>,
            otherAxisTracks:Array<GridTrack>, allItems:Array<GridItem>, axisAvailableGridSpace:AvailableSpace, innerNodeSize:SizeOf<Null<Float>>,
            getTrackSizeEstimate:Int):Void {
        // Step 1. Shim baseline-aligned items so their intrinsic size contributions reflect their baseline alignment.

        // Already done at this point. See resolveItemBaselines function.

        // Step 2.

        // The track sizing algorithm requires us to iterate through the items in ascending order of the number of
        // tracks they span (first items that span 1 track, then items that span 2 tracks, etc).
        // To avoid having to do multiple iterations of the items, we pre-sort them into this order.
        //
        // Items that cross a flexible track are all processed together in a single batch (regardless of their span), so
        // they only need to be moved to the end of the list. And the order in which items within a batch are processed
        // does not affect the result, so the remaining items only need to be sorted if any of them span more than one track.
        final itemCount = allItems.length;
        final items:Array<GridItem> = [];
        items.resize(itemCount);
        var frontLen = 0;
        var backLen = 0;
        var needsSort = false;
        for (item in allItems) {
            if (item.crossesFlexibleTrack(axis)) {
                // Items pushed to the back end up at the end of the array in the reverse of the order that they were pushed
                items[itemCount - backLen - 1] = item;
                backLen++;
            }
            else {
                if (item.span(axis) > 1)
                    needsSort = true;
                items[frontLen] = item;
                frontLen++;
            }
        }
        final nonFlexItemCount = frontLen;
        if (needsSort) {
            final nonFlexItems = items.slice(0, nonFlexItemCount);
            ArraySort.sort(nonFlexItems, (a, b) -> a.span(axis) - b.span(axis));
            for (i in 0...nonFlexItemCount)
                items[i] = nonFlexItems[i];
        }

        // Step 2, Step 3 and Step 4
        // 2 & 3. Iterate over items that don't cross a flex track. Items should have already been sorted in ascending order
        // of the number of tracks they span. Step 2 is the 1 track case and has an optimised implementation
        // 4. Next, repeat the previous step instead considering (together, rather than grouped by span size) all items
        // that do span a track with a flexible sizing function while

        // Compute item's intrinsic (content-based) sizes
        // Note: For items with a specified minimum size of auto (the initial value), the minimum contribution is usually equivalent
        // to the min-content contribution: but can differ in some cases, see 6.6 Automatic Minimum Size of Grid Items.
        // Also, minimum contribution <= min-content contribution <= max-content contribution.

        final axisInnerNodeSize = innerNodeSize.get(axis);
        final itemSizer = new IntrinsicSizeMeasurer(tree, otherAxisTracks, getTrackSizeEstimate, axis, innerNodeSize);

        final isMinOrMaxContentSpace = switch axisAvailableGridSpace {
            case MinContent | MaxContent: true;
            case _: false;
        }
        final isMaxContentSpace = switch axisAvailableGridSpace {
            case MaxContent: true;
            case _: false;
        }

        // Item batcher: a list of grid items sorted firstly by whether they cross a flex track
        // in the specified axis (items that don't cross a flex track first) and then by the number
        // of tracks they cross in specified axis (ascending order).
        var indexOffset = 0;
        var currentIsFlex = false;
        while (!(currentIsFlex || indexOffset >= items.length)) {
            final firstItem = items[indexOffset];
            final currentSpan = firstItem.span(axis);
            currentIsFlex = firstItem.crossesFlexibleTrack(axis);

            var nextIndexOffset = items.length;
            if (!currentIsFlex) {
                for (i in 0...items.length) {
                    final it = items[i];
                    if (it.crossesFlexibleTrack(axis) || it.span(axis) > currentSpan) {
                        nextIndexOffset = i;
                        break;
                    }
                }
            }

            final batchStart = indexOffset;
            final batchEnd = nextIndexOffset;
            indexOffset = nextIndexOffset;
            final isFlex = currentIsFlex;

            // 2. Size tracks to fit non-spanning items: For each track with an intrinsic track sizing function and not a flexible sizing function,
            // consider the items in it with a span of 1:
            final batchSpan = items[batchStart].placement(axis).span();
            if (!isFlex && batchSpan == 1) {
                for (b in batchStart...batchEnd) {
                    final item = items[b];
                    final trackIndex = item.placementIndexes(axis).start + 1;
                    final track = axisTracks[trackIndex];

                    // Handle base sizes
                    final newBaseSize = switch track.minTrackSizingFunction.tag() {
                        case CompactLength.MIN_CONTENT_TAG:
                            Sys.f32Max(track.baseSize, itemSizer.minContentContribution(item, axisTracks));
                        case CompactLength.MAX_CONTENT_TAG:
                            Sys.f32Max(track.baseSize, itemSizer.maxContentContribution(item, axisTracks));
                        // If the container size is indefinite and has not yet been resolved then percentage sized
                        // tracks are treated as auto
                        case _ if (track.minTrackSizingFunction.behavesAsAuto(axisInnerNodeSize)):
                            final space = if (isMinOrMaxContentSpace && !(axis == Inline ? item.overflow.x : item.overflow.y).isScrollContainer()) {
                                // QUIRK: The spec says that:
                                //
                                //   If the grid container is being sized under a min- or max-content constraint, use the items' limited
                                //   min-content contributions in place of their minimum contributions here.
                                //
                                // However, in practice browsers only seem to apply this rule if the item is not a scroll container
                                // (note that overflow:hidden counts as a scroll container), giving the automatic minimum size of scroll
                                // containers (zero) precedence over the min-content contributions.
                                final axisMinimumSize = itemSizer.minimumContribution(item, axisTracks);
                                final axisMinContentSize = itemSizer.minContentContribution(item, axisTracks);
                                final limit = track.maxTrackSizingFunction.definiteLimit(axisInnerNodeSize);
                                Sys.f32Max(MaybeMath.maybeMinF(axisMinContentSize, limit), axisMinimumSize);
                            }
                            else {
                                itemSizer.minimumContribution(item, axisTracks);
                            }
                            Sys.f32Max(track.baseSize, space);
                        // Do nothing as it's not an intrinsic track sizing function
                        case _:
                            track.baseSize;
                    }
                    axisTracks[trackIndex].baseSize = newBaseSize;

                    // Handle growth limits
                    //
                    // Computing an item's contributions calls into the child, so they are only computed if they are used.
                    // The min-content contribution is computed for every item in an intrinsic track (even where only the
                    // max-content contribution determines the growth limit), as the check for whether track sizing needs
                    // to be re-run compares each such item's min-content contribution against the one cached here.
                    final track = axisTracks[trackIndex];
                    final maxTrackSizingFunction = track.maxTrackSizingFunction;
                    final fitContentLimit = track.fitContentLimit();
                    final minContentContribution:Null<Float> = track.hasIntrinsicSizingFunction() ? itemSizer.minContentContribution(item,
                        axisTracks) : null;
                    final plannedIncrease:Null<Float> = if (maxTrackSizingFunction.isFitContent()) {
                        // Always increase the growth limit to at least the size of the *fit-content limited*
                        // max-content contribution
                        final maxContentContribution = Sys.f32Min(itemSizer.maxContentContribution(item, axisTracks), fitContentLimit);

                        // If item is not a scroll container, then increase the growth limit to at least the
                        // size of the min-content contribution
                        if (minContentContribution != null && !(axis == Inline ? item.overflow.x : item.overflow.y).isScrollContainer())
                            Sys.f32Max(minContentContribution, maxContentContribution);
                        else
                            maxContentContribution;
                    }
                    else if (maxTrackSizingFunction.isMaxContentAlike() || (maxTrackSizingFunction.usesPercentage() && axisInnerNodeSize == null)) {
                        // If the container size is indefinite and has not yet been resolved then percentage sized
                        // tracks should be treated as auto (this matches Chrome's behaviour and seems sensible)
                        itemSizer.maxContentContribution(item, axisTracks);
                    }
                    else if (maxTrackSizingFunction.isIntrinsic()) {
                        minContentContribution;
                    }
                    else {
                        null;
                    }
                    if (plannedIncrease != null) {
                        final t = axisTracks[trackIndex];
                        t.growthLimitPlannedIncrease = Sys.f32Max(t.growthLimitPlannedIncrease, plannedIncrease);
                    }
                }

                for (track in axisTracks) {
                    if (track.growthLimitPlannedIncrease > 0.0) {
                        track.growthLimit = if (track.growthLimit == Math.POSITIVE_INFINITY) {
                            track.growthLimitPlannedIncrease;
                        }
                        else {
                            Sys.f32Max(track.growthLimit, track.growthLimitPlannedIncrease);
                        }
                    }
                    track.infinitelyGrowable = false;
                    track.growthLimitPlannedIncrease = 0.0;
                    if (track.growthLimit < track.baseSize)
                        track.growthLimit = track.baseSize;
                }

                continue;
            }

            // 1. For intrinsic minimums:
            // First increase the base size of tracks with an intrinsic min track sizing function
            for (b in batchStart...batchEnd) {
                final item = items[b];
                if (!item.crossesIntrinsicTrack(axis))
                    continue;
                // ...by distributing extra space as needed to accommodate these items' minimum contributions.
                //
                // QUIRK: The spec says that:
                //
                //   If the grid container is being sized under a min- or max-content constraint, use the items' limited min-content contributions
                //   in place of their minimum contributions here.
                //
                // However, in practice browsers only seem to apply this rule if the item is not a scroll container (note that overflow:hidden counts as
                // a scroll container), giving the automatic minimum size of scroll containers (zero) precedence over the min-content contributions.
                final isScrollContainer = (axis == Inline ? item.overflow.x : item.overflow.y).isScrollContainer();
                final space = if (isMinOrMaxContentSpace && !isScrollContainer) {
                    final axisMinimumSize = itemSizer.minimumContribution(item, axisTracks);
                    final axisMinContentSize = itemSizer.minContentContribution(item, axisTracks);
                    final limit = item.spannedTrackLimit(axis, axisTracks, axisInnerNodeSize);
                    final limitedMinContent = Sys.f32Max(MaybeMath.maybeMinF(axisMinContentSize, limit), axisMinimumSize);

                    // For items crossing flexible tracks, browsers hand the content-derived contribution to
                    // the flexible tracks only in proportion to the crossed flex factor sum, clamped at one
                    // (CSS Grid 2, 12.5: "if the sum is less than one, distribute that proportion of
                    // space"). The proportion applies to the space left after covering the spanned
                    // inflexible tracks, and the item's minimum contribution acts as a floor on the result:
                    // a definite size still spreads over `0fr` tracks in full. This is what lets a `0fr`
                    // track holding a `min-height: 0` item collapse to zero, which the
                    // `grid-template-rows: 0fr` to `1fr` collapse animation pattern relies on.
                    if (isFlex) {
                        final inflexibleSizes = inflexibleBaseSizes(axisTracks, item.trackRangeStart(axis), item.trackRangeEnd(axis));
                        final scale = Sys.f32Min(crossedFlexFactorSum(axisTracks, item.trackRangeStart(axis), item.trackRangeEnd(axis)), 1.0);
                        final excess = Sys.f32Max(limitedMinContent - inflexibleSizes, 0.0);
                        Sys.f32Max(axisMinimumSize, inflexibleSizes + excess * scale);
                    }
                    else {
                        limitedMinContent;
                    }
                }
                else {
                    itemSizer.minimumContribution(item, axisTracks);
                }
                if (space > 0.0) {
                    final limit = isScrollContainer ? L_FIT_CONTENT_LIMITED_GROWTH_LIMIT : L_GROWTH_LIMIT;
                    distributeItemSpaceToBaseSize(isFlex, space, axisTracks, item.trackRangeStart(axis), item.trackRangeEnd(axis), P_INTRINSIC_MIN,
                        axisInnerNodeSize, limit, CONTRIBUTION_MINIMUM);
                }
            }
            flushPlannedBaseSizeIncreases(axisTracks);

            // 2. For content-based minimums:
            // Next continue to increase the base size of tracks with a min track sizing function of min-content or max-content
            // by distributing extra space as needed to account for these items' min-content contributions.
            for (b in batchStart...batchEnd) {
                final item = items[b];
                if (!spansTrackMatching(item, axis, axisTracks, P_MIN_OR_MAX_CONTENT_MIN, axisInnerNodeSize))
                    continue;
                final space = itemSizer.minContentContribution(item, axisTracks);
                if (space > 0.0) {
                    final isScrollContainer = (axis == Inline ? item.overflow.x : item.overflow.y).isScrollContainer();
                    final limit = isScrollContainer ? L_FIT_CONTENT_LIMITED_GROWTH_LIMIT : L_GROWTH_LIMIT;
                    distributeItemSpaceToBaseSize(isFlex, space, axisTracks, item.trackRangeStart(axis), item.trackRangeEnd(axis),
                        P_MIN_OR_MAX_CONTENT_MIN, axisInnerNodeSize, limit, CONTRIBUTION_MINIMUM);
                }
            }
            flushPlannedBaseSizeIncreases(axisTracks);

            // 3. For max-content minimums:

            // If the grid container is being sized under a max-content constraint, continue to increase the base size of tracks with
            // a min track sizing function of auto or max-content by distributing extra space as needed to account for these items'
            // limited max-content contributions.
            if (isMaxContentSpace) {
                for (b in batchStart...batchEnd) {
                    final item = items[b];
                    if (!spansTrackMatching(item, axis, axisTracks, P_AUTO_OR_MAX_CONTENT_MIN, axisInnerNodeSize))
                        continue;
                    final axisMaxContentSize = itemSizer.maxContentContribution(item, axisTracks);
                    final limit = item.spannedTrackLimit(axis, axisTracks, axisInnerNodeSize);
                    var space = MaybeMath.maybeMinF(axisMaxContentSize, limit);

                    // As for the intrinsic minimums above: scale the space beyond the spanned inflexible
                    // tracks by the crossed flex factor sum, clamped at one. Anchoring at the inflexible
                    // track sizes rather than the current base sizes keeps this pass from compounding with
                    // the scaling already applied to the min-content contribution.
                    if (isFlex) {
                        final inflexibleSizes = inflexibleBaseSizes(axisTracks, item.trackRangeStart(axis), item.trackRangeEnd(axis));
                        final scale = Sys.f32Min(crossedFlexFactorSum(axisTracks, item.trackRangeStart(axis), item.trackRangeEnd(axis)), 1.0);
                        space = inflexibleSizes + Sys.f32Max(space - inflexibleSizes, 0.0) * scale;
                    }
                    if (space > 0.0) {
                        // If any of the tracks spanned by the item have a MaxContent min track sizing function then
                        // distribute space only to those tracks. Otherwise distribute space to tracks with an Auto min
                        // track sizing function.
                        //
                        // Note: this prioritisation of MaxContent over Auto is not mentioned in the spec (which suggests that
                        // we ought to distribute space evenly between MaxContent and Auto tracks). But it is implemented like
                        // this in both Chrome and Firefox (and it does have a certain logic to it), so we implement it too for
                        // compatibility.
                        //
                        // See: https://www.w3.org/TR/css-grid-1/#track-size-max-content-min
                        if (spansTrackMatching(item, axis, axisTracks, P_MAX_CONTENT_MIN, axisInnerNodeSize)) {
                            distributeItemSpaceToBaseSize(isFlex, space, axisTracks, item.trackRangeStart(axis), item.trackRangeEnd(axis),
                                P_MAX_CONTENT_MIN, axisInnerNodeSize, L_INFINITY, CONTRIBUTION_MAXIMUM);
                        }
                        else {
                            distributeItemSpaceToBaseSize(isFlex, space, axisTracks, item.trackRangeStart(axis), item.trackRangeEnd(axis), P_AUTO_MIN,
                                axisInnerNodeSize, L_FIT_CONTENT_LIMITED_GROWTH_LIMIT, CONTRIBUTION_MAXIMUM);
                        }
                    }
                }
                flushPlannedBaseSizeIncreases(axisTracks);
            }

            // In all cases, continue to increase the base size of tracks with a min track sizing function of max-content by distributing
            // extra space as needed to account for these items' max-content contributions.
            for (b in batchStart...batchEnd) {
                final item = items[b];
                if (!spansTrackMatching(item, axis, axisTracks, P_MAX_CONTENT_MIN, axisInnerNodeSize))
                    continue;
                final axisMaxContentSize = itemSizer.maxContentContribution(item, axisTracks);
                final space = axisMaxContentSize;
                if (space > 0.0) {
                    distributeItemSpaceToBaseSize(isFlex, space, axisTracks, item.trackRangeStart(axis), item.trackRangeEnd(axis), P_MAX_CONTENT_MIN,
                        axisInnerNodeSize, L_GROWTH_LIMIT, CONTRIBUTION_MAXIMUM);
                }
            }
            flushPlannedBaseSizeIncreases(axisTracks);

            // 4. If at this point any track's growth limit is now less than its base size, increase its growth limit to match its base size.
            for (track in axisTracks) {
                if (track.growthLimit < track.baseSize)
                    track.growthLimit = track.baseSize;
            }

            // If a track is a flexible track, then it has flexible max track sizing function
            // It cannot also have an intrinsic max track sizing function, so these steps do not apply.
            if (!isFlex) {
                // 5. For intrinsic maximums: Next increase the growth limit of tracks with an intrinsic max track sizing function by
                // distributing extra space as needed to account for these items' min-content contributions.
                for (b in batchStart...batchEnd) {
                    final item = items[b];
                    if (!spansTrackMatching(item, axis, axisTracks, P_INTRINSIC_MAX, axisInnerNodeSize))
                        continue;
                    final axisMinContentSize = itemSizer.minContentContribution(item, axisTracks);
                    final space = axisMinContentSize;
                    if (space > 0.0)
                        distributeItemSpaceToGrowthLimit(space, axisTracks, item.trackRangeStart(axis), item.trackRangeEnd(axis), P_INTRINSIC_MAX,
                            axisInnerNodeSize);
                }
                // Mark any tracks whose growth limit changed from infinite to finite in this step as infinitely growable for the next step.
                flushPlannedGrowthLimitIncreases(axisTracks, true);

                // 6. For max-content maximums: Lastly continue to increase the growth limit of tracks with a max track sizing function of max-content
                // by distributing extra space as needed to account for these items' max-content contributions. However, limit the growth of any
                // fit-content() tracks by their fit-content() argument.
                for (b in batchStart...batchEnd) {
                    final item = items[b];
                    if (!spansTrackMatching(item, axis, axisTracks, P_MAX_CONTENT_MAX, axisInnerNodeSize))
                        continue;
                    final axisMaxContentSize = itemSizer.maxContentContribution(item, axisTracks);
                    final space = axisMaxContentSize;
                    if (space > 0.0)
                        distributeItemSpaceToGrowthLimit(space, axisTracks, item.trackRangeStart(axis), item.trackRangeEnd(axis), P_MAX_CONTENT_MAX,
                            axisInnerNodeSize);
                }
                // Mark any tracks whose growth limit changed from infinite to finite in this step as infinitely growable for the next step.
                flushPlannedGrowthLimitIncreases(axisTracks, false);
            }
        }

        // Step 5. If any track still has an infinite growth limit (because, for example, it had no items placed
        // in it or it is a flexible track), set its growth limit to its base size.
        // NOTE: this step is super-important to ensure that the "Maximise Tracks" step doesn't affect flexible tracks
        for (track in axisTracks) {
            if (track.growthLimit == Math.POSITIVE_INFINITY)
                track.growthLimit = track.baseSize;
        }
    }

    /** The sum of the base sizes of the inflexible tracks in the range */
    static inline function inflexibleBaseSizes(tracks:Array<GridTrack>, start:Int, end:Int):Float {
        var sum = 0.0;
        for (i in start...end) {
            final track = tracks[i];
            if (!track.isFlexible())
                sum += track.baseSize;
        }
        return sum;
    }

    /** The sum of the flex factors of the flexible tracks in an item's spanned track range */
    static inline function crossedFlexFactorSum(tracks:Array<GridTrack>, start:Int, end:Int):Float {
        var sum = 0.0;
        for (i in start...end) {
            final track = tracks[i];
            if (track.isFlexible())
                sum += track.flexFactor();
        }
        return sum;
    }

    /**
     * 11.5.1. Distributing Extra Space Across Spanned Tracks
     * https://www.w3.org/TR/css-grid-1/#extra-space
     */
    static function distributeItemSpaceToBaseSize(isFlex:Bool, space:Float, tracks:Array<GridTrack>, start:Int, end:Int, predicate:Int,
            axisInnerNodeSize:Null<Float>, limit:Int, intrinsicContributionType:Int):Void {
        if (isFlex) {
            final filter = predicate | F_FLEXIBLE;

            // If the sum of the flex factors of the affected tracks is greater than zero, distribute
            // space according to the ratios of the tracks' flex factors. Otherwise distribute space equally.
            //
            // Note: the spec says to compute the sum over all flexible tracks spanned by the item, and to
            // blend flex-factor-proportional and equal distribution when the sum is below one. But Chrome
            // computes the sum over only the affected tracks and uses pure flex-factor ratios whenever
            // that sum is non-zero, so we do the same for compatibility.
            var flexFactorSum = 0.0;
            for (i in start...end) {
                final track = tracks[i];
                if (trackMatches(track, filter, axisInnerNodeSize))
                    flexFactorSum += track.flexFactor();
            }
            distributeItemSpaceToBaseSizeInner(space, tracks, start, end, filter, axisInnerNodeSize, flexFactorSum > 0.0, limit,
                intrinsicContributionType);
        }
        else {
            distributeItemSpaceToBaseSizeInner(space, tracks, start, end, predicate, axisInnerNodeSize, false, limit, intrinsicContributionType);
        }
    }

    /**
     * Inner function that doesn't account for differences due to distributing to flex items
     * This difference is handled by the filter passed in above
     */
    static function distributeItemSpaceToBaseSizeInner(space:Float, tracks:Array<GridTrack>, start:Int, end:Int, filter:Int,
            axisInnerNodeSize:Null<Float>, useFlexFactor:Bool, limit:Int, intrinsicContributionType:Int):Void {
        // Skip this distribution if there is either
        //   - no space to distribute
        //   - no affected tracks to distribute space to
        if (space == 0.0)
            return;
        var anyAffected = false;
        for (i in start...end) {
            if (trackMatches(tracks[i], filter, axisInnerNodeSize)) {
                anyAffected = true;
                break;
            }
        }
        if (!anyAffected)
            return;

        // 1. Find the space to distribute
        var trackSizes = 0.0;
        for (i in start...end)
            trackSizes += tracks[i].baseSize;
        var extraSpace = Sys.f32Max(0.0, space - trackSizes);

        // 2. Distribute space up to limits:
        // Note: there are two exit conditions to this loop:
        //   - We run out of space to distribute (extra_space falls below THRESHOLD)
        //   - We run out of growable tracks to distribute to

        // Define a small constant to avoid infinite loops due to rounding errors. Rather than stopping distributing
        // extra space when it gets to exactly zero, we will stop when it falls below this amount
        final THRESHOLD = 0.000001;

        extraSpace = distributeSpaceUpToLimits(extraSpace, tracks, start, end, filter, axisInnerNodeSize, useFlexFactor, A_BASE_SIZE, limit);

        // 3. Distribute remaining span beyond limits (if any)
        if (extraSpace > THRESHOLD) {
            // When accommodating minimum contributions or accommodating min-content contributions:
            //   - any affected track that happens to also have an intrinsic max track sizing function;
            // When accommodating max-content contributions:
            //   - any affected track that happens to also have a max-content max track sizing function
            var beyondFilter = filter | (intrinsicContributionType == CONTRIBUTION_MINIMUM ? F_MAX_INTRINSIC : F_MAX_OR_FIT_CONTENT);

            // If there are no such tracks (matching filter above), then use all affected tracks.
            var numberOfTracks = 0;
            for (i in start...end) {
                if (trackMatches(tracks[i], beyondFilter, axisInnerNodeSize))
                    numberOfTracks++;
            }
            if (numberOfTracks == 0)
                beyondFilter = filter;

            // When distributing beyond limits, growth limits are ignored, but the argument
            // to any fit-content() max track sizing function still caps growth.
            distributeSpaceUpToLimits(extraSpace, tracks, start, end, beyondFilter, axisInnerNodeSize, useFlexFactor, A_BASE_SIZE, L_FIT_CONTENT_LIMIT);
        }

        // 4. For each affected track, if the track's item-incurred increase is larger than the track's planned increase
        // set the track's planned increase to that value.
        for (i in start...end) {
            final track = tracks[i];
            if (track.itemIncurredIncrease > track.baseSizePlannedIncrease)
                track.baseSizePlannedIncrease = track.itemIncurredIncrease;

            // Reset the item_incurresed increase ready for the next space distribution
            track.itemIncurredIncrease = 0.0;
        }
    }

    /**
     * 11.5.1. Distributing Extra Space Across Spanned Tracks
     * This is simplified (and faster) version of the algorithm for growth limits
     * https://www.w3.org/TR/css-grid-1/#extra-space
     */
    static function distributeItemSpaceToGrowthLimit(space:Float, tracks:Array<GridTrack>, start:Int, end:Int, filter:Int,
            axisInnerNodeSize:Null<Float>):Void {
        // Skip this distribution if there is either
        //   - no space to distribute
        //   - no affected tracks to distribute space to
        if (space == 0.0)
            return;
        var anyAffected = false;
        for (i in start...end) {
            if (trackMatches(tracks[i], filter, axisInnerNodeSize)) {
                anyAffected = true;
                break;
            }
        }
        if (!anyAffected)
            return;

        // 1. Find the space to distribute
        var trackSizes = 0.0;
        for (i in start...end) {
            final track = tracks[i];
            trackSizes += track.growthLimit == Math.POSITIVE_INFINITY ? track.baseSize : track.growthLimit;
        }
        var extraSpace = Sys.f32Max(0.0, space - trackSizes);

        // 2. Distribute space up to limits:
        // For growth limits the limit is the growth limit itself unless the track is marked infinitely growable (or its
        // growth limit is still infinite), in which case it is the track's fit-content() argument if it has one, or
        // infinity if it does not. As the affected size of a track that isn't growable is its growth limit, those
        // tracks won't receive any space in this step.
        extraSpace = distributeSpaceUpToLimits(extraSpace, tracks, start, end, filter | F_GROWABLE, axisInnerNodeSize, false, A_GROWTH_LIMIT_OR_BASE_SIZE,
            L_FIT_CONTENT_LIMIT);

        // 3. Distribute space beyond limits
        // If space remains after all tracks are frozen, unfreeze and continue to distribute space to the item-incurred increase
        // ...when handling any intrinsic growth limit: all affected tracks.
        if (extraSpace > 0.0)
            distributeSpaceUpToLimits(extraSpace, tracks, start, end, filter, axisInnerNodeSize, false, A_GROWTH_LIMIT_OR_BASE_SIZE, L_FIT_CONTENT_LIMIT);

        // 4. For each affected track, if the track's item-incurred increase is larger than the track's planned increase
        // set the track's planned increase to that value.
        for (i in start...end) {
            final track = tracks[i];
            if (track.itemIncurredIncrease > track.growthLimitPlannedIncrease)
                track.growthLimitPlannedIncrease = track.itemIncurredIncrease;

            // Reset the item_incurresed increase ready for the next space distribution
            track.itemIncurredIncrease = 0.0;
        }
    }

    /**
     * 11.6 Maximise Tracks
     * Distributes free space (if any) to tracks with FINITE growth limits, up to their limits.
     */
    static function maximiseTracks(axisTracks:Array<GridTrack>, axisAvailableGridSpace:AvailableSpace):Void {
        var usedSpace = 0.0;
        for (track in axisTracks)
            usedSpace += track.baseSize;
        final freeSpace = axisAvailableGridSpace.computeFreeSpace(usedSpace);
        if (freeSpace == Math.POSITIVE_INFINITY) {
            for (track in axisTracks)
                track.baseSize = track.growthLimit;
        }
        else if (freeSpace > 0.0) {
            distributeSpaceUpToLimits(freeSpace, axisTracks, 0, axisTracks.length, P_ALL, null, false, A_BASE_SIZE, L_FIT_CONTENT_LIMITED_GROWTH_LIMIT);
            for (track in axisTracks) {
                track.baseSize += track.itemIncurredIncrease;
                track.itemIncurredIncrease = 0.0;
            }
        }
    }

    /**
     * 11.7. Expand Flexible Tracks
     * This step sizes flexible tracks using the largest value it can assign to an fr without exceeding the available space.
     */
    static function expandFlexibleTracks(tree:LayoutPartialTree, axis:AbstractAxis, axisTracks:Array<GridTrack>, otherAxisTracks:Array<GridTrack>,
            items:Array<GridItem>, axisMinSize:Null<Float>, axisMaxSize:Null<Float>, axisAvailableSpaceForExpansion:AvailableSpace,
            innerNodeSize:SizeOf<Null<Float>>, getTrackSizeEstimate:Int):Void {
        final itemSizer = new IntrinsicSizeMeasurer(tree, otherAxisTracks, getTrackSizeEstimate, axis, innerNodeSize);

        // First, find the grid's used flex fraction:
        final flexFraction = switch axisAvailableSpaceForExpansion {
            // If the free space is zero:
            //    The used flex fraction is zero.
            // Otherwise, if the free space is a definite length:
            //   The used flex fraction is the result of finding the size of an fr using all of the grid tracks and
            //   a space to fill of the available grid space.
            case Definite(availableSpace):
                var usedSpace = 0.0;
                for (track in axisTracks)
                    usedSpace += track.baseSize;
                final freeSpace = availableSpace - usedSpace;
                if (freeSpace <= 0.0)
                    0.0;
                else
                    findSizeOfFr(axisTracks, 0, axisTracks.length, availableSpace);
            // If ... sizing the grid container under a min-content constraint the used flex fraction is zero.
            case MinContent:
                0.0;
            // Otherwise, if the free space is an indefinite length:
            case MaxContent:
                // The used flex fraction is the maximum of:
                // For each flexible track, if the flexible track's flex factor is greater than one,
                // the result of dividing the track's base size by its flex factor; otherwise, the track's base size.
                var trackFraction:Null<Float> = null;
                for (track in axisTracks) {
                    if (!track.maxTrackSizingFunction.isFr())
                        continue;
                    final flexFactor = track.flexFactor();
                    final value = flexFactor > 1.0 ? track.baseSize / flexFactor : track.baseSize;
                    if (trackFraction == null || value > (trackFraction : Float))
                        trackFraction = value;
                }
                // For each grid item that crosses a flexible track, the result of finding the size of an fr using all the grid tracks
                // that the item crosses and a space to fill of the item's max-content contribution.
                var itemFraction:Null<Float> = null;
                for (item in items) {
                    if (!item.crossesFlexibleTrack(axis))
                        continue;
                    final maxContentContribution = itemSizer.maxContentContribution(item, axisTracks);
                    final value = findSizeOfFr(axisTracks, item.trackRangeStart(axis), item.trackRangeEnd(axis), maxContentContribution);
                    if (itemFraction == null || value > (itemFraction : Float))
                        itemFraction = value;
                }
                final flexFraction = Sys.f32Max(trackFraction != null ? (trackFraction : Float) : 0.0, itemFraction != null ? (itemFraction : Float) : 0.0);

                // If using this flex fraction would cause the grid to be smaller than the grid container's min-width/height (or larger than the
                // grid container's max-width/height), then redo this step, treating the free space as definite and the available grid space as equal
                // to the grid container's inner size when it's sized to its min-width/height (max-width/height).
                // (Note: min_size takes precedence over max_size)
                var hypotheticalGridSize = 0.0;
                for (track in axisTracks) {
                    if (track.maxTrackSizingFunction.isFr()) {
                        final trackFlexFactor = track.maxTrackSizingFunction.value();
                        hypotheticalGridSize += Sys.f32Max(track.baseSize, trackFlexFactor * flexFraction);
                    }
                    else {
                        hypotheticalGridSize += track.baseSize;
                    }
                }
                final minSize = axisMinSize != null ? (axisMinSize : Float) : 0.0;
                final maxSize = axisMaxSize != null ? (axisMaxSize : Float) : Math.POSITIVE_INFINITY;
                if (hypotheticalGridSize < minSize)
                    findSizeOfFr(axisTracks, 0, axisTracks.length, minSize);
                else if (hypotheticalGridSize > maxSize)
                    findSizeOfFr(axisTracks, 0, axisTracks.length, maxSize);
                else
                    flexFraction;
        }

        // For each flexible track, if the product of the used flex fraction and the track's flex factor is greater
        // than the track's base size, set its base size to that product.
        for (track in axisTracks) {
            if (!track.maxTrackSizingFunction.isFr())
                continue;
            final trackFlexFactor = track.maxTrackSizingFunction.value();
            track.baseSize = Sys.f32Max(track.baseSize, trackFlexFactor * flexFraction);
        }
    }

    /**
     * 11.7.1. Find the Size of an fr
     * This algorithm finds the largest size that an fr unit can be without exceeding the target size.
     * It must be called with a set of grid tracks and some quantity of space to fill.
     */
    static function findSizeOfFr(tracks:Array<GridTrack>, start:Int, end:Int, spaceToFill:Float):Float {
        // Handle the trivial case where there is no space to fill
        // Do not remove as otherwise the loop below will loop infinitely
        if (spaceToFill == 0.0)
            return 0.0;

        // If the product of the hypothetical fr size (computed below) and any flexible track's flex factor
        // is less than the track's base size, then we must restart this algorithm treating all such tracks as inflexible.
        // We therefore wrap the entire algorithm in a loop, with an hypothetical_fr_size of INFINITY such that the above
        // condition can never be true for the first iteration.
        var hypotheticalFrSize = Math.POSITIVE_INFINITY;
        var previousIterHypotheticalFrSize = Math.POSITIVE_INFINITY;
        // Every restart of the algorithm treats at least one more flexible track as inflexible, so a valid
        // hypothetical fr size is always found within `tracks.len() + 1` iterations. Non-finite values (which
        // can arise from non-finite style inputs) break that invariant as comparisons against `NaN` are always
        // false, so we bound the iteration count to guarantee termination.
        final maxIterations = end - start + 1;
        for (_ in 0...maxIterations) {
            // Let leftover space be the space to fill minus the base sizes of the non-flexible grid tracks.
            // Let flex factor sum be the sum of the flex factors of the flexible tracks. If this value is less than 1, set it to 1 instead.
            // We compute both of these in a single loop to avoid iterating over the data twice
            var usedSpace = 0.0;
            var naiveFlexFactorSum = 0.0;
            for (i in start...end) {
                final track = tracks[i];
                // Tracks for which flex_factor * hypothetical_fr_size < track.base_size are treated as inflexible
                if (track.maxTrackSizingFunction.isFr() && track.maxTrackSizingFunction.value() * hypotheticalFrSize >= track.baseSize)
                    naiveFlexFactorSum += track.maxTrackSizingFunction.value();
                else
                    usedSpace += track.baseSize;
            }
            final leftoverSpace = spaceToFill - usedSpace;
            final flexFactor = Sys.f32Max(naiveFlexFactorSum, 1.0);

            // Let the hypothetical fr size be the leftover space divided by the flex factor sum.
            previousIterHypotheticalFrSize = hypotheticalFrSize;
            hypotheticalFrSize = leftoverSpace / flexFactor;

            // If the product of the hypothetical fr size and a flexible track's flex factor is less than the track's base size,
            // restart this algorithm treating all such tracks as inflexible.
            // We keep track of the hypothetical_fr_size
            var hypotheticalFrSizeIsValid = true;
            for (i in start...end) {
                final track = tracks[i];
                if (track.maxTrackSizingFunction.isFr()) {
                    final flexFactor = track.maxTrackSizingFunction.value();
                    if (!(flexFactor * hypotheticalFrSize >= track.baseSize || flexFactor * previousIterHypotheticalFrSize < track.baseSize)) {
                        hypotheticalFrSizeIsValid = false;
                        break;
                    }
                }
            }
            if (hypotheticalFrSizeIsValid)
                break;
        }

        // Return the hypothetical fr size.
        return hypotheticalFrSize;
    }

    /**
     * 11.8. Stretch auto Tracks
     * This step expands tracks that have an auto max track sizing function by dividing any remaining positive, definite free space equally amongst them.
     */
    static function stretchAutoTracks(axisTracks:Array<GridTrack>, axisMinSize:Null<Float>, axisAvailableSpaceForExpansion:AvailableSpace):Void {
        var numAutoTracks = 0;
        for (track in axisTracks) {
            if (track.maxTrackSizingFunction.isAuto())
                numAutoTracks++;
        }
        if (numAutoTracks > 0) {
            var usedSpace = 0.0;
            for (track in axisTracks)
                usedSpace += track.baseSize;

            // If the free space is indefinite, but the grid container has a definite min-width/height
            // use that size to calculate the free space for this step instead.
            final freeSpace = if (axisAvailableSpaceForExpansion.isDefinite()) {
                axisAvailableSpaceForExpansion.computeFreeSpace(usedSpace);
            }
            else {
                axisMinSize != null ? (axisMinSize : Float) - usedSpace : 0.0;
            }
            if (freeSpace > 0.0) {
                final extraSpacePerAutoTrack = freeSpace / numAutoTracks;
                for (track in axisTracks) {
                    if (track.maxTrackSizingFunction.isAuto())
                        track.baseSize += extraSpacePerAutoTrack;
                }
            }
        }
    }

    /**
     * Helper function for distributing space to tracks evenly
     * Used by both distributeItemSpaceToBaseSize and maximiseTracks steps
     */
    static function distributeSpaceUpToLimits(spaceToDistribute:Float, tracks:Array<GridTrack>, start:Int, end:Int, filter:Int,
            axisInnerNodeSize:Null<Float>, useFlexFactor:Bool, affectedProperty:Int, limit:Int):Float {
        // Define a small constant to avoid infinite loops due to rounding errors. Rather than stopping distributing
        // extra space when it gets to exactly zero, we will stop when it falls below this amount
        final THRESHOLD = 0.01;

        // Each iteration freezes at least one track at its limit, so the loop always completes within
        // `tracks.len() + 1` iterations. Non-finite values (which can arise from non-finite style inputs) can
        // prevent any space from being distributed, so we bound the iteration count to guarantee termination.
        final maxIterations = end - start + 1;

        var space = spaceToDistribute;
        for (_ in 0...maxIterations) {
            if (space <= THRESHOLD)
                break;

            var trackDistributionProportionSum = 0.0;
            var minIncreaseLimit:Null<Float> = null;
            for (i in start...end) {
                final track = tracks[i];
                final trackLimitValue = trackLimit(track, limit);
                final property = trackAffectedProperty(track, affectedProperty);
                if (!(property + track.itemIncurredIncrease < trackLimitValue))
                    continue;
                if (!trackMatches(track, filter, axisInnerNodeSize))
                    continue;
                final proportion = trackDistributionProportion(track, useFlexFactor);
                trackDistributionProportionSum += proportion;
                // Compute item-incurred increase for this iteration
                final increaseLimit = (trackLimitValue - property - track.itemIncurredIncrease) / proportion;
                if (minIncreaseLimit == null || increaseLimit < (minIncreaseLimit : Float))
                    minIncreaseLimit = increaseLimit;
            }

            if (trackDistributionProportionSum == 0.0)
                break;

            final iterationItemIncurredIncrease = Sys.f32Min(minIncreaseLimit, space / trackDistributionProportionSum);

            for (i in start...end) {
                final track = tracks[i];
                if (!trackMatches(track, filter, axisInnerNodeSize))
                    continue;
                final increase = iterationItemIncurredIncrease * trackDistributionProportion(track, useFlexFactor);
                if (increase > 0.0
                    && trackAffectedProperty(track, affectedProperty) + track.itemIncurredIncrease + increase <= trackLimit(track, limit) + THRESHOLD) {
                    track.itemIncurredIncrease += increase;
                    space -= increase;
                }
            }
        }

        return space;
    }

}
