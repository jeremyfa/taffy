// Ported from taffy 0.15.0: src/compute/flexbox.rs (mod balance)
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.flexbox;

import taffy.util.Sys;

/**
 * Balanced line breaking for `flex-wrap: balance`.
 *
 * Implements the balancing algorithm from the CSS Flexbox Level 2 draft
 * (https://drafts.csswg.org/css-flexbox-2/#balancing). Items are divided into exactly
 * `lineCount` contiguous sequences (lines), where `lineCount` is the number of lines that
 * greedy line breaking would produce (with item sizes floored at zero), raised to the minimum
 * flex line count (`flex-line-count`, clamped to the number of items), such that:
 *
 * - every line holds at least one item;
 * - no line's size exceeds the container's inner main size, unless the line holds a single
 *   (overflowing) item;
 * - a zero-sized item is assigned to the end of the preceding line rather than the beginning
 *   of a line, unless no valid division can glue it there: because extending the preceding
 *   line through the item would make it exceed the container's inner main size (which covers
 *   a preceding single overflowing item), or because gluing leaves the remaining lines
 *   without a valid division of the remaining items;
 * - calling the difference between a line's size and the container's inner main size the
 *   line's *error*, the sum of the squared errors of all lines is minimized;
 * - ties are broken by assigning the most items to the first line, then the most items to the
 *   second line, and so on.
 *
 * Because every division has the same line count, total item size, and total gap size,
 * minimizing the sum of squared errors is equivalent to minimizing the sum of squared *line
 * sizes*, which is what is actually computed: it needs no target size, so an indefinite
 * (infinite) container size needs no special handling (no line overflows, and the
 * minimization equalizes the line sizes). Haxe floats are 64-bit, like the `f64` used upstream.
 *
 * The minimization is a dynamic program over (line count, first item of suffix) accelerated
 * with the divide-and-conquer optimization, running in `O(lineCount * itemCount *
 * log(itemCount))` time; the naive `O(lineCount * itemCount^2)` dynamic program is kept as
 * a test oracle (see `FlexboxUnitTests`).
 */
class FlexBalance {

    /** Score assigned to divisions that violate the line size constraint */
    public static final INFEASIBLE:Float = Math.POSITIVE_INFINITY;

    /**
     * Convert an item size in pixels to a float, flooring negative sizes at zero. (An
     * infinite size is clamped to the largest finite `f32` so that sums stay meaningful.)
     */
    public static inline function toSize(value:Float):Float {
        return Sys.f32Clamp(value, 0.0, Sys.F32_MAX);
    }

    /** Index of the first element of `arr[lo..hi]` (sorted ascending) that is not `< value` (Rust `partition_point(|&e| e < value)`) */
    static function partitionPointLess(arr:Array<Int>, lo:Int, hi:Int, value:Int):Int {
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            if (arr[mid] < value)
                lo = mid + 1;
            else
                hi = mid;
        }
        return lo;
    }

    /** Index of the first element of `arr[lo..hi]` (sorted ascending) that is not `<= value` (Rust `partition_point(|&e| e <= value)`) */
    static function partitionPointLessEq(arr:Array<Int>, lo:Int, hi:Int, value:Int):Int {
        while (lo < hi) {
            final mid = (lo + hi) >> 1;
            if (arr[mid] <= value)
                lo = mid + 1;
            else
                hi = mid;
        }
        return lo;
    }

    /**
     * Compute `cur[start]` and `opts[optsOffset + start]` for `start` in `startLo..=startHi`, where
     * `cur[start]` is the minimum over valid ends `end` of
     * `row.sizes.lineCost(start, end) + row.prev[end + 1]` and `opts[start]` is the largest
     * `end` achieving that minimum. Ends preceding a non-zero item are minimized over
     * `row.nonzeroEnds[colLo..colHi]`; the (at most one) end preceding a zero item allowed
     * by the zero-sized-item rule is merged in afterwards.
     *
     * Uses the divide-and-conquer dynamic programming optimization: over the ends preceding
     * non-zero items, the cost function satisfies the concave quadrangle inequality, so the largest
     * minimizing end is non-decreasing in `start`. Solving the middle `start` therefore
     * splits the end range in two. (The ends constrained by the zero-sized-item rule are *not*
     * monotone this way, which is why they are excluded from the scan and merged in separately.)
     */
    static function fillRow(row:BalanceRow, cur:Array<Float>, opts:Array<Int>, optsOffset:Int, startLo:Int, startHi:Int, colLo:Int, colHi:Int):Void {
        if (startLo > startHi)
            return;
        final start = startLo + ((startHi - startLo) >> 1);

        // Minimize over the in-range ends preceding a non-zero item, starting from `start`
        // (the line must hold at least one item)
        final firstCol = partitionPointLess(row.nonzeroEnds, colLo, colHi, start);
        var minCost = INFEASIBLE;
        var minCol = -1;
        for (col in firstCol...colHi) {
            final end = row.nonzeroEnds[col];
            final lineCost = row.sizes.lineCost(start, end);
            if (lineCost == INFEASIBLE) {
                // Every longer line also exceeds the limit
                break;
            }
            final cost = lineCost + row.prev[end + 1];
            // `<=` keeps the *largest* minimizing end, assigning the most items to the
            // earliest lines as the tie-break requires
            if (cost <= minCost) {
                minCost = cost;
                minCol = col;
            }
        }

        // Merge the single end preceding a zero item that the zero-sized-item rule allows
        var minEnd = minCol >= 0 ? row.nonzeroEnds[minCol] : -1;
        final zeroEnd = Sys.imin(row.fitEnds[start], row.maxEnd);
        if (row.sizes.isZeroItem(zeroEnd + 1)) {
            final cost = row.sizes.lineCost(start, zeroEnd) + row.prev[zeroEnd + 1];
            if (cost < minCost || (cost == minCost && (minEnd < 0 || minEnd < zeroEnd))) {
                minCost = cost;
                minEnd = zeroEnd;
            }
        }

        // Infeasible states are excluded from the range by the caller, and every feasible
        // state has a valid transition (see `LineSizes.suffixGreedyLineCounts`)
        cur[start] = minCost;
        opts[optsOffset + start] = minEnd >= 0 ? minEnd : start;

        // The zero-rule end is excluded from the narrowing: only the non-zero ends' minima
        // are monotone
        if (start > startLo) {
            final hi = minCol >= 0 ? minCol + 1 : colHi;
            fillRow(row, cur, opts, optsOffset, startLo, start - 1, colLo, hi);
        }
        if (start < startHi) {
            final lo = minCol >= 0 ? minCol : firstCol;
            fillRow(row, cur, opts, optsOffset, start + 1, startHi, lo, colHi);
        }
    }

    /** Build the `LineSizes` of the given item sizes */
    public static function makeLineSizes(itemSizes:Array<Float>, lineLimit:Float, gapBetweenItems:Float):LineSizes {
        final itemCount = itemSizes.length;
        final gap = toSize(gapBetweenItems);
        final sums:Array<Float> = [];
        final zeros:Array<Bool> = [];
        var sum = 0.0;
        for (i in 0...itemCount) {
            final size = toSize(itemSizes[i]);
            sum += size + gap;
            sums.push(sum);
            zeros.push(size == 0.0);
        }
        return new LineSizes(sums, zeros, gap, lineLimit);
    }

    /**
     * Determine the number of items on each line that balances items across lines, such that
     * the largest line is as small as possible, with a minimum of `minLineCount` lines
     * (or one line per item if there are fewer items).
     *
     * `itemSizes` must be non-empty. The returned line item counts are all non-zero and sum to
     * the number of items.
     */
    public static function balancedLineItemCounts(itemSizes:Array<Float>, lineLimit:Float, gapBetweenItems:Float, minLineCount:Int):Array<Int> {
        final itemCount = itemSizes.length;
        final sizes = makeLineSizes(itemSizes, lineLimit, gapBetweenItems);

        // `suffixGreedy[start]` is the number of lines greedy line breaking produces for items
        // `start..`, which is also the *fewest* lines the suffix can validly be divided into
        final suffixGreedy = sizes.suffixGreedyLineCounts();
        final clampedMin = minLineCount < 1 ? 1 : (minLineCount > itemCount ? itemCount : minLineCount);
        final lineCount = Sys.imax(suffixGreedy[0], clampedMin);

        final itemCounts:Array<Int> = [];
        if (lineCount == itemCount) {
            // One item per line is the only division (this covers `flex-line-count` of at least
            // the item count as well as every item overflowing a line of its own)
            for (_ in 0...itemCount)
                itemCounts.push(1);
            return itemCounts;
        }

        final fitEnds = sizes.fitEnds();
        final nonzeroEnds:Array<Int> = [];
        for (end in 0...itemCount - 1) {
            if (!sizes.isZeroItem(end + 1))
                nonzeroEnds.push(end);
        }

        // `prev[start]` is the minimum total score of any valid division of items `start..`
        // into exactly `lines - 1` lines (`INFEASIBLE` if there is none), and `cur` is the
        // row being computed for `lines` lines: a division into `lines` lines is a first line
        // `start..=end` plus a division of `end + 1..` into `lines - 1` lines.
        // `opts[(lines - 2) * itemCount + start]` records the largest `end` achieving
        // `cur[start]`, from which the chosen division is read back.
        var prev:Array<Float> = [];
        for (start in 0...itemCount)
            prev.push(sizes.lineCost(start, itemCount - 1));
        var cur:Array<Float> = [];
        for (_ in 0...itemCount)
            cur.push(INFEASIBLE);
        final opts:Array<Int> = [];
        for (_ in 0...(lineCount - 1) * itemCount)
            opts.push(0);
        final row = new BalanceRow(sizes, fitEnds, nonzeroEnds);
        for (lines in 2...lineCount + 1) {
            // The remaining `lines - 1` lines need one item each, bounding this line's end
            final maxEnd = itemCount - lines;
            // Starts whose suffix doesn't fit in `lines` lines even with greedy breaking are
            // infeasible; they form a prefix (a longer suffix never needs fewer lines), and
            // excluding them keeps every state `fillRow` solves feasible
            var firstStart = 0;
            while (firstStart < maxEnd && suffixGreedy[firstStart] > lines) {
                cur[firstStart] = INFEASIBLE;
                firstStart++;
            }
            final colHi = partitionPointLessEq(nonzeroEnds, 0, nonzeroEnds.length, maxEnd);
            row.prev = prev;
            row.maxEnd = maxEnd;
            fillRow(row, cur, opts, (lines - 2) * itemCount, firstStart, maxEnd, 0, colHi);
            final tmp = prev;
            prev = cur;
            cur = tmp;
        }

        // Read the division back out front to back
        var start = 0;
        var lines = lineCount;
        while (lines >= 2) {
            final end = opts[(lines - 2) * itemCount + start];
            itemCounts.push(end - start + 1);
            start = end + 1;
            lines--;
        }
        itemCounts.push(itemCount - start);
        return itemCounts;
    }

}

/**
 * Line sizing shared by the scoring and readback phases
 */
class LineSizes {

    /**
     * Per item, the prefix sum of the item sizes through it (each item also contributes
     * one trailing gap, so the size of the line holding items `start..=end` is
     * `sums[end] - sums[start - 1] - gapBetweenItems`)
     */
    public final sums:Array<Float>;

    /** Per item, whether the item's (floored) size is zero */
    public final zeros:Array<Bool>;

    /** The size of the gap between adjacent items on a line */
    public final gapBetweenItems:Float;

    /** The container's inner main size, which lines may not exceed (unless they hold a single item) */
    public final limit:Float;

    public inline function new(sums:Array<Float>, zeros:Array<Bool>, gapBetweenItems:Float, limit:Float) {
        this.sums = sums;
        this.zeros = zeros;
        this.gapBetweenItems = gapBetweenItems;
        this.limit = limit;
    }

    /** The total number of items */
    public inline function itemCount():Int {
        return sums.length;
    }

    /** Whether the item at `index` has a (floored) size of zero */
    public inline function isZeroItem(index:Int):Bool {
        return zeros[index];
    }

    /** The size of the line holding items `start..=end` */
    public inline function lineSize(start:Int, end:Int):Float {
        final startSum = start == 0 ? 0.0 : sums[start - 1];
        return sums[end] - startSum - gapBetweenItems;
    }

    /**
     * The squared size of the line holding items `start..=end`, or `INFEASIBLE` for a
     * line of more than one item exceeding the limit
     */
    public function lineCost(start:Int, end:Int):Float {
        final size = lineSize(start, end);
        if (end > start && size > limit)
            return FlexBalance.INFEASIBLE;
        return size * size;
    }

    /**
     * For every suffix of the items, the number of lines that greedy line breaking
     * produces for it: each line collects consecutive items until the next item no longer
     * fits, and if even the first item of a line doesn't fit, that line takes just the one
     * (overflowing) item. (The entry for the empty suffix is zero.)
     *
     * This is also the *fewest* lines each suffix can validly be divided into, and a
     * suffix can validly be divided into any number of lines from that count up to its
     * item count.
     */
    public function suffixGreedyLineCounts():Array<Int> {
        final count = itemCount();
        final counts:Array<Int> = [];
        for (_ in 0...count + 1)
            counts.push(0);
        // The (exclusive) end of the greedy first line of the suffix, which only moves
        // down as the suffix grows leftwards since lines starting earlier are larger
        var lineEnd = count;
        var start = count - 1;
        while (start >= 0) {
            while (lineEnd > start + 1 && lineSize(start, lineEnd - 1) > limit)
                lineEnd--;
            counts[start] = 1 + counts[lineEnd];
            start--;
        }
        return counts;
    }

    /**
     * For every `start`, the largest `end` such that the line holding items `start..=end`
     * does not exceed the limit (or `start` itself if even that one item overflows)
     */
    public function fitEnds():Array<Int> {
        final count = itemCount();
        final result:Array<Int> = [];
        // Lines starting later are smaller, so the fit end only moves up
        var fitEnd = 0;
        for (start in 0...count) {
            if (fitEnd < start)
                fitEnd = start;
            while (fitEnd + 1 < count && lineSize(start, fitEnd + 1) <= limit)
                fitEnd++;
            result.push(fitEnd);
        }
        return result;
    }

}

/**
 * One row of the balancing dynamic program: divisions of item suffixes into exactly
 * `lines` lines
 */
class BalanceRow {

    /** The line sizing for the items being divided */
    public final sizes:LineSizes;

    /** See `LineSizes.fitEnds` */
    public final fitEnds:Array<Int>;

    /**
     * The line ends that precede a non-zero item, in ascending order. Line ends preceding a
     * *zero* item are constrained by the zero-sized-item rule and handled separately: for a
     * first line starting at `start`, the only end preceding a zero item that can be part of a
     * valid division is `min(fitEnds[start], maxEnd)`.
     */
    public final nonzeroEnds:Array<Int>;

    /**
     * The previous row: `prev[start]` is the minimum score of any valid division of items
     * `start..` into exactly `lines - 1` lines (`INFEASIBLE` if there is none)
     */
    public var prev:Array<Float> = null;

    /** The largest possible end of the first line: the remaining `lines - 1` lines need one item each */
    public var maxEnd:Int = 0;

    public inline function new(sizes:LineSizes, fitEnds:Array<Int>, nonzeroEnds:Array<Int>) {
        this.sizes = sizes;
        this.fitEnds = fitEnds;
        this.nonzeroEnds = nonzeroEnds;
    }

}
