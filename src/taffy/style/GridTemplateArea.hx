// Ported from taffy 0.15.0: src/style/grid.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * Defines a grid area
 */
class GridTemplateArea {

    /** The name of the grid area */
    public final name:String;

    /** The index of the row at which the grid area starts in grid coordinates. */
    public final rowStart:Int;

    /** The index of the row at which the grid area ends in grid coordinates. */
    public final rowEnd:Int;

    /** The index of the column at which the grid area starts in grid coordinates. */
    public final columnStart:Int;

    /** The index of the column at which the grid area end in grid coordinates. */
    public final columnEnd:Int;

    public function new(name:String, rowStart:Int, rowEnd:Int, columnStart:Int, columnEnd:Int) {
        this.name = name;
        this.rowStart = rowStart;
        this.rowEnd = rowEnd;
        this.columnStart = columnStart;
        this.columnEnd = columnEnd;
    }

}

/**
 * Defines a named grid line
 */
class NamedGridLine {

    /** The name of the grid line */
    public final name:String;

    /** The index of the line in grid coordinates */
    public final index:Int;

    public function new(name:String, index:Int) {
        this.name = name;
        this.index = index;
    }

}
