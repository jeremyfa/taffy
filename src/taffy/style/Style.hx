// Ported from taffy 0.15.0: src/style/mod.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

import taffy.geometry.AbsoluteAxis;
import taffy.geometry.AbstractAxis;
import taffy.geometry.LineOf;
import taffy.geometry.PointOf;
import taffy.geometry.RectOf;
import taffy.geometry.SizeOf;

/**
 * A typed representation of the CSS style information for a single node.
 *
 * The most important idea in flexbox is the notion of a "main" and "cross" axis, which are always perpendicular to each other.
 * The orientation of these axes are controlled via the `FlexDirection` field of this struct.
 *
 * This struct follows the CSS equivalent directly; information about the behavior on the web should transfer directly.
 *
 * In Rust, the style is accessed by the layout algorithms through the `CoreStyle`, `FlexboxContainerStyle`,
 * `GridContainerStyle`... traits. This port uses the concrete `Style` class directly: the trait accessors
 * that compute something (`boxGenerationMode()`, `isBlock()`, `gridTemplateTracks()`...) are methods of this class.
 *
 * Geometry fields hold immutable objects, so a shallow `clone()` is safe (arrays are copied).
 */
class Style {

    /** What layout strategy should be used? */
    public var display:Display = Display.DEFAULT;

    /** Whether a child is display:table or not. This affects children of block layouts. */
    public var itemIsTable:Bool = false;

    /** Is it a replaced element like an image or form field? */
    public var itemIsReplaced:Bool = false;

    /** Is it a compressible replaced element like a form field? */
    public var itemIsCompressibleReplaced:Bool = false;

    /** Should size styles apply to the content box or the border box of the node */
    public var boxSizing:BoxSizing = BorderBox;

    /** The inline base direction of the node */
    public var direction:Direction = Ltr;

    /** How children overflowing their container should affect layout */
    public var overflow:PointOf<Overflow> = DEFAULT_OVERFLOW;

    /** How much space (in points) should be reserved for the scrollbars of `Overflow.Scroll` nodes */
    public var scrollbarWidth:Float = 0.0;

    /** The CSS `contain` property */
    public var contain:Contain = Contain.NONE;

    /** Should the box be floated (block layout only) */
    public var float:CssFloat = CssFloat.None;

    /** Should the box clear floats (block layout only) */
    public var clear:Clear = Clear.None;

    /** What should the `position` value of this struct use as a base offset? */
    public var position:Position = Static;

    /** How should the position of this element be tweaked relative to the layout defined? */
    public var inset:RectOf<LengthPercentageAuto> = DEFAULT_INSET;

    /** Sets the initial size of the item */
    public var size:SizeOf<Dimension> = DEFAULT_SIZE;

    /** Controls the minimum size of the item */
    public var minSize:SizeOf<LengthPercentageAuto> = DEFAULT_MIN_MAX_SIZE;

    /** Controls the maximum size of the item */
    public var maxSize:SizeOf<LengthPercentageAuto> = DEFAULT_MIN_MAX_SIZE;

    /** Sets the preferred aspect ratio for the item (width / height) */
    public var aspectRatio:Null<Float> = null;

    /** How large should the margin be on each side? */
    public var margin:RectOf<LengthPercentageAuto> = DEFAULT_MARGIN;

    /** How large should the padding be on each side? */
    public var padding:RectOf<LengthPercentage> = DEFAULT_PADDING_BORDER;

    /** How large should the border be on each side? */
    public var border:RectOf<LengthPercentage> = DEFAULT_PADDING_BORDER;

    /** How this node's children aligned in the cross/block axis? */
    public var alignItems:AlignItems = AlignItems.NORMAL;

    /** How this node should be aligned in the cross/block axis (null means `auto`) */
    public var alignSelf:Null<AlignItems> = null;

    /** How this node's children should be aligned in the inline axis */
    public var justifyItems:AlignItems = AlignItems.NORMAL;

    /** How this node should be aligned in the inline axis (null means `auto`) */
    public var justifySelf:Null<AlignItems> = null;

    /** How should content contained within this item be aligned in the cross/block axis */
    public var alignContent:AlignContent = AlignContent.NORMAL;

    /** How should content contained within this item be aligned in the main/inline axis */
    public var justifyContent:AlignContent = AlignContent.NORMAL;

    /** How large should the gaps between items in a grid or flex container be? */
    public var gap:SizeOf<LengthPercentage> = DEFAULT_GAP;

    /** How should the inline content of a block container be aligned (legacy `-webkit-*` values) */
    public var textAlign:TextAlign = TextAlign.Auto;

    /** Which direction does the main axis flow in? */
    public var flexDirection:FlexDirection = Row;

    /** Should elements wrap, or stay in a single line? */
    public var flexWrap:FlexWrap = NoWrap;

    /** The number of lines of a `flex-wrap: balance` container */
    public var flexLineCount:Int = 1;

    /** Sets the initial main axis size of the item */
    public var flexBasis:Dimension = Dimension.AUTO;

    /** The relative rate at which this item grows when it is expanding to fill space */
    public var flexGrow:Float = 0.0;

    /** The relative rate at which this item shrinks when it is contracting to fit into space */
    public var flexShrink:Float = 1.0;

    /** Defines the track sizing functions (heights) of the grid rows */
    public var gridTemplateRows:Array<GridTemplateComponent> = [];

    /** Defines the track sizing functions (widths) of the grid columns */
    public var gridTemplateColumns:Array<GridTemplateComponent> = [];

    /** Defines the size of implicitly created rows */
    public var gridAutoRows:Array<TrackSizingFunction> = [];

    /** Defines the size of implicitly created columns */
    public var gridAutoColumns:Array<TrackSizingFunction> = [];

    /** Controls how items get placed into the grid for auto-placed items */
    public var gridAutoFlow:GridAutoFlow = GridAutoFlow.Row;

    /** Defines the rectangular grid areas */
    public var gridTemplateAreas:Null<GridTemplateAreas> = null;

    /** The named lines between the columns */
    public var gridTemplateColumnNames:Array<Array<String>> = [];

    /** The named lines between the rows */
    public var gridTemplateRowNames:Array<Array<String>> = [];

    /** Defines which row in the grid the item should start and end at */
    public var gridRow:LineOf<GridPlacement> = DEFAULT_GRID_PLACEMENT;

    /** Defines which column in the grid the item should start and end at */
    public var gridColumn:LineOf<GridPlacement> = DEFAULT_GRID_PLACEMENT;

    static final DEFAULT_OVERFLOW:PointOf<Overflow> = new PointOf<Overflow>(Visible, Visible);
    static final DEFAULT_INSET:RectOf<LengthPercentageAuto> = new RectOf<LengthPercentageAuto>(LengthPercentageAuto.AUTO, LengthPercentageAuto.AUTO, LengthPercentageAuto.AUTO, LengthPercentageAuto.AUTO);
    static final DEFAULT_SIZE:SizeOf<Dimension> = new SizeOf<Dimension>(Dimension.AUTO, Dimension.AUTO);
    static final DEFAULT_MIN_MAX_SIZE:SizeOf<LengthPercentageAuto> = new SizeOf<LengthPercentageAuto>(LengthPercentageAuto.AUTO, LengthPercentageAuto.AUTO);
    static final DEFAULT_MARGIN:RectOf<LengthPercentageAuto> = new RectOf<LengthPercentageAuto>(LengthPercentageAuto.ZERO, LengthPercentageAuto.ZERO, LengthPercentageAuto.ZERO, LengthPercentageAuto.ZERO);
    static final DEFAULT_PADDING_BORDER:RectOf<LengthPercentage> = new RectOf<LengthPercentage>(LengthPercentage.ZERO, LengthPercentage.ZERO, LengthPercentage.ZERO, LengthPercentage.ZERO);
    static final DEFAULT_GAP:SizeOf<LengthPercentage> = new SizeOf<LengthPercentage>(LengthPercentage.ZERO, LengthPercentage.ZERO);
    static final DEFAULT_GRID_PLACEMENT:LineOf<GridPlacement> = new LineOf<GridPlacement>(GridPlacement.Auto, GridPlacement.Auto);

    /** A shared default style. Do not mutate it. */
    public static final DEFAULT:Style = new Style();

    public function new() {}

    /** Create a copy of this style (arrays are copied, immutable values are shared) */
    public function clone():Style {
        final s = new Style();
        s.display = display;
        s.itemIsTable = itemIsTable;
        s.itemIsReplaced = itemIsReplaced;
        s.itemIsCompressibleReplaced = itemIsCompressibleReplaced;
        s.boxSizing = boxSizing;
        s.direction = direction;
        s.overflow = overflow;
        s.scrollbarWidth = scrollbarWidth;
        s.contain = contain;
        s.float = float;
        s.clear = clear;
        s.position = position;
        s.inset = inset;
        s.size = size;
        s.minSize = minSize;
        s.maxSize = maxSize;
        s.aspectRatio = aspectRatio;
        s.margin = margin;
        s.padding = padding;
        s.border = border;
        s.alignItems = alignItems;
        s.alignSelf = alignSelf;
        s.justifyItems = justifyItems;
        s.justifySelf = justifySelf;
        s.alignContent = alignContent;
        s.justifyContent = justifyContent;
        s.gap = gap;
        s.textAlign = textAlign;
        s.flexDirection = flexDirection;
        s.flexWrap = flexWrap;
        s.flexLineCount = flexLineCount;
        s.flexBasis = flexBasis;
        s.flexGrow = flexGrow;
        s.flexShrink = flexShrink;
        s.gridTemplateRows = gridTemplateRows.copy();
        s.gridTemplateColumns = gridTemplateColumns.copy();
        s.gridAutoRows = gridAutoRows.copy();
        s.gridAutoColumns = gridAutoColumns.copy();
        s.gridAutoFlow = gridAutoFlow;
        s.gridTemplateAreas = gridTemplateAreas;
        s.gridTemplateColumnNames = [for (names in gridTemplateColumnNames) names.copy()];
        s.gridTemplateRowNames = [for (names in gridTemplateRowNames) names.copy()];
        s.gridRow = gridRow;
        s.gridColumn = gridColumn;
        return s;
    }

    // CoreStyle

    /** The box generation mode of the node (`None` for `display: none`) */
    public inline function boxGenerationMode():BoxGenerationMode {
        return display == Display.None ? BoxGenerationMode.None : BoxGenerationMode.Normal;
    }

    /** Is block layout? */
    public inline function isBlock():Bool {
        return display == Display.Block;
    }

    /** Is it a compressible replaced element? */
    public inline function isCompressibleReplaced():Bool {
        return itemIsReplaced || itemIsCompressibleReplaced;
    }

    /** Is it a replaced element? */
    public inline function isReplaced():Bool {
        return itemIsReplaced;
    }

    /** Which kinds of out-of-flow descendants this node is the containing block for */
    public inline function isContainingBlock():ContainingBlockClaims {
        return position.isPositioned() ? CLAIMS_ABSOLUTE : ContainingBlockClaims.NONE;
    }

    static final CLAIMS_ABSOLUTE:ContainingBlockClaims = new ContainingBlockClaims(true, false);

    // OofItemStyle / BlockItemStyle

    /** Whether the item is a table */
    public inline function isTable():Bool {
        return itemIsTable;
    }

    // GridContainerStyle

    /** Get the grid template tracks for the given axis */
    public inline function gridTemplateTracks(axis:AbsoluteAxis):Array<GridTemplateComponent> {
        return axis == Horizontal ? gridTemplateColumns : gridTemplateRows;
    }

    /** Get the content alignment of the grid container in the given axis (`normal` resolves to `stretch`) */
    public inline function gridAlignContent(axis:AbstractAxis):AlignContent {
        final alignment = axis == Inline ? justifyContent : alignContent;
        return alignment.keyword == AlignContentKeyword.Normal ? AlignContent.STRETCH : alignment;
    }

    /**
     * The number of rows in the `grid-template-areas` template (0 if there is no template).
     * May be greater than the extent of the named areas due to unnamed (`.`) cells.
     */
    public inline function gridTemplateAreaRowCount():Int {
        return gridTemplateAreas != null ? gridTemplateAreas.rowCount : 0;
    }

    /**
     * The number of columns in the `grid-template-areas` template (0 if there is no template).
     * May be greater than the extent of the named areas due to unnamed (`.`) cells.
     */
    public inline function gridTemplateAreaColumnCount():Int {
        return gridTemplateAreas != null ? gridTemplateAreas.columnCount : 0;
    }

    // GridItemStyle

    /** Get the grid placement of the item for the given axis */
    public inline function gridPlacement(axis:AbsoluteAxis):LineOf<GridPlacement> {
        return axis == Horizontal ? gridColumn : gridRow;
    }

}
