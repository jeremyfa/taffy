// Ported from taffy 0.15.0 (repository): tests/hand_written/block_replaced.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.SizeOf;
import taffy.style.Dimension;
import taffy.style.LengthPercentageAuto;
import taffy.style.Style;
import taffy.tree.NodeId;
import taffy.tree.TaffyTree;

/**
 * Sizing of replaced (`itemIsReplaced: true`) children of block containers.
 *
 * Block layout stretch-sizes in-flow children to the container width, but block-level
 * replaced elements are exempt: with `width: auto` they use their intrinsic size.
 */
class BlockReplacedTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("auto_width_uses_intrinsic_size", autoWidthUsesIntrinsicSize),
            new TestCase("non_replaced_child_is_stretch_sized", nonReplacedChildIsStretchSized),
            new TestCase("explicit_width_is_used", explicitWidthIsUsed),
            new TestCase("max_width_clamps_intrinsic_size", maxWidthClampsIntrinsicSize),
            new TestCase("auto_margins_center_replaced_child", autoMarginsCenterReplacedChild),
        ];
    }

    // A 142x20 badge-like image (height = width * 20/142)
    static function badge():TestNodeContext {
        return TestNodeContext.aspectRatio(142.0, 20.0 / 142.0);
    }

    static function blockContainer(width:Float):Style {
        return st(s -> {
            s.display = Block;
            s.size = new SizeOf<Dimension>(length(width), auto());
        });
    }

    static function layout(taffy:TaffyTree<TestNodeContext>, root:NodeId) {
        taffy.computeLayoutWithMeasure(root, MAX_CONTENT, testMeasureFunction);
    }

    static function autoWidthUsesIntrinsicSize() {
        final taffy = newTestTree();
        final child = taffy.newLeafWithContext(st(s -> {
            s.display = Block;
            s.itemIsReplaced = true;
        }), badge());
        final root = taffy.newWithChildren(blockContainer(600.0), [child]);
        layout(taffy, root);

        final childLayout = taffy.layout(child);
        Assert.eq(childLayout.size.width, 142.0);
        Assert.eq(childLayout.size.height, 20.0);
    }

    static function nonReplacedChildIsStretchSized() {
        final taffy = newTestTree();
        final child = taffy.newLeafWithContext(st(s -> {
            s.display = Block;
        }), badge());
        final root = taffy.newWithChildren(blockContainer(600.0), [child]);
        layout(taffy, root);

        Assert.eq(taffy.layout(child).size.width, 600.0);
    }

    static function explicitWidthIsUsed() {
        final taffy = newTestTree();
        final child = taffy.newLeafWithContext(st(s -> {
            s.display = Block;
            s.itemIsReplaced = true;
            s.size = new SizeOf<Dimension>(length(300.0), length(50.0));
        }), badge());
        final root = taffy.newWithChildren(blockContainer(600.0), [child]);
        layout(taffy, root);

        final childLayout = taffy.layout(child);
        Assert.eq(childLayout.size.width, 300.0);
        Assert.eq(childLayout.size.height, 50.0);
    }

    static function maxWidthClampsIntrinsicSize() {
        final taffy = newTestTree();
        final child = taffy.newLeafWithContext(st(s -> {
            s.display = Block;
            s.itemIsReplaced = true;
            s.maxSize = new SizeOf<LengthPercentageAuto>(percent(1.0), auto());
        }), badge());
        final root = taffy.newWithChildren(blockContainer(100.0), [child]);
        layout(taffy, root);

        final childLayout = taffy.layout(child);
        Assert.eq(childLayout.size.width, 100.0);
    }

    static function autoMarginsCenterReplacedChild() {
        final taffy = newTestTree();
        final child = taffy.newLeafWithContext(st(s -> {
            s.display = Block;
            s.itemIsReplaced = true;
            s.margin = rectLPA(auto(), auto(), zero(), zero());
        }), badge());
        final root = taffy.newWithChildren(blockContainer(600.0), [child]);
        layout(taffy, root);

        final childLayout = taffy.layout(child);
        Assert.eq(childLayout.size.width, 142.0);
        Assert.eq(childLayout.location.x, (600.0 - 142.0) / 2.0);
    }

}
