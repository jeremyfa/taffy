// Ported from taffy 0.15.0: src/compute/oof.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute;

import taffy.compute.common.ScrollableOverflow;
import taffy.compute.common.SizingKeyword;
import taffy.geometry.Line;
import taffy.geometry.LineOf;
import taffy.geometry.Point;
import taffy.geometry.PointOf;
import taffy.geometry.Rect;
import taffy.geometry.RectOf;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.AlignItems;
import taffy.style.AlignItemsKeyword;
import taffy.style.AlignmentSafety;
import taffy.style.AvailableSpace;
import taffy.style.BoxSizing;
import taffy.style.Contain;
import taffy.style.ContainingBlockClaims;
import taffy.style.Direction;
import taffy.style.Overflow;
import taffy.tree.AxisStaticEdge;
import taffy.tree.AxisStaticPosition;
import taffy.tree.DetailedLayoutInfo;
import taffy.tree.Layout;
import taffy.tree.LayoutContainingBlock;
import taffy.tree.LayoutInput;
import taffy.tree.LayoutOutput;
import taffy.tree.NodeId;
import taffy.tree.OofCandidate;
import taffy.tree.OofCandidates;
import taffy.tree.OofPositioningArea;
import taffy.util.Sys;
import taffy.geometry.RectOpt;
import taffy.util.OptionalFloat;
import taffy.geometry.SizeAvail;
import taffy.style.AvailableSpace.Definite;

using taffy.geometry.SizeOf;
using taffy.tree.LayoutPartialTree;
using taffy.util.MaybeMath;
using taffy.util.Resolve;

/**
 * The self-alignment of an out-of-flow box in one axis, resolved relative to the writing mode
 * of its containing block (`Start` is the logical start edge of the containing block).
 */
enum abstract OofAlignment(Int) {

    /** `normal` (or `auto`): stretch-fit sizing for non-replaced, non-table boxes; start alignment */
    var Normal = 0;

    /** `stretch`: stretch-fit sizing; start alignment */
    var Stretch = 1;

    /** Aligned to the logical start edge */
    var Start = 2;

    /** Centered */
    var Center = 3;

    /** Aligned to the logical end edge */
    var End = 4;

    /** Convert an `align-self`/`justify-self` value (with `self-start`/`self-end` already resolved) */
    public static function fromResolved(alignment:AlignItems):OofAlignment {
        return switch alignment.keyword {
            case AlignItemsKeyword.Normal: Normal;
            case AlignItemsKeyword.Stretch: Stretch;
            case AlignItemsKeyword.Center: Center;
            case AlignItemsKeyword.End | AlignItemsKeyword.FlexEnd | AlignItemsKeyword.SelfEnd: End;
            // The fallback alignment of `baseline` is `start`
            case AlignItemsKeyword.Start | AlignItemsKeyword.FlexStart | AlignItemsKeyword.SelfStart | AlignItemsKeyword.Baseline: Start;
        }
    }

    /** The physical edge the box's margin box is aligned to. `Normal` and `Stretch` behave as `Start`. */
    public function physicalEdge(reversed:Bool):AxisStaticEdge {
        final self:OofAlignment = cast this;
        if (self == Center)
            return AxisStaticEdge.Center;
        if (self == End)
            return reversed ? AxisStaticEdge.Start : AxisStaticEdge.End;
        return reversed ? AxisStaticEdge.End : AxisStaticEdge.Start;
    }

}

/**
 * The inputs to the absolute positioning layout model in a single axis. All coordinates
 * are physical and relative to the start of the containing block's inset-resolution area.
 */
class OofAxis {

    /** The size of the containing block in this axis */
    public final cbSize:Float;
    /** The box's resolved inset start (null = auto) */
    public final insetStart:OptionalFloat;
    /** The box's resolved inset end (null = auto) */
    public final insetEnd:OptionalFloat;
    /** The box's resolved margin start (null = auto) */
    public final marginStart:OptionalFloat;
    /** The box's resolved margin end (null = auto) */
    public final marginEnd:OptionalFloat;
    /** The box's static position (relative to the containing block's inset-resolution area) */
    public final staticPosition:AxisStaticPosition;
    /** The box's self-alignment in this axis */
    public final alignment:OofAlignment;
    /** The overflow-position modifier of the box's self-alignment in this axis */
    public final safety:AlignmentSafety;
    /** Whether this is the inline axis of the containing block */
    public final isInline:Bool;
    /** Whether the logical start edge of the containing block is the physical end edge of this axis */
    public final reversed:Bool;
    /** Whether the containing block is a scroll container which scrolls in this axis */
    public final isScrollAxis:Bool;

    public function new(cbSize:Float, insetStart:OptionalFloat, insetEnd:OptionalFloat, marginStart:OptionalFloat, marginEnd:OptionalFloat, staticPosition:AxisStaticPosition, alignment:OofAlignment, safety:AlignmentSafety, isInline:Bool, reversed:Bool, isScrollAxis:Bool) {
        this.cbSize = cbSize;
        this.insetStart = insetStart;
        this.insetEnd = insetEnd;
        this.marginStart = marginStart;
        this.marginEnd = marginEnd;
        this.staticPosition = staticPosition;
        this.alignment = alignment;
        this.safety = safety;
        this.isInline = isInline;
        this.reversed = reversed;
        this.isScrollAxis = isScrollAxis;
    }

    /** The physical edge corresponding to the logical start edge of the containing block */
    inline function startEdge():AxisStaticEdge {
        return reversed ? AxisStaticEdge.End : AxisStaticEdge.Start;
    }

    /** The physical edge corresponding to the logical end edge of the containing block */
    inline function endEdge():AxisStaticEdge {
        return reversed ? AxisStaticEdge.Start : AxisStaticEdge.End;
    }

    /** The inset-modified containing block (IMCB) in this axis */
    public function insetModifiedContainingBlock():Line {
        var imcbStart:Float;
        var imcbEnd:Float;
        var weakerEdge:AxisStaticEdge;
        if (insetStart.isSome() && insetEnd.isSome()) {
            imcbStart = insetStart.unwrap();
            imcbEnd = cbSize - insetEnd.unwrap();
            weakerEdge = endEdge();
        }
        else if (insetStart.isSome()) {
            // A lone auto inset resolves to zero, and is the weaker inset
            imcbStart = insetStart.unwrap();
            imcbEnd = cbSize;
            weakerEdge = AxisStaticEdge.End;
        }
        else if (insetEnd.isSome()) {
            imcbStart = 0.0;
            imcbEnd = cbSize - insetEnd.unwrap();
            weakerEdge = AxisStaticEdge.Start;
        }
        else {
            // Both insets are auto: resolve them from the static position rectangle and the alignment within it
            final sp = staticPosition;
            switch sp.align.keyword {
                case AxisStaticEdge.Start:
                    imcbStart = sp.area.start;
                    imcbEnd = cbSize;
                case AxisStaticEdge.End:
                    imcbStart = 0.0;
                    imcbEnd = sp.area.end;
                case AxisStaticEdge.Center:
                    // Center the IMCB on the static position rectangle's center, bounded by the nearer edge of the containing block
                    final center = (sp.area.start + sp.area.end) / 2.0;
                    final startDistance = center;
                    final endDistance = cbSize - center;
                    if (Sys.abs(startDistance) <= Sys.abs(endDistance)) {
                        imcbStart = 0.0;
                        imcbEnd = 2.0 * startDistance;
                    }
                    else {
                        imcbStart = cbSize - 2.0 * endDistance;
                        imcbEnd = cbSize;
                    }
            }
            weakerEdge = endEdge();
        }

        // Overconstrained insets: the weaker inset is reduced to bring the IMCB size up to zero
        if (imcbEnd < imcbStart) {
            if (weakerEdge == AxisStaticEdge.Start)
                imcbStart = imcbEnd;
            else
                imcbEnd = imcbStart;
        }
        return new Line(imcbStart, imcbEnd);
    }

    /** The size of the IMCB in this axis: the space available to the box's margin box */
    public inline function insetModifiedContainingBlockSize():Float {
        final imcb = insetModifiedContainingBlock();
        return imcb.end - imcb.start;
    }

    /** The stretch-fit size of the box's border box: the IMCB minus the non-auto margins */
    public function stretchFitSize():Float {
        final nonAutoMarginSum = marginStart.unwrapOr(0.0) + marginEnd.unwrapOr(0.0);
        return Sys.f32Max(insetModifiedContainingBlockSize() - nonAutoMarginSum, 0.0);
    }

    /** Whether an `auto` size in this axis is the stretch-fit size (rather than fit-content) */
    public function isStretchSized(isReplaced:Bool, isTable:Bool):Bool {
        final noAutoInset = insetStart.isSome() && insetEnd.isSome();
        return noAutoInset && switch alignment {
            case Stretch: true;
            case Normal: !isReplaced && !isTable;
            case _: false;
        }
    }

    /** Resolve the box's auto margins given its final size */
    public function resolveMargins(size:Float):Line {
        final bothInsets = insetStart.isSome() && insetEnd.isSome();
        final imcb = insetModifiedContainingBlock();
        final freeSpace = imcb.end - imcb.start - size;
        if (marginStart.isSome() && marginEnd.isSome())
            return new Line(marginStart.unwrap(), marginEnd.unwrap());
        // If either inset is auto then auto margins resolve to zero
        if (!bothInsets)
            return new Line(marginStart.unwrapOr(0.0), marginEnd.unwrapOr(0.0));
        if (marginStart.isSome())
            return new Line(marginStart.unwrap(), freeSpace - marginStart.unwrap());
        if (marginEnd.isSome())
            return new Line(freeSpace - marginEnd.unwrap(), marginEnd.unwrap());
        // In the inline axis, negative free space is absorbed entirely by the end margin
        if (freeSpace < 0.0 && isInline) {
            return reversed ? new Line(freeSpace, 0.0) : new Line(0.0, freeSpace);
        }
        return new Line(freeSpace / 2.0, freeSpace / 2.0);
    }

    /** Compute the physical start of the box's border box given its final size and margins */
    public function position(size:Float, margin:Line):Float {
        final imcb = insetModifiedContainingBlock();
        if (insetStart.isNone() && insetEnd.isNone()) {
            // Both insets are auto: static alignment, with safe overflow relative to the IMCB
            final sp = staticPosition;
            final marginBoxSize = size + margin.start + margin.end;
            final offset = (sp.align.safety == AlignmentSafety.Safe && marginBoxSize > imcb.end - imcb.start)
                ? Oof.alignInLine(imcb, marginBoxSize, startEdge())
                : Oof.alignInLine(sp.area, marginBoxSize, sp.align.keyword);
            return offset + margin.start;
        }
        // One auto inset: the margin box is aligned to the edge of the stronger inset
        if (insetEnd.isNone())
            return imcb.start + margin.start;
        if (insetStart.isNone())
            return imcb.end - size - margin.end;

        // Auto margins have already absorbed all of the free space
        if (marginStart.isNone() || marginEnd.isNone())
            return imcb.start + margin.start;
        final marginBoxSize = size + margin.start + margin.end;
        final imcbSize = imcb.end - imcb.start;
        final edge = alignment.physicalEdge(reversed);
        final marginBoxStart:Float = switch safety {
            case AlignmentSafety.Unsafe:
                Oof.alignInLine(imcb, marginBoxSize, edge);
            case AlignmentSafety.Safe:
                Oof.alignInLine(imcb, marginBoxSize, marginBoxSize > imcbSize ? startEdge() : edge);
            case AlignmentSafety.Default:
                if (marginBoxSize <= imcbSize || alignment == Normal) {
                    // 1. Fits within the IMCB: align as specified
                    Oof.alignInLine(imcb, marginBoxSize, edge);
                }
                else {
                    // The overflow limit rect is the bounding rect of the IMCB and the containing block,
                    // extended to infinity in the scrollable direction of a scroll container
                    var limitStart = Sys.f32Min(imcb.start, 0.0);
                    var limitEnd = Sys.f32Max(imcb.end, cbSize);
                    if (isScrollAxis) {
                        if (reversed)
                            limitStart = Math.NEGATIVE_INFINITY;
                        else
                            limitEnd = Math.POSITIVE_INFINITY;
                    }
                    if (marginBoxSize <= limitEnd - limitStart) {
                        // 2. Fits within the overflow limit rect
                        final start = Oof.alignInLine(imcb, marginBoxSize, edge);
                        Sys.f32Max(Sys.f32Min(start, limitEnd - marginBoxSize), limitStart);
                    }
                    else {
                        // 3. Start-align within the overflow limit rect
                        Oof.alignInLine(new Line(limitStart, limitEnd), marginBoxSize, startEdge());
                    }
                }
        }
        return marginBoxStart + margin.start;
    }

}

/**
 * The result of laying out out-of-flow candidates against an explicit positioning area.
 */
class OofLayoutResult {

    /** Candidates claimed and laid out by this pass, in document order. */
    public final hoisted:Array<NodeId>;

    /** Candidates not claimed by this pass, which must continue bubbling. */
    public final unclaimed:OofCandidates;

    /** Scrollable overflow contributed by the claimed candidates, relative to the positioning area's origin. */
    public final scrollableOverflowRect:Rect;

    public function new(hoisted:Array<NodeId>, unclaimed:OofCandidates, scrollableOverflowRect:Rect) {
        this.hoisted = hoisted;
        this.unclaimed = unclaimed;
        this.scrollableOverflowRect = scrollableOverflowRect;
    }

}

/**
 * The result of laying out a single out-of-flow box with `Oof.layoutOofBox`.
 */
class OofBoxLayout {

    /** The box's final layout (its `location` is relative to the containing block's border box) */
    public final layout:Layout;

    /** Out-of-flow candidates surfaced from within the box's subtree, relative to the box's own border box */
    public final surfaced:OofCandidates;

    /** The box's `overflow` style */
    public final overflow:PointOf<Overflow>;

    /** The box's `contain` style */
    public final contain:Contain;

    public function new(layout:Layout, surfaced:OofCandidates, overflow:PointOf<Overflow>, contain:Contain) {
        this.layout = layout;
        this.surfaced = surfaced;
        this.overflow = overflow;
        this.contain = contain;
    }

}

/**
 * Out-of-flow (absolute / fixed) positioning
 */
class Oof {

    static final FALSE_LINE:LineOf<Bool> = new LineOf<Bool>(false, false);
    static final TRUE_SIZE:SizeOf<Bool> = new SizeOf<Bool>(true, true);

    /**
     * Resolve the final static offset of an out-of-flow box from its static position, given the
     * box's final size and resolved margins.
     */
    public static function resolveStaticOffset(staticPosition:PointOf<AxisStaticPosition>, finalSize:Size, resolvedMargin:Rect):Point {
        return new Point(
            resolveStaticOffsetAxis(staticPosition.x, finalSize.width, new Line(resolvedMargin.left, resolvedMargin.right)),
            resolveStaticOffsetAxis(staticPosition.y, finalSize.height, new Line(resolvedMargin.top, resolvedMargin.bottom))
        );
    }

    /** Single-axis version of `resolveStaticOffset` */
    static function resolveStaticOffsetAxis(sp:AxisStaticPosition, size:Float, margin:Line):Float {
        final marginBoxSize = size + margin.start + margin.end;
        final overflows = sp.align.safety == AlignmentSafety.Safe && marginBoxSize > sp.area.end - sp.area.start;
        final keyword = overflows ? sp.align.fallback : sp.align.keyword;
        return alignInLine(sp.area, marginBoxSize, keyword) + margin.start;
    }

    /** Position a box of `size` within `container` so that it is aligned to the given physical edge */
    public static inline function alignInLine(container:Line, size:Float, edge:AxisStaticEdge):Float {
        return switch edge {
            case AxisStaticEdge.Start: container.start;
            case AxisStaticEdge.End: container.end - size;
            case AxisStaticEdge.Center: (container.start + container.end - size) / 2.0;
        }
    }

    /**
     * Run the out-of-flow positioning pass for `nodeId` after its layout algorithm has produced
     * `output`: lay out the out-of-flow candidates in `output.oofCandidates` for which the node is
     * the containing block, record them as the node's hoisted children, and replace
     * `output.oofCandidates` with the unclaimed remainder. The scrollable overflow contributed by the
     * claimed boxes is merged into `output.scrollableOverflowRect`.
     *
     * It is a no-op when `output.oofPositioningArea` is null (leaf and size-only outputs).
     */
    /** The same value, zero signs included */
    static inline function sameFloat(a:Float, b:Float):Bool {
        return a == b && (b != 0.0 || 1.0 / a == 1.0 / b);
    }

    public static function computeOofLayout(tree:LayoutContainingBlock, nodeId:NodeId, output:LayoutOutput):Void {
        final area = output.oofPositioningArea;
        if (area == null)
            return;
        final taken = output.oofCandidates.take();
        if (taken.isEmpty()) {
            // What the general path gives without any candidate (no hoisted child, no unclaimed
            // candidate, a zero overflow rect from `performOofLayout`), without its lists
            tree.clearHoistedChildren(nodeId);
            output.oofCandidates = OofCandidates.EMPTY;
            final rect = output.scrollableOverflowRect;
            final zero = Rect.ZERO;
            final left = Sys.f32Min(rect.left, zero.left);
            final right = Sys.f32Max(rect.right, zero.right);
            final top = Sys.f32Min(rect.top, zero.top);
            final bottom = Sys.f32Max(rect.bottom, zero.bottom);
            // `rect.union(Rect.ZERO)`, the same object when the union does not change it
            if (!sameFloat(left, rect.left) || !sameFloat(right, rect.right) || !sameFloat(top, rect.top) || !sameFloat(bottom, rect.bottom))
                output.scrollableOverflowRect = new Rect(left, right, top, bottom);
            return;
        }
        output.oofCandidates = taken;
        final style = tree.getCoreContainerStyle(nodeId);
        final direction = style.direction;
        final claims = style.isContainingBlock();
        final candidates = output.oofCandidates.take();
        final result = computeOofLayoutForArea(tree, nodeId, candidates.asArray(), area, direction, claims);
        // Always record the hoisted child list (even when empty) so that lists recorded by previous layout runs do not persist
        tree.clearHoistedChildren(nodeId);
        tree.addHoistedChildren(nodeId, result.hoisted);
        output.oofCandidates = result.unclaimed;
        output.scrollableOverflowRect = output.scrollableOverflowRect.union(result.scrollableOverflowRect);
    }

    /**
     * Lay out out-of-flow candidates against an explicit positioning area.
     *
     * Unlike `computeOofLayout`, this function does not update the geometry owner's hoisted
     * children or merge overflow into a `LayoutOutput`.
     */
    public static function computeOofLayoutForArea(
        tree:LayoutContainingBlock,
        geometryOwner:NodeId,
        candidates:Array<OofCandidate>,
        area:OofPositioningArea,
        direction:Direction,
        claims:ContainingBlockClaims
    ):OofLayoutResult {
        final overflow = tree.getCoreContainerStyle(geometryOwner).overflow;
        final hoisted:Array<NodeId> = [];
        final unclaimed = new OofCandidates();
        final scrollableOverflowRect = performOofLayout(tree, geometryOwner, candidates, area.size, area.offset, direction, claims, overflow, hoisted, unclaimed);
        return new OofLayoutResult(hoisted, unclaimed, scrollableOverflowRect);
    }

    /**
     * Size and position a single out-of-flow box against its containing block, and store its layout.
     *
     * - `areaSize`/`areaOffset` describe the inset-resolution area of the containing block, relative to its border box.
     * - `containerOverflow` is the `overflow` style of the containing block.
     * - `gridOwner` is the node whose detailed layout info is consulted for grid placement (or -1;
     *   an Int rather than a `Null<NodeId>`, which boxes the id on hxcpp).
     * - `beforeLayout` is called with the inputs of the final layout pass just before it runs (may be null).
     */
    public static function layoutOofBox(
        tree:LayoutContainingBlock,
        candidate:OofCandidate,
        areaSize:Size,
        areaOffset:Point,
        direction:Direction,
        containerOverflow:PointOf<Overflow>,
        gridOwner:Int,
        beforeLayout:Null<(LayoutContainingBlock, LayoutInput) -> Void>
    ):OofBoxLayout {
        final childStyle = tree.getOofItemStyle(candidate.node);

        // If the current node is a grid container then the box is positioned relative to the
        // grid area determined by its grid-placement properties
        if (gridOwner != -1) {
            switch tree.getDetailedLayoutInfo(gridOwner) {
                case Grid(gridInfo):
                    final areaRect = new Rect(areaOffset.x, areaOffset.x + areaSize.width, areaOffset.y, areaOffset.y + areaSize.height);
                    final gridArea = gridInfo.resolveAbsoluteGridArea(childStyle.gridRow, childStyle.gridColumn, direction, areaRect);
                    areaSize = new Size(gridArea.right - gridArea.left, gridArea.bottom - gridArea.top);
                    areaOffset = new Point(gridArea.left, gridArea.top);
                case None:
            }
        }
        final areaWidth = areaSize.width;
        final areaHeight = areaSize.height;
        final areaSizeOptions = areaSize.toOptions();

        final aspectRatio = childStyle.aspectRatio;
        final marginStyle = childStyle.margin;
        final margin = new RectOpt(
            marginStyle.left.resolveToOption(areaWidth),
            marginStyle.right.resolveToOption(areaWidth),
            marginStyle.top.resolveToOption(areaWidth),
            marginStyle.bottom.resolveToOption(areaWidth)
        );
        final padding = childStyle.padding.resolveOrZero(OptionalFloat.some(areaWidth));
        final border = childStyle.border.resolveOrZero(OptionalFloat.some(areaWidth));
        final paddingBorderSum = padding.add(border).sumAxes();
        final contentBoxAdjusted = childStyle.boxSizing == ContentBox;
        final boxSizingAdjustment = new Size(contentBoxAdjusted ? paddingBorderSum.width : 0.0, contentBoxAdjusted ? paddingBorderSum.height : 0.0);

        // Resolve inset
        final inset = childStyle.inset;
        final left = inset.left.maybeResolve(OptionalFloat.some(areaWidth));
        final right = inset.right.maybeResolve(OptionalFloat.some(areaWidth));
        final top = inset.top.maybeResolve(OptionalFloat.some(areaHeight));
        final bottom = inset.bottom.maybeResolve(OptionalFloat.some(areaHeight));

        // Compute known dimensions from min/max/inherent size styles
        final sizeStyle = childStyle.size;
        final styleSize = sizeStyle.maybeResolve(areaSizeOptions).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);
        var minSize = childStyle.minSize
            .maybeResolve(areaSizeOptions)
            .maybeApplyAspectRatio(aspectRatio)
            .maybeAddSize(boxSizingAdjustment)
            .or(paddingBorderSum.toOptions())
            .maybeMaxSize(paddingBorderSum);
        final maxSize = childStyle.maxSize.maybeResolve(areaSizeOptions).maybeApplyAspectRatio(aspectRatio).maybeAddSize(boxSizingAdjustment);
        var knownDimensions = styleSize.maybeClamp(minSize, maxSize);

        final isReplaced = childStyle.isReplaced();
        final isTable = childStyle.isTable();
        final itemDirection = childStyle.direction;
        // Taffy only supports the `horizontal-tb` writing mode, so only the inline axis can be reversed.
        // `auto` (null) behaves as `normal` for absolutely positioned boxes.
        final justifySelf = (childStyle.justifySelf != null ? (childStyle.justifySelf : AlignItems) : AlignItems.NORMAL).resolveSelfRelative(itemDirection, direction, true);
        final alignSelf = (childStyle.alignSelf != null ? (childStyle.alignSelf : AlignItems) : AlignItems.NORMAL).resolveSelfRelative(itemDirection, direction, false);
        final overflow = childStyle.overflow;
        final scrollbarWidth = childStyle.scrollbarWidth;
        final contain = childStyle.contain;

        // Static positions are relative to the containing block's border box: make them relative to the inset-resolution area
        final spX = candidate.staticPosition.x;
        final spY = candidate.staticPosition.y;
        final staticPositionX = new AxisStaticPosition(new Line(spX.area.start - areaOffset.x, spX.area.end - areaOffset.x), spX.align);
        final staticPositionY = new AxisStaticPosition(new Line(spY.area.start - areaOffset.y, spY.area.end - areaOffset.y), spY.align);

        final horizontal = new OofAxis(
            areaWidth, left, right, margin.left, margin.right, staticPositionX,
            OofAlignment.fromResolved(justifySelf), justifySelf.safety, true, direction.isRtl(), containerOverflow.x.isScrollContainer()
        );
        final vertical = new OofAxis(
            areaHeight, top, bottom, margin.top, margin.bottom, staticPositionY,
            OofAlignment.fromResolved(alignSelf), alignSelf.safety, false, false, containerOverflow.y.isScrollContainer()
        );

        final stretchFitSize = new Size(horizontal.stretchFitSize(), vertical.stretchFitSize());

        // The space available to the box's border box is its stretch-fit size (the IMCB minus its non-auto margins).
        // The available space for a table never exceeds that of the containing block (minus the margins)
        var availableSpaceSize = stretchFitSize;
        if (isTable) {
            final nonAutoMargin = new Rect(margin.left.unwrapOr(0.0), margin.right.unwrapOr(0.0), margin.top.unwrapOr(0.0), margin.bottom.unwrapOr(0.0));
            availableSpaceSize = availableSpaceSize.f32Min(new Size(
                Sys.f32Max(areaWidth - nonAutoMargin.horizontalAxisSum(), 0.0),
                Sys.f32Max(areaHeight - nonAutoMargin.verticalAxisSum(), 0.0)
            ));
        }
        final clampedAvailable = availableSpaceSize.maybeClamp(minSize, maxSize);
        final availableSpace = new SizeAvail(Definite(clampedAvailable.width), Definite(clampedAvailable.height));

        // Resolve any sizing keywords in the size styles. An explicitly sized axis takes precedence over the automatic size below.
        if (sizeStyle.width.isSizingKeyword() || sizeStyle.height.isSizingKeyword()) {
            knownDimensions = SizingKeyword.resolveAbsoluteSizingKeywords(
                tree,
                candidate.node,
                knownDimensions,
                sizeStyle,
                areaSize,
                new RectOpt(left, right, top, bottom),
                margin,
                ContentSize
            );
            knownDimensions = knownDimensions.maybeApplyAspectRatio(aspectRatio).maybeClamp(minSize, maxSize);
        }

        // Resolve automatic sizes: stretch-fit sizes first so that a size in the other axis can be
        // transferred through the aspect ratio.
        final stretchWidth = knownDimensions.width.isNone() && horizontal.isStretchSized(isReplaced, isTable);
        final stretchHeight = knownDimensions.height.isNone() && vertical.isStretchSized(isReplaced, isTable);
        final bothExplicitStretch = horizontal.alignment == Stretch && vertical.alignment == Stretch;
        // Rust `None`: `OptionalFloat.NONE` (a `null` here became a ratio of 0 on hxcpp, and boxed)
        final stretchAspectRatio = (stretchWidth && stretchHeight && bothExplicitStretch) ? OptionalFloat.NONE : aspectRatio;
        if (stretchWidth) {
            if (isTable) {
                // A table cannot be stretched smaller than its content: stretch-fit is a minimum
                minSize = minSize.withWidth(OptionalFloat.some(Sys.f32Max(minSize.width.unwrapOr(0.0), stretchFitSize.width)));
            }
            else {
                knownDimensions = knownDimensions.withWidth(OptionalFloat.some(stretchFitSize.width));
                knownDimensions = knownDimensions.maybeApplyAspectRatio(stretchAspectRatio).maybeClamp(minSize, maxSize);
            }
        }
        if (knownDimensions.height.isNone() && stretchHeight) {
            if (isTable) {
                minSize = minSize.withHeight(OptionalFloat.some(Sys.f32Max(minSize.height.unwrapOr(0.0), stretchFitSize.height)));
            }
            else {
                knownDimensions = knownDimensions.withHeight(OptionalFloat.some(stretchFitSize.height));
                knownDimensions = knownDimensions.maybeApplyAspectRatio(stretchAspectRatio).maybeClamp(minSize, maxSize);
            }
        }

        var finalSize:Size;
        if (knownDimensions.width.isSome() && knownDimensions.height.isSome()) {
            finalSize = new Size(knownDimensions.width.unwrap(), knownDimensions.height.unwrap());
        }
        else {
            final measuredSize = tree.measureChildSizeBoth(
                candidate.node,
                knownDimensions,
                areaSizeOptions,
                availableSpace,
                ContentSize,
                FALSE_LINE
            );
            finalSize = knownDimensions.unwrapOr(measuredSize);
        }
        finalSize = finalSize.maybeClamp(minSize, maxSize);

        final layoutInput = new LayoutInput(
            PerformLayout,
            ContentSize,
            Both,
            finalSize.toOptions(),
            TRUE_SIZE,
            areaSizeOptions,
            availableSpace,
            FALSE_LINE
        );
        if (beforeLayout != null)
            beforeLayout(tree, layoutInput);
        final layoutOutput = tree.computeChildLayout(candidate.node, layoutInput);

        // Resolve auto margins
        final horizontalMargin = horizontal.resolveMargins(finalSize.width);
        final verticalMargin = vertical.resolveMargins(finalSize.height);
        final resolvedMargin = new Rect(horizontalMargin.start, horizontalMargin.end, verticalMargin.start, verticalMargin.end);

        // Align the margin box within the IMCB
        final location = new Point(
            horizontal.position(finalSize.width, horizontalMargin) + areaOffset.x,
            vertical.position(finalSize.height, verticalMargin) + areaOffset.y
        );

        // Note: axis intentionally switched here as scrollbars take up space in the opposite axis
        // to the axis in which scrolling is enabled.
        final scrollbarSize = new Size(
            overflow.y == Scroll ? scrollbarWidth : 0.0,
            overflow.x == Scroll ? scrollbarWidth : 0.0
        );

        final layout = new Layout(
            candidate.order,
            location,
            finalSize,
            layoutOutput.scrollableOverflowRect,
            scrollbarSize,
            border,
            padding,
            resolvedMargin
        );
        tree.setUnroundedLayout(candidate.node, layout);

        return new OofBoxLayout(layout, layoutOutput.oofCandidates.take(), overflow, contain);
    }

    /**
     * Lay out the candidates claimed by `claims` against the given area, returning the scrollable
     * overflow they contribute. Claimed nodes are appended to `hoisted`, others to `unclaimed`.
     */
    public static function performOofLayout(
        tree:LayoutContainingBlock,
        nodeId:NodeId,
        candidates:Array<OofCandidate>,
        areaSize:Size,
        areaOffset:Point,
        direction:Direction,
        claims:ContainingBlockClaims,
        containerOverflow:PointOf<Overflow>,
        hoisted:Array<NodeId>,
        unclaimed:OofCandidates
    ):Rect {
        var absoluteOverflowRect = Rect.ZERO;
        if (candidates.length == 0)
            return absoluteOverflowRect;

        final isScrollContainer = containerOverflow.x.isScrollContainer() || containerOverflow.y.isScrollContainer();

        // Split the candidate list into an initial work list of claimed candidates and the unclaimed
        // remainder. Further claimed candidates surfaced while laying out a claimed box are appended to the work list.
        final worklist:Array<OofCandidate> = [];
        for (candidate in candidates) {
            if (claims.forPosition(candidate.position))
                worklist.push(candidate);
            else
                unclaimed.push(candidate);
        }

        var index = 0;
        while (index < worklist.length) {
            final candidate = worklist[index];
            index++;
            hoisted.push(candidate.node);

            final boxLayout = layoutOofBox(tree, candidate, areaSize, areaOffset, direction, containerOverflow, nodeId, null);
            final layout = boxLayout.layout;
            final location = layout.location;
            final finalSize = layout.size;

            // Re-sweep any candidates surfaced from within the box's subtree, translating their
            // anchors so they are relative to this node's border box
            final surfaced = boxLayout.surfaced;
            if (!surfaced.isEmpty()) {
                surfaced.translate(location);
                for (i in 0...surfaced.length()) {
                    final surfacedCandidate = surfaced.get(i);
                    if (claims.forPosition(surfacedCandidate.position))
                        worklist.push(surfacedCandidate);
                    else
                        unclaimed.push(surfacedCandidate);
                }
            }

            // Location is measured from the scroll origin (the inline-start edge: right side in RTL)
            final relativeLocation = direction.isRtl()
                ? new Point(areaSize.width - (location.x - areaOffset.x) - finalSize.width, location.y - areaOffset.y)
                : new Point(location.x - areaOffset.x, location.y - areaOffset.y);
            absoluteOverflowRect = absoluteOverflowRect.union(ScrollableOverflow.computeScrollableOverflowContribution(
                relativeLocation,
                finalSize,
                layout.scrollableOverflowRect,
                boxLayout.overflow,
                boxLayout.contain,
                isScrollContainer
            ));
        }

        return absoluteOverflowRect;
    }

}
