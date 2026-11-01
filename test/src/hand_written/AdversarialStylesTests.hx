// Ported from taffy 0.15.0 (repository): tests/hand_written/adversarial_styles.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.LineOf;
import taffy.geometry.SizeOf;
import taffy.style.AvailableSpace;
import taffy.style.CompactLength;
import taffy.style.Dimension;
import taffy.style.Direction;
import taffy.style.GridPlacement;
import taffy.style.GridTemplateComponent;
import taffy.style.TrackSizingFunction;

/**
 * Tests for style inputs which are valid to construct, but which are degenerate or hostile
 * (non-finite numbers, extreme values, or internally inconsistent grid templates).
 *
 * These tests are primarily about layout *terminating* without throwing.
 *
 * Not ported: `repetition_with_wrong_line_name_set_count_panics` (needs a hand built
 * `GridTemplateRepetition` with an invalid line name count, which the CSS parser cannot produce).
 */
class AdversarialStylesTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("non_finite_flex_factor_terminates", nonFiniteFlexFactorTerminates),
            new TestCase("non_finite_grid_container_size_terminates", nonFiniteGridContainerSizeTerminates),
            new TestCase("repetition_without_line_names_resolves_lines", repetitionWithoutLineNamesResolvesLines),
            new TestCase("zero_span_and_named_span_terminates", zeroSpanAndNamedSpanTerminates),
            new TestCase("small_item_in_max_size_occupied_grid_terminates", smallItemInMaxSizeOccupiedGridTerminates),
            new TestCase("extreme_placements_and_spans_terminate", extremePlacementsAndSpansTerminate),
        ];
    }

    static function definiteSquare(size:Float):SizeOf<AvailableSpace> {
        return definite(size, size);
    }

    /**
     * A `NaN` flex factor makes every comparison in the "find the size of an fr" algorithm false,
     * which used to prevent that algorithm from ever finding a valid hypothetical fr size.
     */
    static function nonFiniteFlexFactorTerminates() {
        for (flexFactor in [Math.NaN, Math.POSITIVE_INFINITY, Math.NEGATIVE_INFINITY]) {
            final tree = newTestTree();
            final child = tree.newLeaf(st(s -> {
                s.size = new SizeOf<Dimension>(Dimension.length(10.0), Dimension.length(10.0));
            }));
            final root = tree.newWithChildren(st(s -> {
                s.display = Grid;
                s.gridTemplateColumns = [GridTemplateComponent.Single(new TrackSizingFunction(CompactLength.AUTO, CompactLength.fr(flexFactor)))];
            }), [child]);

            tree.computeLayout(root, definiteSquare(100.0));
        }
    }

    /**
     * A non-finite size on a grid container makes the space to fill non-finite, which used to
     * prevent the "find the size of an fr" algorithm from terminating.
     */
    static function nonFiniteGridContainerSizeTerminates() {
        for (width in [Math.NaN, Math.POSITIVE_INFINITY]) {
            final tree = newTestTree();
            final child = tree.newLeaf(st(s -> {}));
            final root = tree.newWithChildren(st(s -> {
                s.display = Grid;
                s.size = new SizeOf<Dimension>(Dimension.length(width), Dimension.length(100.0));
                s.gridTemplateColumns = tracks("repeat(2, 1fr)");
            }), [child]);

            tree.computeLayout(root, definiteSquare(100.0));
        }
    }

    /**
     * `repeat()` definitions are allowed to contain no line name sets at all. Line numbering must
     * still account for the tracks that each repetition generates.
     */
    static function repetitionWithoutLineNamesResolvesLines() {
        final tree = newTestTree();
        final child = tree.newLeaf(st(s -> {
            s.size = new SizeOf<Dimension>(Dimension.length(5.0), Dimension.length(5.0));
            s.gridColumn = placement(NamedLine("c", 1), Auto);
        }));
        final root = tree.newWithChildren(st(s -> {
            s.display = Grid;
            s.size = new SizeOf<Dimension>(Dimension.length(100.0), Dimension.length(100.0));
            s.gridTemplateColumns = tracks("repeat(2, 10px) 10px");
            s.gridTemplateColumnNames = [[], [], ["c"]];
        }), [child]);

        tree.computeLayout(root, definiteSquare(100.0));

        // "c" is the 4th line of the grid: the line after the three 10px columns
        Assert.eq(tree.layout(child).location.x, 30.0);
    }

    /**
     * A zero span (an invalid value which gets normalized to 1) combined with an unresolvable
     * named span used to size the implicit grid estimate to zero tracks, while auto-placement
     * resolved the same placement to a span of 1.
     */
    static function zeroSpanAndNamedSpanTerminates() {
        for (direction in [Direction.Ltr, Direction.Rtl]) {
            final tree = newTestTree();
            final child = tree.newLeaf(st(s -> {
                s.gridColumn = placement(NamedSpan("does-not-exist", 1), Span(0));
            }));
            final root = tree.newWithChildren(st(s -> {
                s.display = Grid;
                s.direction = direction;
            }), [child]);

            tree.computeLayout(root, definiteSquare(100.0));
        }
    }

    /**
     * When auto-placement collides with an occupied area, the search cursor must jump past the
     * whole occupied interval.
     */
    static function smallItemInMaxSizeOccupiedGridTerminates() {
        final tree = newTestTree();
        final big = tree.newLeaf(st(s -> {
            s.gridRow = placement(Span(10000), Auto);
            s.gridColumn = placement(Span(10000), Auto);
        }));
        final small = tree.newLeaf(st(s -> {
            s.gridRow = placement(Span(10000), Auto);
            s.gridColumn = placement(Span(1), Auto);
        }));
        final root = tree.newWithChildren(st(s -> {
            s.display = Grid;
            s.size = new SizeOf<Dimension>(Dimension.length(100.0), Dimension.length(100.0));
        }), [big, small]);

        tree.computeLayout(root, definiteSquare(100.0));
    }

    /**
     * Items may span thousands of tracks and be placed thousands of tracks outside of the explicit
     * grid. Auto-placing such items must not take an excessive amount of time.
     */
    static function extremePlacementsAndSpansTerminate() {
        final tree = newTestTree();
        final placements:Array<LineOf<GridPlacement>> = [
            placement(Auto, Span(2000)),
            placement(Line(-2000), Line(2000)),
        ];
        final children = [for (p in placements) tree.newLeaf(st(s -> {
            s.gridRow = p;
            s.gridColumn = p;
        }))];
        final root = tree.newWithChildren(st(s -> {
            s.display = Grid;
            s.size = new SizeOf<Dimension>(Dimension.length(100.0), Dimension.length(100.0));
        }), children);

        tree.computeLayout(root, definiteSquare(100.0));
    }

}
