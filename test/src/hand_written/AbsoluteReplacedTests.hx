// Ported from taffy 0.15.0 (repository): tests/hand_written/absolute_replaced.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.SizeOf;
import taffy.style.Dimension;
import taffy.style.Style;
import taffy.tree.Layout;

/**
 * Sizing of absolutely positioned replaced (`itemIsReplaced: true`) boxes.
 *
 * An `auto` width/height of an absolutely positioned replaced element resolves to its
 * intrinsic size rather than being stretched between its insets.
 */
class AbsoluteReplacedTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("auto_size_uses_intrinsic_size_despite_insets", autoSizeUsesIntrinsicSizeDespiteInsets),
            new TestCase("auto_height_uses_aspect_ratio_despite_insets", autoHeightUsesAspectRatioDespiteInsets),
            new TestCase("non_replaced_auto_size_is_stretched_between_insets", nonReplacedAutoSizeIsStretchedBetweenInsets),
        ];
    }

    // A 100x50 image (height = width * 0.5)
    static function image():TestNodeContext {
        return TestNodeContext.aspectRatio(100.0, 0.5);
    }

    static function container():Style {
        return st(s -> {
            s.display = Block;
            s.position = Relative;
            s.size = new SizeOf<Dimension>(length(400.0), length(300.0));
        });
    }

    static function layoutChild(childStyle:Style):Layout {
        final taffy = newTestTree();
        final child = taffy.newLeafWithContext(childStyle, image());
        final root = taffy.newWithChildren(container(), [child]);
        taffy.computeLayoutWithMeasure(root, MAX_CONTENT, testMeasureFunction);
        return taffy.layout(child);
    }

    static function autoSizeUsesIntrinsicSizeDespiteInsets() {
        final layout = layoutChild(st(s -> {
            s.position = Absolute;
            s.itemIsReplaced = true;
            s.inset = insetAll(10.0);
        }));
        Assert.eqSize(layout.size, 100.0, 50.0);
        Assert.eqPoint(layout.location, 10.0, 10.0);
    }

    static function autoHeightUsesAspectRatioDespiteInsets() {
        final layout = layoutChild(st(s -> {
            s.position = Absolute;
            s.itemIsReplaced = true;
            s.inset = insetAll(10.0);
            s.size = new SizeOf<Dimension>(length(200.0), auto());
        }));
        Assert.eqSize(layout.size, 200.0, 100.0);
    }

    static function nonReplacedAutoSizeIsStretchedBetweenInsets() {
        final layout = layoutChild(st(s -> {
            s.position = Absolute;
            s.inset = insetAll(10.0);
        }));
        Assert.eqSize(layout.size, 380.0, 280.0);
    }

}
