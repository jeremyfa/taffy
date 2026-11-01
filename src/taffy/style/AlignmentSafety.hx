// Ported from taffy 0.15.0: src/style/alignment.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * The overflow-position (`safe` / `unsafe`) of an alignment value
 * https://www.w3.org/TR/css-align-3/#overflow-values
 */
enum abstract AlignmentSafety(Int) to Int {

    /** No overflow-position keyword was specified */
    var Default = 0;

    /** `unsafe`: honor the alignment even if the content overflows */
    var Unsafe = 1;

    /** `safe`: fall back to `start` if the content overflows */
    var Safe = 2;

}
