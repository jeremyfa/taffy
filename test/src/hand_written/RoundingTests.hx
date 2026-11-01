// Ported from taffy 0.15.0 (repository): tests/hand_written/rounding.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.SizeOf;
import taffy.style.AlignContent;
import taffy.style.Dimension;

class RoundingTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("rounding_doesnt_leave_gaps", roundingDoesntLeaveGaps),
        ];
    }

    static function roundingDoesntLeaveGaps() {
        // First create an instance of TaffyTree
        final taffy = newTestTree();

        final wSquare = new SizeOf<Dimension>(length(100.3), length(100.3));
        final childA = taffy.newLeaf(st(s -> {
            s.size = wSquare;
        }));
        final childB = taffy.newLeaf(st(s -> {
            s.size = wSquare;
        }));

        final rootNode = taffy.newWithChildren(st(s -> {
            s.size = new SizeOf<Dimension>(length(963.3333), length(1000.0));
            s.justifyContent = AlignContent.CENTER;
        }), [childA, childB]);

        taffy.computeLayout(rootNode, MAX_CONTENT);

        final layoutA = taffy.layout(childA);
        final layoutB = taffy.layout(childB);
        Assert.eq(layoutA.location.x + layoutA.size.width, layoutB.location.x);
    }

}
