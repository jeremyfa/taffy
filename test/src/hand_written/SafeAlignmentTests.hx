// Ported from taffy 0.15.0 (repository): tests/hand_written/safe_alignment.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.SizeOf;
import taffy.style.AlignContent;
import taffy.style.AlignItems;
import taffy.style.Dimension;
import taffy.style.Direction;
import taffy.style.Style;
import taffy.tree.NodeId;
import taffy.tree.TaffyTree;

/**
 * Tests for the `safe` and `unsafe` overflow-position keywords on align-* and justify-*.
 *
 * When the alignment subject overflows the alignment container, a `safe` value behaves
 * as logical `start`; an `unsafe` value (the default) keeps its requested position even
 * when that causes data loss at the start edge.
 */
class SafeAlignmentTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("grid_safe_align_self_falls_back_to_start_on_overflow", gridSafeAlignSelfFallsBackToStartOnOverflow),
            new TestCase("grid_safe_align_self_behaves_as_end_when_no_overflow", gridSafeAlignSelfBehavesAsEndWhenNoOverflow),
            new TestCase("grid_unsafe_align_self_keeps_overflowing_position", gridUnsafeAlignSelfKeepsOverflowingPosition),
            new TestCase("grid_safe_justify_self_falls_back_to_start_on_overflow", gridSafeJustifySelfFallsBackToStartOnOverflow),
            new TestCase("grid_safe_justify_self_rtl_falls_back_to_rtl_start_edge", gridSafeJustifySelfRtlFallsBackToRtlStartEdge),
            new TestCase("grid_safe_align_content_overflow_falls_back_to_start", gridSafeAlignContentOverflowFallsBackToStart),
            new TestCase("flex_safe_align_self_falls_back_to_start_on_overflow", flexSafeAlignSelfFallsBackToStartOnOverflow),
            new TestCase("flex_unsafe_align_self_keeps_overflowing_position", flexUnsafeAlignSelfKeepsOverflowingPosition),
            new TestCase("flex_safe_justify_content_falls_back_to_start_on_overflow", flexSafeJustifyContentFallsBackToStartOnOverflow),
            new TestCase("flex_safe_align_content_falls_back_to_start_on_multiline_overflow", flexSafeAlignContentFallsBackToStartOnMultilineOverflow),
        ];
    }

    static function sized(width:Float, height:Float):SizeOf<Dimension> {
        return new SizeOf<Dimension>(length(width), length(height));
    }

    /** A 100x100 grid with a single 100x100 cell */
    static function singleCellGrid(direction:Direction):Style {
        return st(s -> {
            s.display = Grid;
            s.direction = direction;
            s.size = sized(100.0, 100.0);
            s.gridTemplateRows = tracks("100px");
            s.gridTemplateColumns = tracks("100px");
        });
    }

    /** Lays out a single child in a container and returns the tree */
    static function layoutSingleChild(childStyle:Style, containerStyle:Style):{taffy:TaffyTree<TestNodeContext>, child:NodeId} {
        final taffy = newTestTree();
        final child = taffy.newLeaf(childStyle);
        final root = taffy.newWithChildren(containerStyle, [child]);
        taffy.computeLayout(root, MAX_CONTENT);
        return {taffy: taffy, child: child};
    }

    static function gridSafeAlignSelfFallsBackToStartOnOverflow() {
        final r = layoutSingleChild(st(s -> {
            s.size = sized(50.0, 150.0);
            s.alignSelf = AlignItems.SAFE_END;
        }), singleCellGrid(Ltr));

        // Child overflows the 100-tall grid area, so safe end falls back to start (y == 0).
        Assert.eq(r.taffy.layout(r.child).location.y, 0.0);
    }

    static function gridSafeAlignSelfBehavesAsEndWhenNoOverflow() {
        final r = layoutSingleChild(st(s -> {
            s.size = sized(50.0, 40.0);
            s.alignSelf = AlignItems.SAFE_END;
        }), singleCellGrid(Ltr));

        // No overflow, so safe end behaves as end: y == 100 - 40 == 60
        Assert.eq(r.taffy.layout(r.child).location.y, 60.0);
    }

    static function gridUnsafeAlignSelfKeepsOverflowingPosition() {
        final r = layoutSingleChild(st(s -> {
            s.size = sized(50.0, 150.0);
            s.alignSelf = AlignItems.END;
        }), singleCellGrid(Ltr));

        // Plain End with overflow keeps end alignment: y == 100 - 150 == -50
        Assert.eq(r.taffy.layout(r.child).location.y, -50.0);
    }

    static function gridSafeJustifySelfFallsBackToStartOnOverflow() {
        final r = layoutSingleChild(st(s -> {
            s.size = sized(150.0, 50.0);
            s.justifySelf = AlignItems.SAFE_END;
        }), singleCellGrid(Ltr));

        Assert.eq(r.taffy.layout(r.child).location.x, 0.0);
    }

    static function gridSafeJustifySelfRtlFallsBackToRtlStartEdge() {
        final r = layoutSingleChild(st(s -> {
            s.size = sized(150.0, 50.0);
            s.justifySelf = AlignItems.SAFE_END;
        }), singleCellGrid(Rtl));

        // In RTL the inline-start edge is the right side. The 150-wide child in the
        // 100-wide container, anchored at the RTL Start edge, sits at x == -50.
        Assert.eq(r.taffy.layout(r.child).location.x, -50.0);
    }

    static function gridSafeAlignContentOverflowFallsBackToStart() {
        final taffy = newTestTree();
        final childA = taffy.newLeaf(st(s -> {
            s.size = sized(40.0, 80.0);
        }));
        final childB = taffy.newLeaf(st(s -> {
            s.size = sized(40.0, 80.0);
        }));
        final root = taffy.newWithChildren(st(s -> {
            s.display = Grid;
            s.size = sized(100.0, 100.0);
            s.gridTemplateRows = tracks("80px 80px");
            s.gridTemplateColumns = tracks("40px");
            s.alignContent = AlignContent.SAFE_END;
        }), [childA, childB]);

        taffy.computeLayout(root, MAX_CONTENT);

        // Tracks total 160 in a 100-tall container: overflow. Safe end falls back to
        // start: first track at y == 0.
        Assert.eq(taffy.layout(childA).location.y, 0.0);
    }

    static function flexContainer():Style {
        return st(s -> {
            s.display = Flex;
            s.size = sized(100.0, 100.0);
        });
    }

    static function flexSafeAlignSelfFallsBackToStartOnOverflow() {
        final r = layoutSingleChild(st(s -> {
            s.size = sized(50.0, 150.0);
            s.alignSelf = AlignItems.SAFE_END;
        }), flexContainer());

        // Cross-axis overflow: safe end falls back to start (y == 0).
        Assert.eq(r.taffy.layout(r.child).location.y, 0.0);
    }

    static function flexUnsafeAlignSelfKeepsOverflowingPosition() {
        final r = layoutSingleChild(st(s -> {
            s.size = sized(50.0, 150.0);
            s.alignSelf = AlignItems.END;
        }), flexContainer());

        // Plain End with cross-axis overflow keeps end alignment: y == 100 - 150 == -50
        Assert.eq(r.taffy.layout(r.child).location.y, -50.0);
    }

    static function flexSafeJustifyContentFallsBackToStartOnOverflow() {
        final taffy = newTestTree();
        final childA = taffy.newLeaf(st(s -> {
            s.size = sized(80.0, 50.0);
        }));
        final childB = taffy.newLeaf(st(s -> {
            s.size = sized(80.0, 50.0);
        }));
        final root = taffy.newWithChildren(stFrom(flexContainer(), s -> {
            s.justifyContent = AlignContent.SAFE_END;
        }), [childA, childB]);

        taffy.computeLayout(root, MAX_CONTENT);

        // Items total 160 in a 100-wide container: overflow. Safe end falls back to
        // start: first item anchored at x == 0.
        Assert.eq(taffy.layout(childA).location.x, 0.0);
    }

    static function flexSafeAlignContentFallsBackToStartOnMultilineOverflow() {
        final taffy = newTestTree();
        final childA = taffy.newLeaf(st(s -> {
            s.size = sized(60.0, 80.0);
        }));
        final childB = taffy.newLeaf(st(s -> {
            s.size = sized(60.0, 80.0);
        }));
        final root = taffy.newWithChildren(stFrom(flexContainer(), s -> {
            s.flexWrap = Wrap;
            s.alignContent = AlignContent.SAFE_END;
        }), [childA, childB]);

        taffy.computeLayout(root, MAX_CONTENT);

        // Two 80-tall lines wrap and overflow the 100-tall container. Safe end falls back
        // to start: first line at y == 0.
        Assert.eq(taffy.layout(childA).location.y, 0.0);
    }

}
