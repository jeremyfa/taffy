// Ported from taffy 0.15.0: src/style/flex.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

import taffy.geometry.AbsoluteAxis;

/**
 * The direction of the flexbox layout main axis.
 *
 * There are always two perpendicular layout axes: main (or primary) and cross (or secondary).
 * Adding items will cause them to be positioned adjacent to each other along the main axis.
 *
 * The default value is `Row`.
 * https://www.w3.org/TR/css-flexbox-1/#flex-direction-property
 */
enum abstract FlexDirection(Int) {

    /** Defines +x as the main axis. Items will be added from left to right in a row. */
    var Row = 0;

    /** Defines +y as the main axis. Items will be added from top to bottom in a column. */
    var Column = 1;

    /** Defines -x as the main axis. Items will be added from right to left in a row. */
    var RowReverse = 2;

    /** Defines -y as the main axis. Items will be added from bottom to top in a column. */
    var ColumnReverse = 3;

    /** Is the direction `Row` or `RowReverse`? */
    public inline function isRow():Bool {
        return this == 0 || this == 2;
    }

    /** Is the direction `Column` or `ColumnReverse`? */
    public inline function isColumn():Bool {
        return this == 1 || this == 3;
    }

    /** Is the direction `RowReverse` or `ColumnReverse`? */
    public inline function isReverse():Bool {
        return this >= 2;
    }

    /** The `AbsoluteAxis` that corresponds to the main axis */
    public inline function mainAxis():AbsoluteAxis {
        return isRow() ? Horizontal : Vertical;
    }

    /** The `AbsoluteAxis` that corresponds to the cross axis */
    public inline function crossAxis():AbsoluteAxis {
        return isRow() ? Vertical : Horizontal;
    }

    /** Parse a CSS keyword, or return null */
    public static function parse(input:String):Null<FlexDirection> {
        return switch (StringTools.trim(input).toLowerCase()) {
            case "row": Row;
            case "column": Column;
            case "row-reverse": RowReverse;
            case "column-reverse": ColumnReverse;
            case _: null;
        }
    }

}
