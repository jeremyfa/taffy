// Ported from taffy 0.15.0 (repository): tests/hand_written/block_margin.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.SizeOf;
import taffy.style.Dimension;
import taffy.style.Style;

class BlockMarginTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("layout_margin_excludes_collapsed_margins", layoutMarginExcludesCollapsedMargins),
        ];
    }

    static function block(marginTop:Float, marginBottom:Float, height:Dimension):Style {
        return st(s -> {
            s.display = Block;
            s.size = new SizeOf<Dimension>(auto(), height);
            s.margin = rectLPA(zero(), zero(), length(marginTop), length(marginBottom));
        });
    }

    /** Margin collapsing changes where boxes are placed, but `Layout.margin` is each box's own margin */
    static function layoutMarginExcludesCollapsedMargins() {
        final taffy = newTestTree();
        final inner = taffy.newLeaf(block(13.0, 20.0, length(10.0)));
        final outer = taffy.newWithChildren(block(8.0, 5.0, auto()), [inner]);
        final sibling = taffy.newLeaf(block(30.0, 0.0, length(10.0)));
        final root = taffy.newWithChildren(st(s -> {
            s.display = FlowRoot;
            s.size = new SizeOf<Dimension>(length(100.0), auto());
        }), [outer, sibling]);

        taffy.computeLayout(root, MAX_CONTENT);

        // The inner box's margins collapse through the outer box's edges
        final outerLayout = taffy.layout(outer);
        Assert.eq(outerLayout.location.y, 13.0);
        Assert.eq(outerLayout.size.height, 10.0);
        Assert.eq(outerLayout.margin.top, 8.0);
        Assert.eq(outerLayout.margin.bottom, 5.0);

        final innerLayout = taffy.layout(inner);
        Assert.eq(innerLayout.location.y, 0.0);
        Assert.eq(innerLayout.margin.top, 13.0);
        Assert.eq(innerLayout.margin.bottom, 20.0);

        // The sibling is placed after the largest of the adjoining margins (5, 20, 30)
        final siblingLayout = taffy.layout(sibling);
        Assert.eq(siblingLayout.location.y, 53.0);
        Assert.eq(siblingLayout.margin.top, 30.0);
    }

}
