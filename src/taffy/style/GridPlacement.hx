// Ported from taffy 0.15.0: src/style/grid.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * A grid line placement specification. Used for grid-[row/column]-[start/end].
 *
 * Defaults to `GridPlacement.Auto`
 *
 * Specification: https://www.w3.org/TR/css3-grid-layout/#typedef-grid-row-start-grid-line
 */
enum GridPlacement {

    /** Place item according to the auto-placement algorithm, and the parent's grid_auto_flow property */
    Auto;

    /**
     * Place item at specified line (column or row) index, in "CSS Grid Line" coordinates
     * (1-based, negative indices count from the end of the explicit grid, 0 is invalid and treated as auto)
     */
    Line(index:Int);

    /** Place item at specified named line (column or row). An index of 0 means "no index specified". */
    NamedLine(name:String, index:Int);

    /** Item should span specified number of tracks (columns or rows) */
    Span(span:Int);

    /**
     * Item should span until the nth line named `<name>`.
     *
     * If there are less than n lines named `<name>` in the specified direction then
     * all implicit lines will be counted.
     */
    NamedSpan(name:String, count:Int);

}
