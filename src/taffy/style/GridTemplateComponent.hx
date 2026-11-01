// Ported from taffy 0.15.0: src/style/grid.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * An element in a `grid-template-columns` or `grid-template-rows` definition.
 * Either a track sizing function or a repeat().
 *
 * See https://developer.mozilla.org/en-US/docs/Web/CSS/grid-template-columns
 */
enum GridTemplateComponent {

    /** A single non-repeated track */
    Single(track:TrackSizingFunction);

    /**
     * Automatically generate grid tracks to fit the available space using the specified definite track lengths
     * Only valid if every track in template (not just the repetition) has a fixed size.
     */
    Repeat(repetition:GridTemplateRepetition);

}

/**
 * Helpers for `GridTemplateComponent`
 */
class GridTemplateComponentTools {

    /** Whether the track definition is a auto-repeated fragment */
    public static inline function isAutoRepetition(self:GridTemplateComponent):Bool {
        return switch self {
            case Single(_): false;
            case Repeat(repetition): taffy.style.RepetitionCount.RepetitionCountTools.isAuto(repetition.count);
        }
    }

}
