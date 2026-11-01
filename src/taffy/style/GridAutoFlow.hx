// Ported from taffy 0.15.0: src/style/grid.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

import taffy.geometry.AbsoluteAxis;

/**
 * Controls whether grid items are placed row-wise or column-wise. And whether the sparse or dense packing algorithm is used.
 *
 * The default value is `Row`.
 * https://developer.mozilla.org/en-US/docs/Web/CSS/grid-auto-flow
 */
enum abstract GridAutoFlow(Int) {

    /** Items are placed by filling each row in turn, adding new rows as necessary */
    var Row = 0;

    /** Items are placed by filling each column in turn, adding new columns as necessary. */
    var Column = 1;

    /** Combines `Row` with the dense packing algorithm. */
    var RowDense = 2;

    /** Combines `Column` with the dense packing algorithm. */
    var ColumnDense = 3;

    /** Whether grid auto placement uses the sparse placement algorithm or the dense placement algorithm */
    public inline function isDense():Bool {
        return this >= 2;
    }

    /** Whether grid auto placement fills areas row-wise or column-wise */
    public inline function primaryAxis():AbsoluteAxis {
        return (this == 0 || this == 2) ? Horizontal : Vertical;
    }

    /** Parse a CSS value, or return null */
    public static function parse(input:String):Null<GridAutoFlow> {
        final parts = StringTools.trim(input).toLowerCase().split(" ").filter(p -> p != "");
        if (parts.length == 0 || parts.length > 2)
            return null;
        var axis:Null<String> = null;
        var dense = false;
        for (p in parts) {
            switch p {
                case "row" | "column":
                    if (axis != null) return null;
                    axis = p;
                case "dense":
                    if (dense) return null;
                    dense = true;
                case _:
                    return null;
            }
        }
        if (axis == "column")
            return dense ? ColumnDense : Column;
        return dense ? RowDense : Row;
    }

}
