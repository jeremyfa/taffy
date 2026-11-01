// Ported from taffy 0.15.0 (repository): tests/hand_written/compressible_replaced.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.SizeOf;
import taffy.style.AlignItems;
import taffy.style.Dimension;
import taffy.style.Style;
import taffy.tree.Layout;

/**
 * Sizing of compressible replaced boxes that are not replaced elements
 * (`itemIsCompressibleReplaced: true`, e.g. form controls such as `<input>`).
 *
 * Like replaced elements, block-level form controls with `width: auto` take their intrinsic
 * width rather than being stretched to the container. Unlike replaced elements, an absolutely
 * positioned form control with both insets set *is* stretched between them.
 */
class CompressibleReplacedTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("block_level_auto_width_uses_intrinsic_size", blockLevelAutoWidthUsesIntrinsicSize),
            new TestCase("block_level_justify_self_stretch_stretches", blockLevelJustifySelfStretchStretches),
            new TestCase("absolute_auto_size_is_stretched_between_insets", absoluteAutoSizeIsStretchedBetweenInsets),
            new TestCase("replaced_implies_compressible_replaced", replacedImpliesCompressibleReplaced),
        ];
    }

    // A 150x20 text input (height = width * 20/150)
    static function input():TestNodeContext {
        return TestNodeContext.aspectRatio(150.0, 20.0 / 150.0);
    }

    static function layoutChild(container:Style, childStyle:Style):Layout {
        final taffy = newTestTree();
        final child = taffy.newLeafWithContext(childStyle, input());
        final root = taffy.newWithChildren(container, [child]);
        taffy.computeLayoutWithMeasure(root, MAX_CONTENT, testMeasureFunction);
        return taffy.layout(child);
    }

    static function blockContainer():Style {
        return st(s -> {
            s.display = Block;
            s.size = new SizeOf<Dimension>(length(400.0), auto());
        });
    }

    static function positionedContainer():Style {
        return st(s -> {
            s.display = Block;
            s.position = Relative;
            s.size = new SizeOf<Dimension>(length(400.0), length(300.0));
        });
    }

    static function blockLevelAutoWidthUsesIntrinsicSize() {
        final layout = layoutChild(blockContainer(), st(s -> {
            s.display = Block;
            s.itemIsCompressibleReplaced = true;
        }));
        Assert.eqSize(layout.size, 150.0, 20.0);
    }

    static function blockLevelJustifySelfStretchStretches() {
        final layout = layoutChild(blockContainer(), st(s -> {
            s.display = Block;
            s.itemIsCompressibleReplaced = true;
            s.justifySelf = AlignItems.STRETCH;
        }));
        Assert.eq(layout.size.width, 400.0);
    }

    static function absoluteAutoSizeIsStretchedBetweenInsets() {
        final layout = layoutChild(positionedContainer(), st(s -> {
            s.position = Absolute;
            s.itemIsCompressibleReplaced = true;
            s.inset = insetAll(10.0);
        }));
        Assert.eqSize(layout.size, 380.0, 280.0);
        Assert.eqPoint(layout.location, 10.0, 10.0);
    }

    static function replacedImpliesCompressibleReplaced() {
        var style = st(s -> {
            s.itemIsReplaced = true;
        });
        Assert.isTrue(style.isCompressibleReplaced());
        Assert.isTrue(style.isReplaced());
        style = st(s -> {
            s.itemIsCompressibleReplaced = true;
        });
        Assert.isTrue(style.isCompressibleReplaced());
        Assert.isFalse(style.isReplaced());
    }

}
