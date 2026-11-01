// Ported from taffy 0.15.0: src/style/mod.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * An abstracted version of the CSS `display` property where any value other than "none" is represented by "normal"
 */
enum abstract BoxGenerationMode(Int) {

    /** The node generates a box in the regular way */
    var Normal = 0;

    /** The node and it's descendants generate no boxes (they are hidden) */
    var None = 1;

}
