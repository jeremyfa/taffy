// Ported from taffy 0.15.0 (repository): tests/hand_written/root_constraints.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.SizeOf;
import taffy.style.Dimension;
import taffy.style.Style;
import taffy.tree.TaffyTree;

class RootConstraintsTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("root_with_percentage_size", rootWithPercentageSize),
            new TestCase("root_with_no_size", rootWithNoSize),
            new TestCase("root_with_larger_size", rootWithLargerSize),
            new TestCase("root_padding_and_border_larger_than_definite_size", rootPaddingAndBorderLargerThanDefiniteSize),
        ];
    }

    static function rootWithPercentageSize() {
        final taffy = newTestTree();
        final node = taffy.newLeaf(st(s -> {
            s.size = new SizeOf<Dimension>(Dimension.percent(1.0), Dimension.percent(1.0));
        }));

        taffy.computeLayout(node, definite(100.0, 200.0));
        final layout = taffy.layout(node);

        Assert.eq(layout.size.width, 100.0);
        Assert.eq(layout.size.height, 200.0);
    }

    static function rootWithNoSize() {
        final taffy = newTestTree();
        final node = taffy.newLeaf(new Style());

        taffy.computeLayout(node, definite(100.0, 100.0));
        final layout = taffy.layout(node);

        Assert.eq(layout.size.width, 0.0);
        Assert.eq(layout.size.height, 0.0);
    }

    static function rootWithLargerSize() {
        final taffy = newTestTree();
        final node = taffy.newLeaf(st(s -> {
            s.size = new SizeOf<Dimension>(Dimension.length(200.0), Dimension.length(200.0));
        }));

        taffy.computeLayout(node, definite(100.0, 100.0));
        final layout = taffy.layout(node);

        Assert.eq(layout.size.width, 200.0);
        Assert.eq(layout.size.height, 200.0);
    }

    static function rootPaddingAndBorderLargerThanDefiniteSize() {
        final tree = new TaffyTree<Int>();

        final child = tree.newLeaf(new Style());

        final root = tree.newWithChildren(st(s -> {
            s.size = new SizeOf<Dimension>(length(10.0), length(10.0));
            s.padding = rectLP(length(10.0), length(10.0), length(10.0), length(10.0));
            s.border = rectLP(length(10.0), length(10.0), length(10.0), length(10.0));
        }), [child]);

        tree.computeLayout(root, MAX_CONTENT);

        final layout = tree.layout(root);

        Assert.eq(layout.size.width, 40.0);
        Assert.eq(layout.size.height, 40.0);
    }

}
