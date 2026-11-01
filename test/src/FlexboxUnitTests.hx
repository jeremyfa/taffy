// Ported from taffy 0.15.0: src/compute/flexbox.rs (mod balance, tests)
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package;

import haxe.Int64;
import taffy.compute.flexbox.FlexBalance;
import taffy.util.Sys;

/**
 * Unit tests of the `flex-wrap: balance` line breaking (the `#[cfg(test)]` tests of `flexbox.rs`)
 */
class FlexboxUnitTests {

    public static function run():{passed:Int, total:Int, failures:Array<String>} {
        final failures:Array<String> = [];
        var total = 0;
        var passed = 0;

        total++;
        final zeroError = zeroSizedItemRule();
        if (zeroError == null)
            passed++;
        else
            failures.push('flexbox balance zero_sized_item_rule: $zeroError');

        total++;
        final naiveError = matchesNaiveDp();
        if (naiveError == null)
            passed++;
        else
            failures.push('flexbox balance matches_naive_dp: $naiveError');

        return {passed: passed, total: total, failures: failures};
    }

    static function sameCounts(a:Array<Int>, b:Array<Int>):Bool {
        if (a.length != b.length)
            return false;
        for (i in 0...a.length) {
            if (a[i] != b[i])
                return false;
        }
        return true;
    }

    static function zeroSizedItemRule():Null<String> {
        // The zero item joins the first line even though the gap it brings makes the score
        // worse: [70, 0] / [20] has line sizes 80 / 20 (score 6800), while [70] / [0, 20]
        // would have line sizes 70 / 30 (score 5800)
        var counts = FlexBalance.balancedLineItemCounts([70.0, 0.0, 20.0], 100.0, 10.0, 1);
        if (!sameCounts(counts, [2, 1]))
            return 'case 1: got $counts';
        // The zero item is not glued to a single overflowing item's line
        counts = FlexBalance.balancedLineItemCounts([150.0, 0.0, 30.0], 100.0, 0.0, 1);
        if (!sameCounts(counts, [1, 2]))
            return 'case 2: got $counts';
        // Zero items are glued as far as the requested line count allows
        counts = FlexBalance.balancedLineItemCounts([70.0, 0.0, 0.0], 100.0, 0.0, 2);
        if (!sameCounts(counts, [2, 1]))
            return 'case 3: got $counts';
        return null;
    }

    /**
     * The number of lines that greedy line breaking produces: each line collects
     * consecutive items until the next item no longer fits, and if even the first item of
     * a line doesn't fit, that line takes just the one (overflowing) item
     */
    static function greedyLineCount(sizes:LineSizes):Int {
        final itemCount = sizes.itemCount();
        var lineCount = 1;
        var index = 0;
        while (index < itemCount) {
            var next = index;
            while (next < itemCount && sizes.lineSize(index, next) <= sizes.limit)
                next++;
            if (next == index)
                next = index + 1;
            index = next;
            if (index < itemCount)
                lineCount++;
        }
        return lineCount;
    }

    /**
     * The zero-sized-item rule, brute force: a line `start..=end` (of a division of
     * `start..` into `lines` lines) may only end before a zero-sized item if no division
     * that extends the line through the item exists. (`minErrors` rows below `lines` must already be computed.)
     */
    static function zeroBoundaryValid(sizes:LineSizes, minErrors:Array<Float>, lines:Int, start:Int, end:Int):Bool {
        final itemCount = sizes.itemCount();
        if (!sizes.isZeroItem(end + 1))
            return true;
        for (gluedEnd in end + 1...itemCount - lines + 1) {
            if (sizes.lineSize(start, gluedEnd) > sizes.limit)
                break;
            if (Sys.isFinite(minErrors[(lines - 2) * itemCount + gluedEnd + 1]))
                return false;
        }
        return true;
    }

    /**
     * The naive `O(lineCount * itemCount^2)` dynamic program from the spec, used as a
     * test oracle for the divide-and-conquer optimized implementation
     */
    static function naiveLineItemCounts(itemSizes:Array<Float>, lineLimit:Float, gapBetweenItems:Float, minLineCount:Int):Array<Int> {
        final itemCount = itemSizes.length;
        final sizes = FlexBalance.makeLineSizes(itemSizes, lineLimit, gapBetweenItems);

        final clampedMin = minLineCount < 1 ? 1 : (minLineCount > itemCount ? itemCount : minLineCount);
        final lineCount = Sys.imax(greedyLineCount(sizes), clampedMin);

        // `minErrors[(lines - 1) * itemCount + start]` is the minimum total score of any
        // valid division of items `start..` into exactly `lines` lines
        final minErrors:Array<Float> = [];
        for (start in 0...itemCount)
            minErrors.push(sizes.lineCost(start, itemCount - 1));
        for (lines in 2...lineCount + 1) {
            final row = (lines - 1) * itemCount;
            for (start in 0...itemCount) {
                var minError = FlexBalance.INFEASIBLE;
                var end = start;
                while (end + lines <= itemCount) {
                    final lineCost = sizes.lineCost(start, end);
                    if (lineCost == FlexBalance.INFEASIBLE)
                        break;
                    if (zeroBoundaryValid(sizes, minErrors, lines, start, end)) {
                        final error = lineCost + minErrors[row - itemCount + end + 1];
                        if (error < minError)
                            minError = error;
                    }
                    end++;
                }
                minErrors.push(minError);
            }
        }

        // For each line, the *largest* end whose error plus the minimum remaining error
        // adds up to the (feasible) minimum is chosen
        if (!Sys.isFinite(minErrors[(lineCount - 1) * itemCount]))
            throw "naive: infeasible";
        final itemCounts:Array<Int> = [];
        var start = 0;
        var linesAfter = lineCount - 1;
        while (linesAfter >= 0) {
            final target = minErrors[linesAfter * itemCount + start];
            var end = itemCount - 1 - linesAfter;
            while (true) {
                if (sizes.lineCost(start, end) != FlexBalance.INFEASIBLE
                    && (linesAfter == 0 || zeroBoundaryValid(sizes, minErrors, linesAfter + 1, start, end))) {
                    final remainingError = linesAfter == 0 ? 0.0 : minErrors[(linesAfter - 1) * itemCount + end + 1];
                    if (sizes.lineCost(start, end) + remainingError == target)
                        break;
                }
                if (end <= start)
                    throw "naive: no end found";
                end--;
            }
            itemCounts.push(end - start + 1);
            start = end + 1;
            linesAfter--;
        }
        if (start != itemCount)
            throw "naive: items left over";
        return itemCounts;
    }

    static function matchesNaiveDp():Null<String> {
        // A simple xorshift PRNG so the test is deterministic and dependency-free
        var state:Int64 = Int64.make(0x243F6A88, 0x85A308D3);
        function rand(bound:Int):Int {
            state = state ^ (state << 13);
            state = state ^ Int64.ushr(state, 7);
            state = state ^ (state << 17);
            final high:Int = Int64.ushr(state, 32).low;
            final unsigned:Float = high < 0 ? high + 4294967296.0 : high;
            return Std.int(unsigned % bound);
        }

        for (caseIndex in 0...5000) {
            // Mostly small item counts (quantized sizes maximize ties, exercising the
            // tie-break rules), with some larger ones exercising the recursion
            final itemCount = caseIndex % 20 == 0 ? rand(60) + 1 : rand(15) + 1;
            final itemSizes:Array<Float> = [];
            for (_ in 0...itemCount) {
                final size = switch rand(8) {
                    // Frequent zero items exercise the zero-sized-item rule
                    case 0 | 1: 0.0;
                    case 2: -10.0;
                    case _: rand(8) * 25.0;
                }
                itemSizes.push(size);
            }
            final lineLimit = switch rand(5) {
                case 0: Math.POSITIVE_INFINITY;
                case _: rand(10) * 30.0;
            }
            final gapBetweenItems = rand(4) * 5.0;
            final minLineCount = rand(itemCount + 2);

            final expected = naiveLineItemCounts(itemSizes, lineLimit, gapBetweenItems, minLineCount);
            final actual = FlexBalance.balancedLineItemCounts(itemSizes, lineLimit, gapBetweenItems, minLineCount);
            if (!sameCounts(actual, expected)) {
                return 'case $caseIndex: itemSizes=$itemSizes lineLimit=$lineLimit gapBetweenItems=$gapBetweenItems minLineCount=$minLineCount expected=$expected actual=$actual';
            }
        }
        return null;
    }

}
