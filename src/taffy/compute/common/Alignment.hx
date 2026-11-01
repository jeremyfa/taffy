// Ported from taffy 0.15.0: src/compute/common/alignment.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.common;

import taffy.style.AlignContent;
import taffy.style.AlignContentKeyword;
import taffy.style.AlignItems;
import taffy.style.AlignItemsKeyword;
import taffy.style.AlignmentSafety;

/**
 * Alignment helpers shared by the layout algorithms
 */
class Alignment {

    /**
     * Resolve the `safe`/`unsafe` overflow-position fallback for a self-level alignment value.
     * If the alignment subject overflows its alignment container and the requested alignment is `safe`,
     * fall back to logical `Start`. Otherwise drop the safety modifier and return the bare keyword.
     */
    public static inline function resolveSelfAlignmentSafety(alignment:AlignItems, overflows:Bool):AlignItemsKeyword {
        return (alignment.safety == AlignmentSafety.Safe && overflows) ? AlignItemsKeyword.Start : alignment.keyword;
    }

    /**
     * Resolve any spec-defined fallbacks for the given `AlignContent` value, returning the
     * bare position keyword the alignment math should use.
     *
     * `normal` must be resolved by the caller (if it is not, it is treated as `stretch`).
     */
    public static function applyAlignmentFallback(freeSpace:Float, numItems:Int, alignmentMode:AlignContent):AlignContentKeyword {
        var keyword:AlignContentKeyword = alignmentMode.keyword == Normal ? Stretch : alignmentMode.keyword;
        var isSafe = alignmentMode.safety == AlignmentSafety.Safe;

        // 1. If there is only a single item being aligned or the items overflow the container, the
        //    distributed alignment keywords fall back to a positional keyword and gain implicit `safe` semantics.
        if (numItems <= 1 || freeSpace <= 0.0) {
            switch keyword {
                case Stretch | SpaceBetween:
                    keyword = FlexStart;
                    isSafe = true;
                case SpaceAround | SpaceEvenly:
                    keyword = Center;
                    isSafe = true;
                case _:
            }
        }

        // 2. Safe alignment falls back to `Start` whenever the alignment subject would overflow the alignment container.
        if (freeSpace <= 0.0 && isSafe) {
            keyword = Start;
        }

        return keyword;
    }

    /**
     * Generic alignment function that is used:
     *   - For both align-content and justify-content alignment
     *   - For both the Flexbox and CSS Grid algorithms
     *
     * CSS Grid does not apply gaps as part of alignment, so the gap parameter should always be set to zero for CSS Grid.
     */
    public static function computeAlignmentOffset(freeSpace:Float, numItems:Int, gap:Float, alignmentMode:AlignContentKeyword, layoutIsFlexReversed:Bool, isFirst:Bool):Float {
        if (isFirst) {
            return switch alignmentMode {
                case Start: 0.0;
                case FlexStart: layoutIsFlexReversed ? freeSpace : 0.0;
                case End: freeSpace;
                case FlexEnd: layoutIsFlexReversed ? 0.0 : freeSpace;
                case Center: freeSpace / 2.0;
                case Normal | Stretch: 0.0;
                case SpaceBetween: 0.0;
                case SpaceAround: freeSpace >= 0.0 ? (freeSpace / numItems) / 2.0 : freeSpace / 2.0;
                case SpaceEvenly: freeSpace >= 0.0 ? freeSpace / (numItems + 1) : freeSpace / 2.0;
            }
        }
        else {
            final fs = freeSpace > 0.0 ? freeSpace : 0.0;
            return gap + switch alignmentMode {
                case Start | FlexStart | End | FlexEnd | Center | Normal | Stretch: 0.0;
                case SpaceBetween: fs / (numItems - 1);
                case SpaceAround: fs / numItems;
                case SpaceEvenly: fs / (numItems + 1);
            }
        }
    }

}
