// Ported from taffy 0.15.0 (repository): tests/hand_written/floats.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.SizeOf;
import taffy.style.Clear;
import taffy.style.CssFloat;
import taffy.style.Dimension;
import taffy.style.Direction;
import taffy.style.LengthPercentageAuto;
import taffy.style.Style;

class FloatsTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("float_no_higher_than_earlier_floats", floatNoHigherThanEarlierFloats),
            new TestCase("clear_past_zero_width_float", clearPastZeroWidthFloat),
            new TestCase("oversized_float_overflows_containing_block", oversizedFloatOverflowsContainingBlock),
            new TestCase("float_beside_existing_float_moves_down_instead_of_overflowing", floatBesideExistingFloatMovesDownInsteadOfOverflowing),
            new TestCase("auto_margins_include_float_avoidance_offsets", autoMarginsIncludeFloatAvoidanceOffsets),
            new TestCase("float_avoiding_auto_margins_in_nested_block_ignore_relative_insets_and_clearance", floatAvoidingAutoMarginsInNestedBlockIgnoreRelativeInsetsAndClearance),
        ];
    }

    /**
     * Regression test for floats-146: a right float placed after two left floats must not be
     * placed higher than the outer top of the earlier floats (CSS2 float rule 5).
     */
    static function floatNoHigherThanEarlierFloats() {
        final taffy = newTestTree();

        final block = (width:Float, height:Float, float:CssFloat) -> st(s -> {
            s.display = Block;
            s.float = float;
            s.size = new SizeOf<Dimension>(length(width), length(height));
        });

        // Spacer block advancing the flow position to a fractional y offset (43.2)
        final spacer = taffy.newLeaf(block(400.0, 43.2, CssFloat.None));
        final floatA = taffy.newLeaf(block(258.0, 42.0, CssFloat.Left));
        final floatB = taffy.newLeaf(block(298.0, 42.0, CssFloat.Left));
        final floatC = taffy.newLeaf(block(98.0, 42.0, CssFloat.Right));

        final root = taffy.newWithChildren(st(s -> {
            s.display = Block;
            s.size = new SizeOf<Dimension>(length(400.0), auto());
        }), [spacer, floatA, floatB, floatC]);

        taffy.computeLayout(root, MAX_CONTENT);

        // A is placed below the spacer
        Assert.eqPoint(taffy.layout(floatA).location, 0.0, 43.0);
        // B does not fit next to A, so is placed below it
        Assert.eqPoint(taffy.layout(floatB).location, 0.0, 85.0);
        // C must not be placed higher than B (it fits next to B on the right)
        Assert.eqPoint(taffy.layout(floatC).location, 302.0, 85.0);
    }

    /**
     * Regression test for margin-collapse-033: floats that occupy no horizontal space still
     * affect `clear`.
     */
    static function clearPastZeroWidthFloat() {
        final taffy = newTestTree();

        // float: left with auto width resolving to 0
        final floated = taffy.newLeaf(st(s -> {
            s.display = Block;
            s.float = CssFloat.Left;
            s.size = new SizeOf<Dimension>(auto(), length(1.0));
        }));
        final cleared = taffy.newLeaf(st(s -> {
            s.display = Block;
            s.clear = Clear.Left;
        }));
        final sibling = taffy.newLeaf(st(s -> {
            s.display = Block;
            s.margin = rectLPA(zero(), zero(), length(99.0), zero());
        }));

        final container = taffy.newWithChildren(st(s -> {
            s.display = Block;
            s.size = new SizeOf<Dimension>(length(100.0), auto());
        }), [floated, cleared, sibling]);
        final root = taffy.newWithChildren(st(s -> {
            s.display = Block;
        }), [container]);

        taffy.computeLayout(root, MAX_CONTENT);

        // The cleared (self-collapsing) block is placed below the float (y=1). Its clearance
        // prevents the sibling's 99px margin from collapsing with preceding margins, so the
        // container's height is 1 + 99 = 100.
        Assert.eq(taffy.layout(container).size.height, 100.0);
    }

    static function floatBlock(width:Float, height:Float, float:CssFloat):Style {
        return st(s -> {
            s.display = Block;
            s.float = float;
            s.size = new SizeOf<Dimension>(length(width), length(height));
        });
    }

    static function rootStyle(width:Float):Style {
        return st(s -> {
            s.display = Block;
            s.size = new SizeOf<Dimension>(length(width), auto());
        });
    }

    /**
     * CSS2 float rule 7: a float that is wider than its containing block and has no other
     * float beside it may overflow the containing block's edge rather than being pushed down.
     */
    static function oversizedFloatOverflowsContainingBlock() {
        final taffy = newTestTree();

        final floatA = taffy.newLeaf(floatBlock(150.0, 50.0, CssFloat.Left));
        final root = taffy.newWithChildren(rootStyle(100.0), [floatA]);

        taffy.computeLayout(root, MAX_CONTENT);

        Assert.eqPoint(taffy.layout(floatA).location, 0.0, 0.0);
    }

    /**
     * CSS2 float rules 3 & 7: a float with another float beside it must not overlap that float
     * (rule 3) nor extend past the containing block's opposite edge (rule 7): it must move down.
     */
    static function floatBesideExistingFloatMovesDownInsteadOfOverflowing() {
        final taffy = newTestTree();

        // Rule 3: an opposite-direction float that doesn't fit must move down, not overlap
        final left = taffy.newLeaf(floatBlock(60.0, 50.0, CssFloat.Left));
        final right = taffy.newLeaf(floatBlock(60.0, 50.0, CssFloat.Right));
        // Rule 7: a same-direction float that doesn't fit must move down, not overflow the
        // containing block's trailing edge
        final left2 = taffy.newLeaf(floatBlock(60.0, 50.0, CssFloat.Left));

        final root = taffy.newWithChildren(rootStyle(100.0), [left, right, left2]);

        taffy.computeLayout(root, MAX_CONTENT);

        Assert.eqPoint(taffy.layout(left).location, 0.0, 0.0);
        Assert.eqPoint(taffy.layout(right).location, 40.0, 50.0);
        Assert.eqPoint(taffy.layout(left2).location, 0.0, 100.0);
    }

    /** Regression test for auto-margins-used-values-with-floats.tentative.html. */
    static function autoMarginsIncludeFloatAvoidanceOffsets() {
        for (direction in [Direction.Ltr, Direction.Rtl]) {
            for (widths in [[0.0, 20.0], [20.0, 0.0], [20.0, 20.0], [0.0, 0.0]]) {
                final leftFloatWidth = widths[0];
                final rightFloatWidth = widths[1];
                final taffy = newTestTree();
                final leftFloat = taffy.newLeaf(floatBlock(leftFloatWidth, 40.0, CssFloat.Left));
                final rightFloat = taffy.newLeaf(floatBlock(rightFloatWidth, 40.0, CssFloat.Right));
                final autoSides = [[true, true], [true, false], [false, true]];
                final boxes = [for (sides in autoSides) taffy.newLeaf(st(s -> {
                    s.display = FlowRoot;
                    s.direction = direction;
                    s.size = new SizeOf<Dimension>(length(40.0), length(10.0));
                    s.margin = rectLPA(
                        sides[0] ? auto() : (zero() : LengthPercentageAuto),
                        sides[1] ? auto() : (zero() : LengthPercentageAuto),
                        auto(),
                        auto()
                    );
                }))];
                final children = [leftFloat, rightFloat].concat(boxes);
                final root = taffy.newWithChildren(st(s -> {
                    s.display = FlowRoot;
                    s.direction = direction;
                    s.size = new SizeOf<Dimension>(length(100.0), auto());
                    s.padding = rectLP(length(5.0), length(5.0), length(5.0), length(5.0));
                }), children);

                taffy.computeLayout(root, MAX_CONTENT);

                for (index in 0...boxes.length) {
                    final leftAuto = autoSides[index][0];
                    final rightAuto = autoSides[index][1];
                    final layout = taffy.layout(boxes[index]);
                    final freeSpace = 90.0 - leftFloatWidth - rightFloatWidth - 40.0;
                    final alignmentMargin = freeSpace / ((leftAuto ? 1 : 0) + (rightAuto ? 1 : 0));
                    final leftGap = leftAuto ? alignmentMargin : 0.0;
                    final msg = 'direction=$direction floats=$widths box=$index';
                    Assert.eqPoint(layout.location, 5.0 + leftFloatWidth + leftGap, 5.0 + index * 10.0, msg);
                    Assert.eqSize(layout.size, 40.0, 10.0, msg);
                    Assert.eq(layout.margin.left, leftAuto ? leftFloatWidth + alignmentMargin : 0.0, msg);
                    Assert.eq(layout.margin.right, rightAuto ? rightFloatWidth + alignmentMargin : 0.0, msg);
                    Assert.eq(layout.margin.top, 0.0, msg);
                    Assert.eq(layout.margin.bottom, 0.0, msg);
                }
            }
        }
    }

    static function floatAvoidingAutoMarginsInNestedBlockIgnoreRelativeInsetsAndClearance() {
        for (direction in [Direction.Ltr, Direction.Rtl]) {
            final taffy = newTestTree();
            final leftFloat = taffy.newLeaf(floatBlock(40.0, 40.0, CssFloat.Left));
            final rightFloat = taffy.newLeaf(floatBlock(60.0, 40.0, CssFloat.Right));
            final boxStyle = st(s -> {
                s.display = FlowRoot;
                s.direction = direction;
                s.size = new SizeOf<Dimension>(length(40.0), length(10.0));
                s.margin = rectLPA(auto(), auto(), zero(), zero());
            });
            final relativeBox = taffy.newLeaf(stFrom(boxStyle, s -> {
                s.position = Relative;
                s.inset = rectLPA(length(7.0), auto(), auto(), auto());
            }));
            final clearedBox = taffy.newLeaf(stFrom(boxStyle, s -> {
                s.clear = Clear.Both;
            }));
            final nested = taffy.newWithChildren(st(s -> {
                s.display = Block;
                s.direction = direction;
                s.margin = rectLPA(length(20.0), length(30.0), zero(), zero());
                s.padding = rectLP(length(5.0), length(7.0), zero(), zero());
                s.border = rectLP(length(3.0), length(5.0), zero(), zero());
            }), [relativeBox, clearedBox]);
            final root = taffy.newWithChildren(st(s -> {
                s.display = FlowRoot;
                s.direction = direction;
                s.size = new SizeOf<Dimension>(length(200.0), auto());
                s.padding = rectLP(length(10.0), length(10.0), length(10.0), length(10.0));
            }), [leftFloat, rightFloat, nested]);

            taffy.computeLayout(root, MAX_CONTENT);

            final msg = 'direction=$direction';
            final relativeLayout = taffy.layout(relativeBox);
            Assert.eqPoint(relativeLayout.location, 47.0, 0.0, msg);
            Assert.eq(relativeLayout.margin.left, 32.0, msg);
            Assert.eq(relativeLayout.margin.right, 38.0, msg);
            final clearedLayout = taffy.layout(clearedBox);
            Assert.eqPoint(clearedLayout.location, 43.0, 40.0, msg);
            Assert.eq(clearedLayout.margin.left, 35.0, msg);
            Assert.eq(clearedLayout.margin.right, 35.0, msg);
            final nestedLayout = taffy.layout(nested);
            Assert.eqPoint(nestedLayout.location, 30.0, 10.0, msg);
            Assert.eq(nestedLayout.margin.left, 20.0, msg);
            Assert.eq(nestedLayout.margin.right, 30.0, msg);
        }
    }

}
