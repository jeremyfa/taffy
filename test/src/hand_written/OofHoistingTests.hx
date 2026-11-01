// Ported from taffy 0.15.0 (repository): tests/hand_written/oof_hoisting.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.SizeOf;
import taffy.style.Dimension;
import taffy.style.Display;
import taffy.style.Style;
import taffy.tree.TaffyTree;

/**
 * Tests for out-of-flow hoisting: absolute/fixed boxes are laid out by their containing
 * block (nearest positioned ancestor, or the root) rather than by their DOM parent, and
 * their `Layout.location` is relative to that containing block.
 */
class OofHoistingTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("absolute_skips_static_parent", absoluteSkipsStaticParent),
            new TestCase("hoisted_children_are_in_document_order", hoistedChildrenAreInDocumentOrder),
            new TestCase("static_position_is_containing_block_relative", staticPositionIsContainingBlockRelative),
            new TestCase("fixed_hoists_to_root", fixedHoistsToRoot),
            new TestCase("absolute_within_absolute", absoluteWithinAbsolute),
            new TestCase("fixed_within_absolute_hoists_to_root", fixedWithinAbsoluteHoistsToRoot),
            new TestCase("hoisting_survives_cache_hits", hoistingSurvivesCacheHits),
            new TestCase("cached_root_does_not_duplicate_hoisted_children", cachedRootDoesNotDuplicateHoistedChildren),
            new TestCase("rounding_uses_containing_block_offsets", roundingUsesContainingBlockOffsets),
            new TestCase("claim_change_relayouts_with_hot_cache", claimChangeRelayoutsWithHotCache),
            new TestCase("fixed_claim_change_relayouts_with_hot_cache", fixedClaimChangeRelayoutsWithHotCache),
            new TestCase("content_change_inside_hoisted_subtree", contentChangeInsideHoistedSubtree),
        ];
    }

    static function leafStyle(width:Float, height:Float):Style {
        return st(s -> {
            s.size = new SizeOf<Dimension>(length(width), length(height));
        });
    }

    static function sized(width:Float, height:Float):SizeOf<Dimension> {
        return new SizeOf<Dimension>(length(width), length(height));
    }

    /**
     * An absolute box whose parent is static is positioned relative to the nearest
     * positioned ancestor, with a containing-block-relative location.
     */
    static function absoluteSkipsStaticParent() {
        for (display in [Display.Block, Display.Flex, Display.Grid]) {
            final tree = new TaffyTree<Int>();
            final abs = tree.newLeaf(st(s -> {
                s.position = Absolute;
                s.inset = rectLPA(length(10.0), auto(), length(20.0), auto());
                s.size = sized(30.0, 30.0);
            }));
            // Static in-flow parent, offset from the containing block's origin
            final staticParent = tree.newWithChildren(st(s -> {
                s.display = display;
                s.margin = rectLPA(length(40.0), auto(), length(40.0), auto());
                s.size = sized(50.0, 50.0);
            }), [abs]);
            final cb = tree.newWithChildren(st(s -> {
                s.display = display;
                s.position = Relative;
                s.size = sized(200.0, 200.0);
            }), [staticParent]);

            tree.computeLayout(cb, MAX_CONTENT);

            // Location is relative to the containing block, not the static parent
            final layout = tree.layout(abs);
            Assert.eqPoint(layout.location, 10.0, 20.0, displayName(display));
            Assert.eqSize(layout.size, 30.0, 30.0, displayName(display));
        }
    }

    /**
     * The containing block's hoisted children are recorded in document order: direct
     * out-of-flow children interleaved with boxes hoisted out of in-flow children's subtrees.
     */
    static function hoistedChildrenAreInDocumentOrder() {
        for (display in [Display.Block, Display.Flex, Display.Grid]) {
            final tree = new TaffyTree<Int>();
            final absStyle = st(s -> {
                s.position = Absolute;
                s.size = sized(10.0, 10.0);
            });
            final inflowStyle = st(s -> {
                s.display = display;
                s.size = sized(20.0, 20.0);
            });

            // Children of `cb`, in document order:
            //   [direct_a, static_b(> nested_b), static_c(> nested_c), direct_d, static_e(> nested_e)]
            final directA = tree.newLeaf(absStyle.clone());
            final nestedB = tree.newLeaf(absStyle.clone());
            final staticB = tree.newWithChildren(inflowStyle.clone(), [nestedB]);
            final nestedC = tree.newLeaf(absStyle.clone());
            final staticC = tree.newWithChildren(inflowStyle.clone(), [nestedC]);
            final directD = tree.newLeaf(absStyle.clone());
            final nestedE = tree.newLeaf(absStyle.clone());
            final staticE = tree.newWithChildren(inflowStyle.clone(), [nestedE]);
            final cb = tree.newWithChildren(st(s -> {
                s.display = display;
                s.position = Relative;
                s.flexWrap = WrapReverse;
                s.flexDirection = RowReverse;
                s.size = sized(50.0, 200.0);
            }), [directA, staticB, staticC, directD, staticE]);

            tree.computeLayout(cb, MAX_CONTENT);

            Assert.eqIds(tree.hoistedChildren(cb), [directA, nestedB, nestedC, directD, nestedE], displayName(display));
        }
    }

    /**
     * An absolute box with auto insets is placed at its static position: where it would
     * have been placed in the normal flow of its DOM parent, expressed relative to its
     * containing block.
     */
    static function staticPositionIsContainingBlockRelative() {
        for (display in [Display.Block, Display.Flex, Display.Grid]) {
            final tree = new TaffyTree<Int>();
            final abs = tree.newLeaf(st(s -> {
                s.position = Absolute;
                s.size = sized(30.0, 30.0);
            }));
            final sibling = tree.newLeaf(leafStyle(50.0, 50.0));
            final staticParent = tree.newWithChildren(st(s -> {
                s.display = display;
                s.margin = rectLPA(length(40.0), auto(), length(40.0), auto());
                s.size = sized(100.0, 100.0);
            }), [sibling, abs]);
            final cb = tree.newWithChildren(st(s -> {
                s.display = display;
                s.position = Relative;
                s.size = sized(200.0, 200.0);
            }), [staticParent]);

            tree.computeLayout(cb, MAX_CONTENT);

            // Static position is offset by the static parent's location within the CB
            final layout = tree.layout(abs);
            switch display {
                // Block: below the in-flow sibling
                case Block: Assert.eqPoint(layout.location, 40.0, 90.0, displayName(display));
                // Flex/grid: placed as if it were the sole item, at the content-box start
                case Flex | Grid: Assert.eqPoint(layout.location, 40.0, 40.0, displayName(display));
                case _: throw "unreachable";
            }
        }
    }

    /** A fixed box bubbles past positioned (non-transformed) ancestors all the way to the root. */
    static function fixedHoistsToRoot() {
        final tree = new TaffyTree<Int>();
        final fixed = tree.newLeaf(st(s -> {
            s.position = Fixed;
            s.inset = rectLPA(length(5.0), auto(), length(5.0), auto());
            s.size = sized(10.0, 10.0);
        }));
        final positionedParent = tree.newWithChildren(st(s -> {
            s.position = Relative;
            s.margin = rectLPA(length(50.0), auto(), length(50.0), auto());
            s.size = sized(50.0, 50.0);
        }), [fixed]);
        final root = tree.newWithChildren(leafStyle(200.0, 200.0), [positionedParent]);

        tree.computeLayout(root, MAX_CONTENT);

        // Location is relative to the root, ignoring the positioned (but not fixed-CB) parent
        Assert.eqPoint(tree.layout(fixed).location, 5.0, 5.0);
    }

    /**
     * An absolute descendant of an absolute box resolves against the absolute box
     * (which is positioned and therefore a containing block).
     */
    static function absoluteWithinAbsolute() {
        final tree = new TaffyTree<Int>();
        final inner = tree.newLeaf(st(s -> {
            s.position = Absolute;
            s.inset = rectLPA(auto(), length(0.0), auto(), length(0.0));
            s.size = sized(10.0, 10.0);
        }));
        final outer = tree.newWithChildren(st(s -> {
            s.position = Absolute;
            s.inset = rectLPA(length(20.0), auto(), length(20.0), auto());
            s.size = sized(50.0, 50.0);
        }), [inner]);
        final root = tree.newWithChildren(leafStyle(200.0, 200.0), [outer]);

        tree.computeLayout(root, MAX_CONTENT);

        Assert.eqPoint(tree.layout(outer).location, 20.0, 20.0);
        // Relative to `outer`, its containing block
        Assert.eqPoint(tree.layout(inner).location, 40.0, 40.0);
    }

    /**
     * A fixed descendant surfaced while laying out an absolute box (at the abspos box's
     * containing block) is re-swept and continues bubbling to the root.
     */
    static function fixedWithinAbsoluteHoistsToRoot() {
        final tree = new TaffyTree<Int>();
        final fixed = tree.newLeaf(st(s -> {
            s.position = Fixed;
            s.inset = rectLPA(length(1.0), auto(), length(2.0), auto());
            s.size = sized(10.0, 10.0);
        }));
        final abs = tree.newWithChildren(st(s -> {
            s.position = Absolute;
            s.inset = rectLPA(length(20.0), auto(), length(20.0), auto());
            s.size = sized(50.0, 50.0);
        }), [fixed]);
        final cb = tree.newWithChildren(st(s -> {
            s.position = Relative;
            s.margin = rectLPA(length(30.0), auto(), length(30.0), auto());
            s.size = sized(100.0, 100.0);
        }), [abs]);
        final root = tree.newWithChildren(leafStyle(200.0, 200.0), [cb]);

        tree.computeLayout(root, MAX_CONTENT);

        Assert.eqPoint(tree.layout(abs).location, 20.0, 20.0);
        // Root-relative, unaffected by `cb` or `abs` offsets
        Assert.eqPoint(tree.layout(fixed).location, 1.0, 2.0);
    }

    /**
     * Hoisting still works when the intermediate (static) ancestors hit the layout cache:
     * the cached `LayoutOutput` re-propagates the candidates without descending into
     * the skipped subtree.
     */
    static function hoistingSurvivesCacheHits() {
        final tree = new TaffyTree<Int>();
        final abs = tree.newLeaf(st(s -> {
            s.position = Absolute;
            s.inset = rectLPA(length(10.0), auto(), length(20.0), auto());
            s.size = sized(30.0, 30.0);
        }));
        var staticAncestor = tree.newWithChildren(leafStyle(50.0, 50.0), [abs]);
        for (_ in 0...3) {
            staticAncestor = tree.newWithChildren(leafStyle(50.0, 50.0), [staticAncestor]);
        }
        final cb = tree.newWithChildren(st(s -> {
            s.position = Relative;
            s.size = sized(200.0, 200.0);
        }), [staticAncestor]);

        tree.computeLayout(cb, MAX_CONTENT);
        Assert.eqPoint(tree.layout(abs).location, 10.0, 20.0);

        // Recompute without dirtying anything: everything hits the cache
        tree.computeLayout(cb, MAX_CONTENT);
        Assert.eqPoint(tree.layout(abs).location, 10.0, 20.0);

        // Relayout with the same constraints: intermediate nodes hit the cache
        tree.markDirty(cb);
        tree.computeLayout(cb, MAX_CONTENT);
        Assert.eqPoint(tree.layout(abs).location, 10.0, 20.0);

        // Changing the abspos box's styles relays it out through its containing block
        final newStyle = tree.style(abs).clone();
        newStyle.inset = newStyle.inset.withLeft(length(15.0));
        tree.setStyle(abs, newStyle);
        tree.computeLayout(cb, MAX_CONTENT);
        Assert.eqPoint(tree.layout(abs).location, 15.0, 20.0);
    }

    /**
     * When the root's layout is served from the cache, the root positioning pass must not
     * re-add fixed boxes to the root's (still valid) hoisted-children list.
     */
    static function cachedRootDoesNotDuplicateHoistedChildren() {
        final tree = new TaffyTree<Int>();
        final fixed = tree.newLeaf(st(s -> {
            s.position = Fixed;
            s.size = sized(30.0, 30.0);
        }));
        final inner = tree.newWithChildren(leafStyle(50.0, 50.0), [fixed]);
        final root = tree.newWithChildren(leafStyle(200.0, 200.0), [inner]);

        tree.computeLayout(root, MAX_CONTENT);
        Assert.eqIds(tree.hoistedChildren(root), [fixed]);

        tree.computeLayout(root, MAX_CONTENT);
        Assert.eqIds(tree.hoistedChildren(root), [fixed]);

        tree.markDirty(root);
        tree.computeLayout(root, MAX_CONTENT);
        Assert.eqIds(tree.hoistedChildren(root), [fixed]);
    }

    /**
     * Rounding recurses into hoisted boxes via their containing block, so a hoisted box's
     * rounded location is computed against the containing block's cumulative offset.
     */
    static function roundingUsesContainingBlockOffsets() {
        final tree = new TaffyTree<Int>();
        tree.enableRounding();
        final abs = tree.newLeaf(st(s -> {
            s.position = Absolute;
            s.inset = rectLPA(length(10.6), auto(), length(10.6), auto());
            s.size = sized(10.0, 10.0);
        }));
        final staticParent = tree.newWithChildren(leafStyle(50.0, 50.0), [abs]);
        final cb = tree.newWithChildren(st(s -> {
            s.position = Relative;
            s.margin = rectLPA(length(20.3), auto(), length(20.3), auto());
            s.size = sized(100.0, 100.0);
        }), [staticParent]);
        final root = tree.newWithChildren(leafStyle(200.0, 200.0), [cb]);

        tree.computeLayout(root, MAX_CONTENT);

        // cb rounds to x=20; abs at cumulative 20.3+10.6=30.9 rounds to 31, i.e. 11 relative to cb
        Assert.eqPoint(tree.layout(cb).location, 20.0, 20.0);
        Assert.eqPoint(tree.layout(abs).location, 11.0, 11.0);
    }

    /**
     * When an intermediate ancestor becomes positioned (with a hot cache), it claims
     * the hoisted box away from the outer containing block, and vice versa when it
     * becomes static again.
     */
    static function claimChangeRelayoutsWithHotCache() {
        final tree = new TaffyTree<Int>();
        final abs = tree.newLeaf(st(s -> {
            s.position = Absolute;
            s.inset = rectLPA(length(10.0), auto(), length(20.0), auto());
            s.size = sized(30.0, 30.0);
        }));
        final middleStyle = st(s -> {
            s.margin = rectLPA(length(40.0), auto(), length(40.0), auto());
            s.size = sized(50.0, 50.0);
        });
        final middle = tree.newWithChildren(middleStyle.clone(), [abs]);
        final cb = tree.newWithChildren(st(s -> {
            s.position = Relative;
            s.size = sized(200.0, 200.0);
        }), [middle]);

        tree.computeLayout(cb, MAX_CONTENT);
        Assert.eqPoint(tree.layout(abs).location, 10.0, 20.0);

        // Make the middle node positioned: it now claims the abspos box, whose
        // location becomes relative to the middle node.
        final positionedMiddle = middleStyle.clone();
        positionedMiddle.position = Relative;
        tree.setStyle(middle, positionedMiddle);
        tree.computeLayout(cb, MAX_CONTENT);
        Assert.eqPoint(tree.layout(abs).location, 10.0, 20.0);
        // Page position moved by the middle node's offset
        Assert.eqPoint(tree.layout(middle).location, 40.0, 40.0);

        // Back to static: the outer containing block claims it again.
        tree.setStyle(middle, middleStyle);
        tree.computeLayout(cb, MAX_CONTENT);
        Assert.eqPoint(tree.layout(abs).location, 10.0, 20.0);
        Assert.eqPoint(tree.layout(middle).location, 40.0, 40.0);
    }

    /**
     * A fixed box hoisted to the root moves to an intermediate ancestor when that
     * ancestor starts claiming fixed boxes (position change with a hot cache), and back.
     */
    static function fixedClaimChangeRelayoutsWithHotCache() {
        final tree = new TaffyTree<Int>();
        final fixed = tree.newLeaf(st(s -> {
            s.position = Fixed;
            s.inset = rectLPA(length(5.0), auto(), length(5.0), auto());
            s.size = sized(10.0, 10.0);
        }));
        final absStyle = st(s -> {
            s.position = Absolute;
            s.inset = rectLPA(length(50.0), auto(), length(50.0), auto());
            s.size = sized(80.0, 80.0);
        });
        final abs = tree.newWithChildren(absStyle.clone(), [fixed]);
        final root = tree.newWithChildren(leafStyle(200.0, 200.0), [abs]);

        tree.computeLayout(root, MAX_CONTENT);
        // Fixed box is claimed by the root, not the abspos ancestor
        Assert.eqPoint(tree.layout(fixed).location, 5.0, 5.0);
        Assert.eqPoint(tree.layout(abs).location, 50.0, 50.0);

        // Dirty only the fixed box: it must still be re-laid out via the root
        final newFixedStyle = tree.style(fixed).clone();
        newFixedStyle.inset = newFixedStyle.inset.withLeft(length(7.0));
        tree.setStyle(fixed, newFixedStyle);
        tree.computeLayout(root, MAX_CONTENT);
        Assert.eqPoint(tree.layout(fixed).location, 7.0, 5.0);
    }

    /**
     * Content changes inside a hoisted subtree relayout correctly through the
     * containing block even when unrelated siblings hit the cache.
     */
    static function contentChangeInsideHoistedSubtree() {
        final tree = new TaffyTree<Int>();
        final inner = tree.newLeaf(leafStyle(10.0, 10.0));
        final abs = tree.newWithChildren(st(s -> {
            s.position = Absolute;
            s.inset = rectLPA(length(10.0), auto(), length(10.0), auto());
        }), [inner]);
        final staticParent = tree.newWithChildren(leafStyle(50.0, 50.0), [abs]);
        final cb = tree.newWithChildren(st(s -> {
            s.position = Relative;
            s.size = sized(200.0, 200.0);
        }), [staticParent]);

        tree.computeLayout(cb, MAX_CONTENT);
        Assert.eqSize(tree.layout(abs).size, 10.0, 10.0);

        // Grow the inner leaf: the hoisted abspos box must resize
        tree.setStyle(inner, leafStyle(20.0, 30.0));
        tree.computeLayout(cb, MAX_CONTENT);
        Assert.eqSize(tree.layout(abs).size, 20.0, 30.0);
    }

}
