// Ported from taffy 0.15.0: src/style/grid.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * Defines the value of the `grid-template-areas` property: the named areas plus the overall
 * size (in tracks) of the area template.
 *
 * The template may be larger than the extents of the named areas due to unnamed (`.`) cells,
 * so the size is stored explicitly.
 */
class GridTemplateAreas {

    /** The named grid areas */
    public final areas:Array<GridTemplateArea>;

    /** The number of rows in the area template */
    public final rowCount:Int;

    /** The number of columns in the area template */
    public final columnCount:Int;

    public function new(areas:Array<GridTemplateArea>, rowCount:Int, columnCount:Int) {
        this.areas = areas;
        this.rowCount = rowCount;
        this.columnCount = columnCount;
    }

}
