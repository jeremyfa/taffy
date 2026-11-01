// Ported from taffy 0.15.0 (repository): tests/hand_written/detailed_grid_info.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;

#if taffy_detailed_grid_tests
import taffy.compute.grid.DetailedGridInfo;
import taffy.geometry.LineOf;
import taffy.geometry.Rect;
import taffy.geometry.SizeOf;
import taffy.style.Dimension;
import taffy.style.Direction;
import taffy.style.GridPlacement;
import taffy.style.GridTemplateAreas;
import taffy.style.LengthPercentage;
import taffy.tree.NodeId;
import taffy.tree.TaffyTree;
#end

/**
 * Tests for the detailed grid info: per-track positions, per-line names, and resolved
 * track list serialization.
 *
 * These tests use the `DetailedGridInfo` API of the grid port (Rust names in camelCase:
 * `rows` / `columns` (`lineNames`, `iterLineNames()`, `namesForLine()`, `negativeImplicitTracks`,
 * `positions`), `gridTemplateColumns()`, `itemGridArea()`, `resolveAbsoluteGridArea()`), and
 * `GridTemplateAreas` / `GridTemplateArea`. They are only compiled with `-D taffy_detailed_grid_tests`.
 */
class DetailedGridInfoTests {

    public static function tests():Array<TestCase> {
        return [
            #if taffy_detailed_grid_tests
            new TestCase("no_line_names", noLineNames),
            new TestCase("zoomed_track_list", zoomedTrackList),
            new TestCase("template_and_area_line_names", templateAndAreaLineNames),
            new TestCase("repeat_expansion_line_names", repeatExpansionLineNames),
            new TestCase("implicit_tracks_shift_line_names", implicitTracksShiftLineNames),
            new TestCase("item_grid_area", itemGridArea),
            new TestCase("absolute_grid_area_named_span", absoluteGridAreaNamedSpan),
            new TestCase("rtl_line_names_are_logical_order", rtlLineNamesAreLogicalOrder),
            #end
        ];
    }

    #if taffy_detailed_grid_tests

    static function getDetailedGridInfo(tree:TaffyTree<TestNodeContext>, node:NodeId):DetailedGridInfo {
        return switch tree.detailedLayoutInfo(node) {
            case Grid(info): info;
            case _: throw "expected detailed grid info";
        }
    }

    static function sized(width:Float, height:Float):SizeOf<Dimension> {
        return new SizeOf<Dimension>(Dimension.length(width), Dimension.length(height));
    }

    static function lineAuto():LineOf<GridPlacement> {
        return placement(Auto, Auto);
    }

    static function assertNames(actual:Array<String>, expected:Array<String>, ?pos:haxe.PosInfos) {
        Assert.eqStr(actual.join(","), expected.join(","), null, pos);
    }

    static function assertItemGridArea(info:DetailedGridInfo, index:Int, x:Float, y:Float, width:Float, height:Float, ?pos:haxe.PosInfos) {
        final area = info.itemGridArea(index);
        Assert.isTrue(area != null, 'item $index has no grid area', pos);
        Assert.eqPoint(area.location, x, y, null, pos);
        Assert.eqSize(area.size, width, height, null, pos);
    }

    static function noLineNames() {
        final tree = newTestTree();
        final child = tree.newLeaf(st(s -> {}));
        final root = tree.newWithChildren(st(s -> {
            s.display = Grid;
            s.size = sized(100.0, 50.0);
            s.gridTemplateColumns = tracks("40px 60px");
            s.gridTemplateRows = tracks("50px");
        }), [child]);
        tree.computeLayout(root, definite(100.0, 50.0));

        final info = getDetailedGridInfo(tree, root);
        Assert.isTrue(info.columns.lineNames.isEmpty());
        Assert.isTrue(info.rows.lineNames.isEmpty());
        Assert.eqInt(info.columns.iterLineNames().length, 0);
        Assert.eqStr(info.gridTemplateColumns(1.0), "40px 60px");
        Assert.eqStr(info.gridTemplateRows(1.0), "50px");
    }

    static function zoomedTrackList() {
        final tree = newTestTree();
        final child = tree.newLeaf(st(s -> {}));
        final root = tree.newWithChildren(st(s -> {
            s.display = Grid;
            s.gridTemplateColumns = tracks("80px 120px");
            s.gridTemplateRows = tracks("100px");
        }), [child]);
        tree.computeLayout(root, definite(200.0, 100.0));

        final info = getDetailedGridInfo(tree, root);
        Assert.eqStr(info.gridTemplateColumns(2.0), "40px 60px");
        Assert.eqStr(info.gridTemplateRows(2.0), "50px");
    }

    static function templateAndAreaLineNames() {
        final tree = newTestTree();
        final child = tree.newLeaf(st(s -> {}));
        final root = tree.newWithChildren(st(s -> {
            s.display = Grid;
            s.size = sized(100.0, 50.0);
            s.gridTemplateColumns = tracks("40px 60px");
            s.gridTemplateColumnNames = [["full-start"], ["main-start"], ["main-end", "full-end"]];
            s.gridTemplateRows = tracks("50px");
            s.gridTemplateAreas = new GridTemplateAreas([new GridTemplateArea("hero", 1, 2, 1, 3)], 1, 2);
        }), [child]);
        tree.computeLayout(root, definite(100.0, 50.0));

        final info = getDetailedGridInfo(tree, root);
        final columnLines = info.columns.iterLineNames();
        Assert.eqInt(columnLines.length, 3);
        assertNames(columnLines[0], ["full-start"]);
        assertNames(columnLines[1], ["main-start"]);
        assertNames(columnLines[2], ["main-end", "full-end"]);
        assertNames(info.columns.namesForLine(1), ["main-start"]);

        // Implicit `<area>-start`/`<area>-end` names are not part of the resolved track list
        Assert.eqInt(info.rows.iterLineNames().length, 0);

        Assert.eqStr(info.gridTemplateColumns(1.0), "[full-start] 40px [main-start] 60px [main-end full-end]");
        Assert.eqStr(info.gridTemplateRows(1.0), "50px");

        // ...but they still resolve for placement
        Assert.eqRect(info.resolveAbsoluteGridArea(
            placement(Line(1), Line(2)),
            placement(NamedLine("hero-start", 1), NamedLine("hero-end", 1)),
            Ltr,
            new Rect(0.0, 100.0, 0.0, 50.0)
        ), new Rect(0.0, 100.0, 0.0, 50.0));
    }

    static function repeatExpansionLineNames() {
        final tree = newTestTree();
        final child = tree.newLeaf(st(s -> {}));
        final root = tree.newWithChildren(st(s -> {
            s.display = Grid;
            s.size = sized(100.0, 50.0);
            s.gridTemplateColumns = tracks("repeat(2, [col-start] 50px [col-end])");
            s.gridTemplateColumnNames = [["outer-start"], ["outer-end"]];
            s.gridTemplateRows = tracks("50px");
        }), [child]);
        tree.computeLayout(root, definite(100.0, 50.0));

        final info = getDetailedGridInfo(tree, root);
        final columnLines = info.columns.iterLineNames();
        Assert.eqInt(columnLines.length, 3);
        // First repetition's end line collapses with the second repetition's start line,
        // and the last repetition's end line collapses with the following template name set
        assertNames(columnLines[0], ["outer-start", "col-start"]);
        assertNames(columnLines[1], ["col-end", "col-start"]);
        assertNames(columnLines[2], ["col-end", "outer-end"]);

        Assert.eqStr(info.gridTemplateColumns(1.0), "[outer-start col-start] 50px [col-end col-start] 50px [col-end outer-end]");
    }

    static function implicitTracksShiftLineNames() {
        final tree = newTestTree();
        final child = tree.newLeaf(st(s -> {
            s.gridColumn = placement(Line(-3), Auto);
        }));
        final root = tree.newWithChildren(st(s -> {
            s.display = Grid;
            s.size = sized(100.0, 50.0);
            s.gridTemplateColumns = tracks("50px");
            s.gridTemplateColumnNames = [["a"], ["b"]];
            s.gridTemplateRows = tracks("50px");
        }), [child]);
        tree.computeLayout(root, definite(100.0, 50.0));

        final info = getDetailedGridInfo(tree, root);
        Assert.eqInt(info.columns.negativeImplicitTracks, 1);
        final columnLines = info.columns.iterLineNames();
        // One leading implicit track: its lines are unnamed, explicit names shift by one
        Assert.eqInt(columnLines.length, 3);
        Assert.eqInt(columnLines[0].length, 0);
        assertNames(columnLines[1], ["a"]);
        assertNames(columnLines[2], ["b"]);
        final firstTrack = info.columns.positions[0];
        final expected = '${firstTrack.end - firstTrack.start}px [a] 50px [b]';
        Assert.eqStr(info.gridTemplateColumns(1.0), expected);
    }

    static function itemGridArea() {
        final tree = newTestTree();
        final childA = tree.newLeaf(st(s -> {}));
        final childB = tree.newLeaf(st(s -> {
            s.gridRow = gridLine(2);
            s.gridColumn = placement(Line(1), Line(3));
        }));
        final container = tree.newWithChildren(st(s -> {
            s.display = Grid;
            s.gridTemplateColumns = tracks("40px 60px");
            s.gridTemplateRows = tracks("50px 30px");
            s.gap = new SizeOf<LengthPercentage>(length(10.0), length(10.0));
            s.padding = rectLP(length(5.0), length(5.0), length(5.0), length(5.0));
        }), [childA, childB]);

        tree.computeLayout(container, MAX_CONTENT);
        final info = getDetailedGridInfo(tree, container);

        // child_a is auto-placed into row 1 / column 1
        assertItemGridArea(info, 0, 5.0, 5.0, 40.0, 50.0);
        // child_b spans both columns in row 2
        assertItemGridArea(info, 1, 5.0, 65.0, 110.0, 30.0);
        // out of bounds index
        Assert.isTrue(info.itemGridArea(2) == null);

        final paddingBox = new Rect(0.0, 120.0, 0.0, 100.0);
        Assert.eqRect(info.resolveAbsoluteGridArea(placement(Line(1), Line(3)), placement(Line(1), Line(3)), Ltr, paddingBox),
            new Rect(5.0, 115.0, 5.0, 95.0));
        Assert.eqRect(info.resolveAbsoluteGridArea(lineAuto(), placement(Auto, Line(2)), Ltr, paddingBox),
            new Rect(0.0, 45.0, 0.0, 100.0));
        Assert.eqRect(info.resolveAbsoluteGridArea(lineAuto(), placement(Line(-1), Auto), Ltr, paddingBox),
            new Rect(115.0, 120.0, 0.0, 100.0));
        // An unknown named line resolves to the first implicit line past the explicit grid,
        // which (being outside the grid) falls back to the padding edge. The resulting
        // start/end pair is swapped, so this is equivalent to `2 / <padding-end>`.
        Assert.eqRect(info.resolveAbsoluteGridArea(lineAuto(), placement(NamedLine("missing", 1), Line(2)), Ltr, paddingBox),
            new Rect(55.0, 120.0, 0.0, 100.0));
        Assert.eqRect(info.resolveAbsoluteGridArea(lineAuto(), placement(Span(2), Span(3)), Ltr, paddingBox),
            new Rect(0.0, 120.0, 0.0, 100.0));
    }

    static function absoluteGridAreaNamedSpan() {
        final tree = newTestTree();
        final child = tree.newLeaf(st(s -> {}));
        final root = tree.newWithChildren(st(s -> {
            s.display = Grid;
            s.size = sized(90.0, 50.0);
            s.gridTemplateColumns = tracks("30px 30px 30px");
            s.gridTemplateColumnNames = [["a"], ["b"], ["b"], ["c"]];
            s.gridTemplateRows = tracks("50px");
        }), [child]);
        tree.computeLayout(root, definite(90.0, 50.0));

        final info = getDetailedGridInfo(tree, root);
        final paddingBox = new Rect(0.0, 90.0, 0.0, 50.0);
        Assert.eqRect(info.resolveAbsoluteGridArea(lineAuto(), placement(NamedLine("a", 1), NamedSpan("b", 2)), Ltr, paddingBox),
            new Rect(0.0, 60.0, 0.0, 50.0));
        Assert.eqRect(info.resolveAbsoluteGridArea(lineAuto(), placement(NamedLine("b", 2), NamedLine("c", 1)), Ltr, paddingBox),
            new Rect(60.0, 90.0, 0.0, 50.0));
    }

    static function rtlLineNamesAreLogicalOrder() {
        final tree = newTestTree();
        final child = tree.newLeaf(st(s -> {}));
        final root = tree.newWithChildren(st(s -> {
            s.display = Grid;
            s.direction = Rtl;
            s.size = sized(100.0, 50.0);
            s.gridTemplateColumns = tracks("40px 60px");
            s.gridTemplateColumnNames = [["a"], ["b"], ["c"]];
            s.gridTemplateRows = tracks("50px");
        }), [child]);
        tree.computeLayout(root, definite(100.0, 50.0));

        final info = getDetailedGridInfo(tree, root);
        final columnLines = info.columns.iterLineNames();
        // Tracks and line names are in logical order regardless of direction
        assertNames(columnLines[0], ["a"]);
        assertNames(columnLines[1], ["b"]);
        assertNames(columnLines[2], ["c"]);
        Assert.eqStr(info.gridTemplateColumns(1.0), "[a] 40px [b] 60px [c]");

        // Positions hold physical coordinates: logical track 1 is physically rightmost in RTL
        Assert.eq(info.columns.positions[0].start, 60.0);
        Assert.eq(info.columns.positions[0].end, 100.0);
        Assert.eq(info.columns.positions[1].start, 0.0);
        Assert.eq(info.columns.positions[1].end, 60.0);
        // item_grid_area resolves the physical rectangle of the (auto-placed) item's grid area
        assertItemGridArea(info, 0, 60.0, 0.0, 40.0, 50.0);
        final paddingBox = new Rect(0.0, 100.0, 0.0, 50.0);
        Assert.eqRect(info.resolveAbsoluteGridArea(lineAuto(), placement(Line(1), Line(2)), Rtl, paddingBox),
            new Rect(60.0, 100.0, 0.0, 50.0));
        Assert.eqRect(info.resolveAbsoluteGridArea(lineAuto(), placement(NamedLine("a", 1), NamedLine("b", 1)), Rtl, paddingBox),
            new Rect(60.0, 100.0, 0.0, 50.0));
        Assert.eqRect(info.resolveAbsoluteGridArea(lineAuto(), placement(Line(1), Auto), Rtl, paddingBox),
            new Rect(0.0, 100.0, 0.0, 50.0));
    }

    #end

}
