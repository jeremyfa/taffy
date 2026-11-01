// Ported from taffy 0.15.0 (repository): tests/hand_written/position.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.SizeOf;
import taffy.style.Dimension;
import taffy.style.Display;
import taffy.style.Position;
import taffy.tree.NodeId;
import taffy.tree.TaffyTree;

class PositionTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("static_and_sticky_ignore_inset", staticAndStickyIgnoreInset),
            new TestCase("sticky_is_positioned_but_in_flow", stickyIsPositionedButInFlow),
        ];
    }

    static function leafWithInset(position:Position, display:Display):{taffy:TaffyTree<Int>, child:NodeId} {
        final taffy = new TaffyTree<Int>();
        final child = taffy.newLeaf(st(s -> {
            s.position = position;
            s.size = new SizeOf<Dimension>(length(10.0), length(10.0));
            s.inset = rectLPA(length(5.0), auto(), length(7.0), auto());
        }));
        final root = taffy.newWithChildren(st(s -> {
            s.display = display;
            s.size = new SizeOf<Dimension>(length(100.0), length(100.0));
        }), [child]);
        taffy.computeLayout(root, MAX_CONTENT);
        return {taffy: taffy, child: child};
    }

    static function staticAndStickyIgnoreInset() {
        for (display in [Display.Block, Display.Flex, Display.Grid]) {
            for (position in [Position.Static, Position.Sticky]) {
                final r = leafWithInset(position, display);
                final layout = r.taffy.layout(r.child);
                Assert.eqPoint(layout.location, 0.0, 0.0, '${positionName(position)} in ${displayName(display)}');
            }
            final r = leafWithInset(Relative, display);
            Assert.eqPoint(r.taffy.layout(r.child).location, 5.0, 7.0, 'Relative in ${displayName(display)}');
        }
    }

    static function stickyIsPositionedButInFlow() {
        Assert.isTrue(Position.Sticky.isPositioned());
        Assert.isFalse(Position.Sticky.isOutOfFlow());
        Assert.isFalse(Position.Static.isPositioned());
    }

}
