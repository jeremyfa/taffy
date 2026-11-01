// Ported from taffy 0.15.0 (repository): tests/hand_written/initial_containing_block.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.RectOf;
import taffy.geometry.SizeOf;
import taffy.style.AvailableSpace;
import taffy.style.Dimension;
import taffy.style.LengthPercentageAuto;
import taffy.style.Position;
import taffy.style.Style;
import taffy.tree.TaffyTree;
import taffy.geometry.SizeAvail;

/**
 * Tests for the initial containing block: boxes with no nearer containing block are positioned
 * against a viewport-sized rectangle at the canvas origin, not against the root element's box.
 */
class InitialContainingBlockTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("root_is_placed_at_its_margin", rootIsPlacedAtItsMargin),
            new TestCase("inset_zero_fills_viewport", insetZeroFillsViewport),
            new TestCase("bottom_right_insets_resolve_against_viewport", bottomRightInsetsResolveAgainstViewport),
            new TestCase("static_position_is_unaffected", staticPositionIsUnaffected),
            new TestCase("fixed_root_is_positioned_by_its_insets", fixedRootIsPositionedByItsInsets),
        ];
    }

    static final VIEWPORT:SizeAvail = definite(800.0, 600.0);

    static function rootStyle():Style {
        return st(s -> {
            s.display = Block;
            s.margin = rectLPA(length(10.0), length(10.0), length(20.0), length(20.0));
            s.border = rectLP(length(5.0), length(5.0), length(5.0), length(5.0));
        });
    }

    static function oofStyle(position:Position, inset:RectOf<LengthPercentageAuto>, size:SizeOf<Dimension>):Style {
        return st(s -> {
            s.position = position;
            s.inset = inset;
            s.size = size;
        });
    }

    static function autoSize():SizeOf<Dimension> {
        return new SizeOf<Dimension>(auto(), auto());
    }

    static function rootIsPlacedAtItsMargin() {
        final tree = new TaffyTree<Int>();
        final root = tree.newLeaf(rootStyle());
        tree.computeLayout(root, VIEWPORT);

        final layout = tree.layout(root);
        Assert.eqPoint(layout.location, 10.0, 20.0);
        Assert.eq(layout.size.width, 780.0);
    }

    static function insetZeroFillsViewport() {
        for (position in [Position.Absolute, Position.Fixed]) {
            final tree = new TaffyTree<Int>();
            final oof = tree.newLeaf(oofStyle(position, insetAll(0.0), autoSize()));
            final root = tree.newWithChildren(rootStyle(), [oof]);
            tree.computeLayout(root, VIEWPORT);

            // Location is relative to the root's border box, which sits at (10, 20) in the viewport
            final layout = tree.layout(oof);
            Assert.eqPoint(layout.location, -10.0, -20.0, positionName(position));
            Assert.eqSize(layout.size, 800.0, 600.0, positionName(position));
        }
    }

    static function bottomRightInsetsResolveAgainstViewport() {
        for (position in [Position.Absolute, Position.Fixed]) {
            final tree = new TaffyTree<Int>();
            final oof = tree.newLeaf(oofStyle(
                position,
                rectLPA(auto(), length(0.0), auto(), length(0.0)),
                new SizeOf<Dimension>(length(50.0), length(50.0))
            ));
            // The root has no in-flow content, so its border box is much shorter than the viewport
            final root = tree.newWithChildren(rootStyle(), [oof]);
            tree.computeLayout(root, VIEWPORT);

            final layout = tree.layout(oof);
            Assert.eqPoint(layout.location, 800.0 - 50.0 - 10.0, 600.0 - 50.0 - 20.0, positionName(position));
        }
    }

    static function staticPositionIsUnaffected() {
        final tree = new TaffyTree<Int>();
        final oof = tree.newLeaf(oofStyle(Absolute, rectAuto(), new SizeOf<Dimension>(length(50.0), length(50.0))));
        final root = tree.newWithChildren(rootStyle(), [oof]);
        tree.computeLayout(root, VIEWPORT);

        Assert.eqPoint(tree.layout(oof).location, 5.0, 5.0);
    }

    static function fixedRootIsPositionedByItsInsets() {
        // `position: fixed` roots cannot be covered by the generated tests, so check that they are
        // positioned like absolutely positioned roots against the initial containing block.
        final tree = new TaffyTree<Int>();
        final root = tree.newLeaf(st(s -> {
            s.display = Block;
            s.position = Fixed;
            s.inset = rectLPA(auto(), length(10.0), percent(0.1), auto());
            s.size = new SizeOf<Dimension>(length(100.0), length(50.0));
        }));
        tree.computeLayout(root, VIEWPORT);

        final layout = tree.layout(root);
        Assert.eqPoint(layout.location, 800.0 - 100.0 - 10.0, 60.0);
        Assert.eqSize(layout.size, 100.0, 50.0);
    }

}
