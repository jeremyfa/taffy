// Ported from taffy 0.15.0: src/compute/grid/alignment.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.grid;

import taffy.compute.common.Alignment;
import taffy.compute.common.ScrollableOverflow;
import taffy.compute.common.SizingKeyword;
import taffy.geometry.AbsoluteAxis;
import taffy.geometry.Line;
import taffy.geometry.LineOf;
import taffy.geometry.Point;
import taffy.geometry.Rect;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.AlignContent;
import taffy.style.AlignItems;
import taffy.style.AlignItemsKeyword;
import taffy.style.AvailableSpace;
import taffy.style.Direction;
import taffy.style.Position;
import taffy.tree.Layout;
import taffy.tree.LayoutGridContainer;
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
 * The result of `GridAlignment.alignAndPositionItem`
 */
class ItemPositionResult {

    /** The item's contribution to the container's scrollable overflow */
    public final overflowContribution:Rect;

    /** The item's final y position */
    public final yPosition:Float;

    /** The item's final height */
    public final height:Float;

    public inline function new(overflowContribution:Rect, yPosition:Float, height:Float) {
        this.overflowContribution = overflowContribution;
        this.yPosition = yPosition;
        this.height = height;
    }

}

/**
 * Alignment of tracks and final positioning of items
 */
class GridAlignment {

    static final FALSE_LINE:LineOf<Bool> = new LineOf<Bool>(false, false);

    /**
     * Align the grid tracks within the grid according to the align-content (rows) or
     * justify-content (columns) property. This only does anything if the size of the
     * grid is not equal to the size of the grid container in the axis being aligned.
     */
    public static function alignTracks(gridContainerContentBoxSize:Float, padding:Line, border:Line, tracks:Array<GridTrack>,
            trackAlignmentStyle:AlignContent, axisIsReversed:Bool):Void {
        var usedSize = 0.0;
        for (track in tracks)
            usedSize += track.baseSize;
        final freeSpace = gridContainerContentBoxSize - usedSize;
        final origin = padding.start + border.start;

        // Count the number of non-collapsed tracks (not counting gutters)
        var numTracks = 0;
        var i = 1;
        while (i < tracks.length) {
            if (!tracks[i].isCollapsed)
                numTracks++;
            i += 2;
        }

        // Grid layout treats gaps as full tracks rather than applying them at alignment so we
        // simply pass zero here. Grid layout is never reversed.
        final gap = 0.0;
        final layoutIsReversed = false;
        var trackAlignment = Alignment.applyAlignmentFallback(freeSpace, numTracks, trackAlignmentStyle);
        if (axisIsReversed)
            trackAlignment = trackAlignment.reversed();

        // If every track is collapsed then no track receives the alignment offset below, but the
        // grid's lines should still be aligned within the container (e.g. at the inline-start edge
        // for RTL), so apply the offset to the origin instead.
        final emptyGridOffset = numTracks == 0 ? Alignment.computeAlignmentOffset(freeSpace, numTracks, gap, trackAlignment, layoutIsReversed,
            true) : 0.0;

        // Compute offsets. Tracks are stored in logical order; when the axis is reversed (RTL)
        // physical offsets are assigned right-to-left by iterating the tracks in reverse.
        var totalOffset = origin + emptyGridOffset;
        var seenNonCollapsedTrack = false;
        final len = tracks.length;
        for (n in 0...len) {
            final track = tracks[axisIsReversed ? len - 1 - n : n];
            // Odd tracks are gutters (but slices are zero-indexed, so odd tracks have even indices)
            final isGutter = n % 2 == 0;
            final isNonCollapsedTrack = !isGutter && !track.isCollapsed;

            // Alignment offsets should be applied only to non-collapsed tracks.
            final isFirst = isNonCollapsedTrack && !seenNonCollapsedTrack;

            final offset = isNonCollapsedTrack ? Alignment.computeAlignmentOffset(freeSpace, numTracks, gap, trackAlignment, layoutIsReversed,
                isFirst) : 0.0;

            track.offset = totalOffset + offset;
            totalOffset = totalOffset + offset + track.baseSize;
            if (isNonCollapsedTrack)
                seenNonCollapsedTrack = true;
        }
    }

    /** Align and size a grid item into it's final position */
    public static function alignAndPositionItem(tree:LayoutGridContainer, node:NodeId, order:Int, gridArea:Rect,
            // Percentage basis for the item's styles. Grid passes the grid area size.
            containingBlockSize:Size, containerJustifyItems:AlignItems, containerAlignItems:AlignItems, baselineShim:Float, direction:Direction,
            containerBorderBoxWidth:Float, containerBorder:Rect, containerIsScrollContainer:Bool, bubbledCandidates:OofCandidates):ItemPositionResult {
        final style = tree.getGridChildStyle(node);

        final overflow = style.overflow;
        final contain = style.contain;
        final scrollbarWidth = style.scrollbarWidth;
        final aspectRatio = style.aspectRatio;
        final isReplaced = style.isReplaced();
        // Fall back to the container's justify-items/align-items if unset (null), and then resolve
        // writing-mode-relative self-start/self-end keywords against the item's own direction.
        // The horizontal axis is the inline axis (Taffy only supports horizontal-tb); the vertical
        // (block) axis resolves them to plain start/end.
        final itemDirection = style.direction;
        final justifySelf = (style.justifySelf != null ? (style.justifySelf : AlignItems) : containerJustifyItems).resolveSelfRelative(itemDirection,
            direction, true);
        final alignSelf = (style.alignSelf != null ? (style.alignSelf : AlignItems) : containerAlignItems).resolveSelfRelative(itemDirection,
            direction, false);

        final position = style.position;
        final insetHorizontalStart = style.inset.left.resolveToOption(containingBlockSize.width);
        final insetHorizontalEnd = style.inset.right.resolveToOption(containingBlockSize.width);
        final insetVerticalStart = style.inset.top.resolveToOption(containingBlockSize.height);
        final insetVerticalEnd = style.inset.bottom.resolveToOption(containingBlockSize.height);
        final padding = style.padding.resolveOrZero(OptionalFloat.some(containingBlockSize.width));
        final border = style.border.resolveOrZero(OptionalFloat.some(containingBlockSize.width));
        final paddingBorderSize = padding.add(border).sumAxes();

        final boxSizingAdjustment = style.boxSizing == ContentBox ? paddingBorderSize : Size.ZERO;

        final containingBlockOptions = containingBlockSize.toOptions();
        final sizeStyle = style.size;
        final inherentSize = sizeStyle.maybeResolve(containingBlockOptions).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);
        final minSize = style.minSize.maybeResolve(containingBlockOptions)
            .maybeAddSize(boxSizingAdjustment)
            .or(paddingBorderSize.toOptions())
            .maybeMaxSize(paddingBorderSize)
            .maybeApplyAspectRatio(aspectRatio);
        final maxSize = style.maxSize.maybeResolve(containingBlockOptions).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);

        // Resolve `normal` alignment (the default if alignment is set on neither the parent or the node itself)
        // Note: if the child has a preferred aspect ratio but neither width or height are set, then the width is stretched
        // and the then height is calculated from the width according the aspect ratio
        // Replaced elements are not stretched: they are sized as for `start`.
        // See: https://www.w3.org/TR/css-grid-1/#grid-item-sizing
        final horizontalAlignment = switch justifySelf.keyword {
            case Normal:
                (inherentSize.width.isSome() || sizeStyle.width.isSizingKeyword() || isReplaced) ? AlignItems.START : AlignItems.STRETCH;
            case _:
                justifySelf;
        }
        final verticalAlignment = switch alignSelf.keyword {
            case Normal:
                (inherentSize.height.isSome() || sizeStyle.height.isSizingKeyword() || aspectRatio.isSome() || isReplaced) ? AlignItems.START : AlignItems.STRETCH;
            case _:
                alignSelf;
        }

        // Note: This is not a bug. It is part of the CSS spec that both horizontal and vertical margins
        // resolve against the WIDTH of the grid area.
        final marginLeft = style.margin.left.resolveToOption(containingBlockSize.width);
        final marginRight = style.margin.right.resolveToOption(containingBlockSize.width);
        final marginTop = style.margin.top.resolveToOption(containingBlockSize.width);
        final marginBottom = style.margin.bottom.resolveToOption(containingBlockSize.width);

        final gridAreaWidth = gridArea.right - gridArea.left;
        final gridAreaHeight = gridArea.bottom - gridArea.top;
        final gridAreaMinusItemMarginsSize = new Size(
            Sys.f32Max(MaybeMath.maybeSubF(MaybeMath.maybeSubF(gridAreaWidth, marginLeft), marginRight), 0.0),
            Sys.f32Max(MaybeMath.maybeSubF(MaybeMath.maybeSubF(gridAreaHeight, marginTop), marginBottom) - baselineShim, 0.0)
        );

        // A size that is a sizing keyword (min-content, max-content, fit-content,
        // fit-content(...), stretch) either resolves to an exact size or is resolved
        // by measuring the item under the corresponding available space constraint
        final keywordWidth = inherentSize.width.isNone() ? SizingKeyword.resolveSizingKeyword(sizeStyle.width, OptionalFloat.some(gridAreaMinusItemMarginsSize.width),
            OptionalFloat.some(containingBlockSize.width)) : null;
        final keywordHeight = inherentSize.height.isNone() ? SizingKeyword.resolveSizingKeyword(sizeStyle.height, OptionalFloat.some(gridAreaMinusItemMarginsSize.height),
            OptionalFloat.some(containingBlockSize.height)) : null;

        // If both axes need to be measured then resolve them with a single measure call
        var keywordMeasuredWidth:OptionalFloat = OptionalFloat.NONE;
        var keywordMeasuredHeight:OptionalFloat = OptionalFloat.NONE;
        if (keywordWidth != null && keywordHeight != null && !position.isOutOfFlow()) {
            switch [keywordWidth, keywordHeight] {
                case [Measure(availableWidth), Measure(availableHeight)]:
                    final measured = LayoutPartialTreeExt.measureChildSizeBoth(tree, node, SizeOpt.NONE, containingBlockOptions,
                        new SizeAvail(availableWidth, availableHeight), InherentSize, FALSE_LINE);
                    keywordMeasuredWidth = OptionalFloat.some(measured.width);
                    keywordMeasuredHeight = OptionalFloat.some(measured.height);
                case _:
            }
        }

        // If node is absolutely positioned and width is not set explicitly, then deduce it
        // from left, right and container_content_box if both are set.
        var width:OptionalFloat = inherentSize.width;
        if (width.isNone()) {
            // Apply width derived from both the left and right properties of an absolutely
            // positioned element being set
            if (position.isOutOfFlow() && insetHorizontalStart.isSome() && insetHorizontalEnd.isSome()) {
                width = OptionalFloat.some(Sys.f32Max(gridAreaMinusItemMarginsSize.width - insetHorizontalStart.unwrap() - insetHorizontalEnd.unwrap(), 0.0));
            }
            else if (keywordWidth != null) {
                width = switch keywordWidth {
                    case Exact(w): OptionalFloat.some(w);
                    case Measure(availableWidth):
                        keywordMeasuredWidth.isSome() ? keywordMeasuredWidth : OptionalFloat.some(LayoutPartialTreeExt.measureChildSize(tree, node, SizeOpt.NONE,
                            containingBlockOptions, new SizeAvail(availableWidth, Definite(gridAreaMinusItemMarginsSize.height)),
                            InherentSize, Horizontal, FALSE_LINE));
                }
            }
            // Apply width based on stretch alignment if:
            //  - Alignment style is "stretch"
            //  - The node is not absolutely positioned
            //  - The node does not have auto margins in this axis.
            else if (marginLeft.isSome() && marginRight.isSome() && horizontalAlignment == AlignItems.STRETCH && !position.isOutOfFlow()) {
                width = OptionalFloat.some(gridAreaMinusItemMarginsSize.width);
            }
        }

        // Reapply aspect ratio after stretch and absolute position width adjustments
        final s1 = new SizeOpt(width, inherentSize.height).maybeApplyAspectRatio(aspectRatio);
        width = s1.width;
        var height:OptionalFloat = s1.height;

        if (height.isNone()) {
            if (position.isOutOfFlow() && insetVerticalStart.isSome() && insetVerticalEnd.isSome()) {
                height = OptionalFloat.some(Sys.f32Max(gridAreaMinusItemMarginsSize.height - insetVerticalStart.unwrap() - insetVerticalEnd.unwrap(), 0.0));
            }
            else if (keywordHeight != null) {
                height = switch keywordHeight {
                    case Exact(h): OptionalFloat.some(h);
                    case Measure(availableHeight):
                        keywordMeasuredHeight.isSome() ? keywordMeasuredHeight : OptionalFloat.some(LayoutPartialTreeExt.measureChildSize(tree, node,
                            new SizeOpt(width, OptionalFloat.NONE), containingBlockOptions,
                            new SizeAvail(width.isSome() ? Definite(width.unwrap()) : Definite(gridAreaMinusItemMarginsSize.width), availableHeight),
                            InherentSize, Vertical, FALSE_LINE));
                }
            }
            // Apply height based on stretch alignment if:
            //  - Alignment style is "stretch"
            //  - The node is not absolutely positioned
            //  - The node does not have auto margins in this axis.
            else if (marginTop.isSome() && marginBottom.isSome() && verticalAlignment == AlignItems.STRETCH && !position.isOutOfFlow()) {
                height = OptionalFloat.some(gridAreaMinusItemMarginsSize.height);
            }
        }
        // Reapply aspect ratio after stretch and absolute position height adjustments
        // Clamp size by min and max width/height
        final clamped = new SizeOpt(width, height).maybeApplyAspectRatio(aspectRatio).maybeClamp(minSize, maxSize);

        // Layout node
        final availableSpace = new SizeAvail(Definite(gridAreaMinusItemMarginsSize.width), Definite(gridAreaMinusItemMarginsSize.height));
        final size = if (position.isOutOfFlow() && (clamped.width.isNone() || clamped.height.isNone())) {
            LayoutPartialTreeExt.measureChildSizeBoth(tree, node, clamped, containingBlockOptions, availableSpace, InherentSize, FALSE_LINE).toOptions();
        }
        else {
            clamped;
        }

        final layoutOutput = LayoutPartialTreeExt.performChildLayout(tree, node, size, containingBlockOptions, availableSpace, InherentSize, FALSE_LINE);

        // Resolve final size
        final finalSize = size.unwrapOr(layoutOutput.size).maybeClamp(minSize, maxSize);
        final finalWidth = finalSize.width;
        final finalHeight = finalSize.height;

        final x = alignItemWithinArea(gridArea.left, gridArea.right, horizontalAlignment, finalWidth, position, insetHorizontalStart,
            insetHorizontalEnd, marginLeft, marginRight, 0.0, direction);
        final xMarginStart = resultMarginStart;
        final xMarginEnd = resultMarginEnd;
        final y = alignItemWithinArea(gridArea.top, gridArea.bottom, verticalAlignment, finalHeight, position, insetVerticalStart, insetVerticalEnd,
            marginTop, marginBottom, baselineShim, Ltr);
        final yMarginStart = resultMarginStart;
        final yMarginEnd = resultMarginEnd;

        final scrollbarSize = new Size(overflow.y == Scroll ? scrollbarWidth : 0.0, overflow.x == Scroll ? scrollbarWidth : 0.0);

        final resolvedMargin = new Rect(xMarginStart, xMarginEnd, yMarginStart, yMarginEnd);

        // Bubble out-of-flow candidates from the item's subtree, translating anchors from
        // item-relative to container-relative coordinates
        final itemCandidates = layoutOutput.oofCandidates.take();
        if (!itemCandidates.isEmpty()) {
            itemCandidates.translate(new Point(x, y));
            bubbledCandidates.append(itemCandidates);
        }

        tree.setUnroundedLayout(node, new Layout(order, new Point(x, y), new Size(finalWidth, finalHeight), layoutOutput.scrollableOverflowRect,
            scrollbarSize, border, padding, resolvedMargin));

        // Contributions to the container's scrollable overflow rect are measured from the
        // container's padding-box origin (mirrored for RTL), matching the scrollable overflow region.
        final isRtlLocation = direction.isRtl();
        final contributionLocation = new Point(isRtlLocation ? containerBorderBoxWidth - (x + finalWidth) - containerBorder.right : x - containerBorder.left, y - containerBorder.top);
        final scratchContribution = ScrollableOverflow.computeScrollableOverflowContribution(contributionLocation, new Size(finalWidth, finalHeight),
            layoutOutput.scrollableOverflowRect, overflow, contain, containerIsScrollContainer);
        // Kept in the result: a copy of the scratch rect
        final contribution = new Rect(scratchContribution.left, scratchContribution.right, scratchContribution.top, scratchContribution.bottom);

        return new ItemPositionResult(contribution, y, finalHeight);
    }

    /** The resolved start margin of the last `alignItemWithinArea` call (avoids allocating a tuple) */
    static var resultMarginStart:Float = 0.0;

    /** The resolved end margin of the last `alignItemWithinArea` call (avoids allocating a tuple) */
    static var resultMarginEnd:Float = 0.0;

    /**
     * Align and size a grid item along a single axis.
     * Returns the start position. The resolved margins are stored in `resultMarginStart` / `resultMarginEnd`.
     */
    public static function alignItemWithinArea(gridAreaStart:Float, gridAreaEnd:Float, alignmentStyle:AlignItems, resolvedSize:Float,
            position:Position, insetStart:OptionalFloat, insetEnd:OptionalFloat, marginStart:OptionalFloat, marginEnd:OptionalFloat, baselineShim:Float,
            direction:Direction):Float {
        // Calculate grid area dimension in the axis
        final nonAutoMarginStart = (marginStart.isSome() ? marginStart.unwrap() : 0.0) + baselineShim;
        final nonAutoMarginEnd = marginEnd.isSome() ? marginEnd.unwrap() : 0.0;
        final nonAutoMarginSum = nonAutoMarginStart + nonAutoMarginEnd;
        final gridAreaSize = Sys.f32Max(gridAreaEnd - gridAreaStart, 0.0);
        final freeSpace = Sys.f32Max(gridAreaSize - resolvedSize - nonAutoMarginSum, 0.0);

        // Expand auto margins to fill available space
        final autoMarginCount = (marginStart.isNone() ? 1 : 0) + (marginEnd.isNone() ? 1 : 0);
        final autoMarginSize = autoMarginCount > 0 ? freeSpace / autoMarginCount : 0.0;
        final resolvedMarginStart = (marginStart.isSome() ? marginStart.unwrap() : autoMarginSize) + baselineShim;
        final resolvedMarginEnd = marginEnd.isSome() ? marginEnd.unwrap() : autoMarginSize;

        final overflows = resolvedSize + nonAutoMarginSum > gridAreaSize;
        final alignmentKeyword = Alignment.resolveSelfAlignmentSafety(alignmentStyle, overflows);

        // Compute offset in the axis
        final alignmentBasedOffset = switch alignmentKeyword {
            // TODO: Add support for baseline alignment. For now we treat it as "start".
            case Start | FlexStart | Baseline | Stretch:
                direction.isRtl() ? gridAreaSize - resolvedSize - resolvedMarginEnd : resolvedMarginStart;
            case End | FlexEnd:
                direction.isRtl() ? resolvedMarginStart : gridAreaSize - resolvedSize - resolvedMarginEnd;
            case Center:
                (gridAreaSize - resolvedSize + resolvedMarginStart - resolvedMarginEnd) / 2.0;
            // Normal is resolved, and SelfStart/SelfEnd are resolved to Start/End against
            // the item's own direction, in `alignAndPositionItem`.
            case Normal | SelfStart | SelfEnd:
                throw "unreachable";
        }

        final offsetWithinArea = if (position.isOutOfFlow()) {
            if (insetStart.isSome() && insetEnd.isSome()) {
                direction.isRtl() ? gridAreaSize - insetEnd.unwrap() - resolvedSize - nonAutoMarginEnd : insetStart.unwrap() + nonAutoMarginStart;
            }
            else if (insetStart.isSome()) {
                insetStart.unwrap() + nonAutoMarginStart;
            }
            else if (insetEnd.isSome()) {
                gridAreaSize - insetEnd.unwrap() - resolvedSize - nonAutoMarginEnd;
            }
            else {
                alignmentBasedOffset;
            }
        }
        else {
            alignmentBasedOffset;
        }

        var start = gridAreaStart + offsetWithinArea;
        if (position == Relative) {
            final relativeInset:OptionalFloat = if (direction.isRtl()) {
                insetEnd.isSome() ? OptionalFloat.some(-insetEnd.unwrap()) : insetStart;
            }
            else {
                insetStart.isSome() ? insetStart : (insetEnd.isSome() ? OptionalFloat.some(-insetEnd.unwrap()) : OptionalFloat.NONE);
            }
            start += relativeInset.isSome() ? relativeInset.unwrap() : 0.0;
        }

        resultMarginStart = resolvedMarginStart;
        resultMarginEnd = resolvedMarginEnd;
        return start;
    }

}
