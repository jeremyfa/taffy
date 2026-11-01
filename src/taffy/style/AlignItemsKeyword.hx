// Ported from taffy 0.15.0: src/style/alignment.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * The positional keyword of an `align-items` / `align-self` / `justify-items` / `justify-self` value
 */
enum abstract AlignItemsKeyword(Int) to Int {

    /** Behaves like `Stretch` or `Start` depending on the layout mode */
    var Normal = 0;
    /** Items are packed toward the start of the axis */
    var Start = 1;
    /** Items are packed toward the end of the axis */
    var End = 2;
    /** Items are packed towards the flex-relative start of the axis */
    var FlexStart = 3;
    /** Items are packed towards the flex-relative end of the axis */
    var FlexEnd = 4;
    /** Items are packed toward the start of the item's own axis */
    var SelfStart = 5;
    /** Items are packed toward the end of the item's own axis */
    var SelfEnd = 6;
    /** Items are packed along the center of the cross axis */
    var Center = 7;
    /** Items are aligned such as their baselines align */
    var Baseline = 8;
    /** Stretch to fill the container */
    var Stretch = 9;

}
