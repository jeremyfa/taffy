// Ported from taffy 0.15.0: src/style/grid.rs, src/style_helpers.rs, src/compute/grid/explicit_grid.rs, src/compute/grid/implicit_grid.rs,
// src/compute/grid/placement.rs, src/compute/grid/types/cell_occupancy.rs, src/compute/grid/types/named.rs, src/compute/grid/util/test_helpers.rs (tests)
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package;

import taffy.compute.grid.CellOccupancyMatrix;
import taffy.compute.grid.CellOccupancyMatrix.CellOccupancyState;
import taffy.compute.grid.CellOccupancyMatrix.OccupiedInterval;
import taffy.compute.grid.CellOccupancyMatrix.TrackIntervals;
import taffy.compute.grid.ExplicitGrid;
import taffy.compute.grid.ExplicitGrid.AutoRepeatStrategy;
import taffy.compute.grid.GenericGridPlacement;
import taffy.compute.grid.GenericGridPlacement.ItemPlacement;
import taffy.compute.grid.GenericGridPlacement.PlacementLine;
import taffy.compute.grid.GridCoordinates;
import taffy.compute.grid.GridCoordinates.IntLine;
import taffy.compute.grid.GridItem;
import taffy.compute.grid.GridTrack;
import taffy.compute.grid.GridTrack.GridTrackKind;
import taffy.compute.grid.ImplicitGrid;
import taffy.compute.grid.ImplicitGrid.GridSizeEstimate;
import taffy.compute.grid.NamedLineResolver;
import taffy.compute.grid.Placement;
import taffy.compute.grid.TrackCounts;
import taffy.geometry.AbsoluteAxis;
import taffy.geometry.LineOf;
import taffy.geometry.RectOf;
import taffy.geometry.SizeOf;
import taffy.geometry.SizeOpt;
import taffy.util.OptionalFloat;
import taffy.style.AlignItems;
import taffy.style.Dimension;
import taffy.style.Display;
import taffy.style.GridAutoFlow;
import taffy.style.GridHelpers;
import taffy.style.GridParsing;
import taffy.style.GridPlacement;
import taffy.style.GridTemplateArea;
import taffy.style.GridTemplateAreas;
import taffy.style.GridTemplateComponent;
import taffy.style.GridTemplateRepetition;
import taffy.style.LengthPercentage;
import taffy.style.LengthPercentageAuto;
import taffy.style.MaxTrackSizingFunction;
import taffy.style.MaxTrackSizingFunction.ExpandedMaxTrackSizingFunction;
import taffy.style.MinTrackSizingFunction;
import taffy.style.MinTrackSizingFunction.ExpandedMinTrackSizingFunction;
import taffy.style.RepetitionCount;
import taffy.style.RepetitionCount.RepetitionCountTools;
import taffy.style.Style;
import taffy.style.TrackSizingFunction;
import taffy.tree.NodeId;

/**
 * Unit tests of the CSS Grid style types and algorithm (the `#[cfg(test)]` tests of the grid modules)
 */
class GridUnitTests {

    static final I16_MAX = 32767;
    static final I16_MIN = -32768;
    static final U16_MAX = 65535;

    public static function run():{passed:Int, total:Int, failures:Array<String>} {
        final tests:Array<{name:String, fn:Void->Void}> = [
            // style/grid.rs
            {name: "grid_placement_parser_saturates_numeric_values", fn: gridPlacementParserSaturatesNumericValues},
            {name: "repetition_parser_saturates_numeric_values", fn: repetitionParserSaturatesNumericValues},
            {name: "repetition_track_count_saturates", fn: repetitionTrackCountSaturates},
            {name: "max_track_sizing_function_round_trips", fn: maxTrackSizingFunctionRoundTrips},
            {name: "min_track_sizing_function_round_trips", fn: minTrackSizingFunctionRoundTrips},
            // style_helpers.rs
            {name: "test_repeat_u16", fn: testRepeatU16},
            {name: "test_repeat_auto_fit_str", fn: testRepeatAutoFitStr},
            {name: "test_repeat_auto_fill_str", fn: testRepeatAutoFillStr},
            // explicit_grid.rs
            {name: "explicit_grid_sizing_no_repeats", fn: explicitGridSizingNoRepeats},
            {name: "explicit_grid_sizing_auto_fill_exact_fit", fn: explicitGridSizingAutoFillExactFit},
            {name: "explicit_grid_sizing_auto_fill_non_exact_fit", fn: explicitGridSizingAutoFillNonExactFit},
            {name: "explicit_grid_sizing_auto_fill_min_size_exact_fit", fn: explicitGridSizingAutoFillMinSizeExactFit},
            {name: "explicit_grid_sizing_auto_fill_min_size_non_exact_fit", fn: explicitGridSizingAutoFillMinSizeNonExactFit},
            {name: "explicit_grid_sizing_auto_fill_multiple_repeated_tracks", fn: explicitGridSizingAutoFillMultipleRepeatedTracks},
            {name: "explicit_grid_sizing_auto_fill_gap", fn: explicitGridSizingAutoFillGap},
            {name: "explicit_grid_sizing_no_defined_size", fn: explicitGridSizingNoDefinedSize},
            {name: "explicit_grid_sizing_mix_repeated_and_non_repeated", fn: explicitGridSizingMixRepeatedAndNonRepeated},
            {name: "explicit_grid_sizing_mix_with_padding", fn: explicitGridSizingMixWithPadding},
            {name: "auto_repeat_clamping_preserves_template_source_order", fn: autoRepeatClampingPreservesTemplateSourceOrder},
            {name: "explicit_track_count_accumulation_saturates", fn: explicitTrackCountAccumulationSaturates},
            {name: "test_initialize_grid_tracks", fn: testInitializeGridTracks},
            // implicit_grid.rs
            {name: "child_min_max_line_auto", fn: childMinMaxLineAuto},
            {name: "child_min_max_line_negative_track", fn: childMinMaxLineNegativeTrack},
            {name: "explicit_grid_sizing_with_children", fn: explicitGridSizingWithChildren},
            {name: "negative_implicit_grid_sizing", fn: negativeImplicitGridSizing},
            // placement.rs
            {name: "test_only_fixed_placement", fn: testOnlyFixedPlacement},
            {name: "test_placement_spanning_origin", fn: testPlacementSpanningOrigin},
            {name: "test_only_auto_placement_row_flow", fn: testOnlyAutoPlacementRowFlow},
            {name: "test_only_auto_placement_column_flow", fn: testOnlyAutoPlacementColumnFlow},
            {name: "test_oversized_item", fn: testOversizedItem},
            {name: "test_fixed_in_secondary_axis", fn: testFixedInSecondaryAxis},
            {name: "test_definite_in_secondary_axis_with_fully_definite_negative", fn: testDefiniteInSecondaryAxisWithFullyDefiniteNegative},
            {name: "test_dense_packing_algorithm", fn: testDensePackingAlgorithm},
            {name: "test_sparse_packing_algorithm", fn: testSparsePackingAlgorithm},
            {name: "test_auto_placement_in_negative_tracks", fn: testAutoPlacementInNegativeTracks},
            {name: "test_overlarge_placement_is_clamped", fn: testOverlargePlacementIsClamped},
            {name: "auto_placement_cursor_saturates_at_integer_bounds", fn: autoPlacementCursorSaturatesAtIntegerBounds},
            {name: "indefinite_spans_saturate_at_integer_bounds", fn: indefiniteSpansSaturateAtIntegerBounds},
            // types/cell_occupancy.rs
            {name: "paint_merges_touching_same_state_intervals", fn: paintMergesTouchingSameStateIntervals},
            {name: "paint_does_not_merge_different_states", fn: paintDoesNotMergeDifferentStates},
            {name: "paint_overwrites_overlapped_cells", fn: paintOverwritesOverlappedCells},
            {name: "paint_overwrites_multiple_intervals", fn: paintOverwritesMultipleIntervals},
            {name: "collision_extent_finds_extremal_occupied_cell", fn: collisionExtentFindsExtremalOccupiedCell},
            {name: "state_at_distinguishes_occupied_intervals_and_gaps", fn: stateAtDistinguishesOccupiedIntervalsAndGaps},
            {name: "definitely_placed_overwrite_hides_auto_placed_cells", fn: definitelyPlacedOverwriteHidesAutoPlacedCells},
            {name: "negative_expansion_preserves_occupancy", fn: negativeExpansionPreservesOccupancy},
            {name: "auto_placed_item_only_advances_cursor_in_first_secondary_track", fn: autoPlacedItemOnlyAdvancesCursorInFirstSecondaryTrack},
            {name: "cursors_survive_interval_merging_and_grid_expansion", fn: cursorsSurviveIntervalMergingAndGridExpansion},
            {name: "alternating_spans_merge_occupancy_and_skip_the_occupied_prefix", fn: alternatingSpansMergeOccupancyAndSkipTheOccupiedPrefix},
            {name: "collision_jump_returns_next_search_position", fn: collisionJumpReturnsNextSearchPosition},
            {name: "occupied_track_jump_skips_non_empty_tracks", fn: occupiedTrackJumpSkipsNonEmptyTracks},
            // types/named.rs
            {name: "extreme_missing_named_line_indices_do_not_overflow", fn: extremeMissingNamedLineIndicesDoNotOverflow},
            {name: "large_named_span_does_not_wrap_negative", fn: largeNamedSpanDoesNotWrapNegative},
            {name: "area_lines_saturate_when_converted_to_grid_lines", fn: areaLinesSaturateWhenConvertedToGridLines},
            {name: "bare_ident_resolves_to_area_edge", fn: bareIdentResolvesToAreaEdge},
            {name: "bare_ident_resolves_to_edge_of_implicitly_named_area", fn: bareIdentResolvesToEdgeOfImplicitlyNamedArea},
            {name: "area_edges_are_lines_named_with_start_and_end_suffixes", fn: areaEdgesAreLinesNamedWithStartAndEndSuffixes},
            {name: "area_edges_are_merged_with_explicitly_named_lines", fn: areaEdgesAreMergedWithExplicitlyNamedLines},
            {name: "area_edges_are_only_matched_by_bare_idents", fn: areaEdgesAreOnlyMatchedByBareIdents},
            {name: "area_edge_is_the_first_line_with_the_edge_name", fn: areaEdgeIsTheFirstLineWithTheEdgeName},
        ];

        final failures:Array<String> = [];
        var passed = 0;
        for (test in tests) {
            #if taffy_census
            final censusBefore = taffy.util.Census.optNaN + taffy.util.Census.optPosInf + taffy.util.Census.optNegInf;
            #end
            try {
                test.fn();
                passed++;
            }
            catch (e:Dynamic) {
                failures.push('grid ${test.name}: $e');
            }
            #if taffy_census
            final censusAfter = taffy.util.Census.optNaN + taffy.util.Census.optPosInf + taffy.util.Census.optNegInf;
            if (censusAfter != censusBefore)
                FileIO.println('  census: ' + (censusAfter - censusBefore) + ' NaN/inf optional values in grid ' + test.name);
            #end
        }
        return {passed: passed, total: tests.length, failures: failures};
    }

    // Assertion helpers

    static function check(cond:Bool, message:String):Void {
        if (!cond)
            throw message;
    }

    static function eqInt(actual:Int, expected:Int, message:String):Void {
        if (actual != expected)
            throw '$message: expected $expected, got $actual';
    }

    static function eqCounts(actual:TrackCounts, expected:TrackCounts, message:String):Void {
        if (!actual.equals(expected))
            throw '$message: expected $expected, got $actual';
    }

    static function eqIntervals(actual:Array<OccupiedInterval>, expected:Array<OccupiedInterval>):Void {
        var same = actual.length == expected.length;
        if (same) {
            for (i in 0...actual.length) {
                if (!actual[i].equals(expected[i]))
                    same = false;
            }
        }
        if (!same)
            throw 'intervals differ: expected ${describe(expected)}, got ${describe(actual)}';
    }

    static function describe(intervals:Array<OccupiedInterval>):String {
        return [for (i in intervals) '${i.start}..${i.end}:${i.state}'].join(", ");
    }

    static inline function interval(start:Int, end:Int, state:CellOccupancyState):OccupiedInterval {
        return new OccupiedInterval(start, end, state);
    }

    static inline function line(start:Int, end:Int):IntLine {
        return new IntLine(start, end);
    }

    // Test helpers (util/test_helpers.rs)

    /** `(width, height, cols, rows).into_grid()` */
    static function intoGrid(width:Float, height:Float, cols:Int, rows:Int):Style {
        final style = new Style();
        style.display = Display.Grid;
        style.size = new SizeOf<Dimension>(Dimension.length(width), Dimension.length(height));
        style.gridTemplateColumns = [for (_ in 0...cols) GridHelpers.single(GridHelpers.fr(1.0))];
        style.gridTemplateRows = [for (_ in 0...rows) GridHelpers.single(GridHelpers.fr(1.0))];
        return style;
    }

    /** `(col_start, col_end, row_start, row_end).into_grid_child()` */
    static function intoGridChild(colStart:GridPlacement, colEnd:GridPlacement, rowStart:GridPlacement, rowEnd:GridPlacement):Style {
        final style = new Style();
        style.display = Display.Grid;
        style.gridColumn = new LineOf<GridPlacement>(colStart, colEnd);
        style.gridRow = new LineOf<GridPlacement>(rowStart, rowEnd);
        return style;
    }

    /** Create a `GridItem` (with start alignment) for each `(index, style)` pair */
    static function gridItems(indexes:Array<Int>, styles:Array<Style>):Array<GridItem> {
        return [for (i in 0...styles.length) GridItem.newWithStyleAndOrder(new NodeId(indexes[i]), styles[i], AlignItems.START, AlignItems.START, indexes[i])];
    }

    /** Resolve the named lines in the `grid-row`/`grid-column` styles of the given child styles */
    static function resolveNamedLines(styles:Array<Style>, nameResolver:NamedLineResolver, explicitColCount:Int, explicitRowCount:Int):Array<ItemPlacement> {
        return [
            for (style in styles)
                new ItemPlacement(
                    PlacementLine.intoOriginZero(nameResolver.resolveColumnNames(style.gridColumn), explicitColCount),
                    PlacementLine.intoOriginZero(nameResolver.resolveRowNames(style.gridRow), explicitRowCount)
                )
        ];
    }

    static inline function gLine(index:Int):GridPlacement {
        return GridHelpers.line(index);
    }

    static inline function gSpan(span:Int):GridPlacement {
        return GridHelpers.span(span);
    }

    static inline function gAuto():GridPlacement {
        return GridPlacement.Auto;
    }

    static function preferredSize(style:Style):SizeOpt {
        return new SizeOpt(style.size.width.intoOption(), style.size.height.intoOption());
    }

    static function gridStyle(columns:Array<GridTemplateComponent>, rows:Array<GridTemplateComponent>):Style {
        final style = new Style();
        style.display = Display.Grid;
        style.gridTemplateColumns = columns;
        style.gridTemplateRows = rows;
        return style;
    }

    static inline function lengths(values:Array<Float>):Array<TrackSizingFunction> {
        return [for (v in values) GridHelpers.length(v)];
    }

    static function explicitSizes(style:Style, size:SizeOpt, strategy:AutoRepeatStrategy):Array<Int> {
        final col = ExplicitGrid.computeExplicitGridSizeInAxis(style, size.width, strategy, Horizontal);
        final row = ExplicitGrid.computeExplicitGridSizeInAxis(style, size.height, strategy, Vertical);
        return [col.autoRepetitionCount, col.trackCount, row.autoRepetitionCount, row.trackCount];
    }

    // style/grid.rs

    static function gridPlacementParserSaturatesNumericValues():Void {
        check(Type.enumEq(GridParsing.parseGridPlacement("32768"), GridPlacement.Line(I16_MAX)), "32768");
        check(Type.enumEq(GridParsing.parseGridPlacement("-32769"), GridPlacement.Line(I16_MIN)), "-32769");
        check(Type.enumEq(GridParsing.parseGridPlacement("span 65536"), GridPlacement.Span(U16_MAX)), "span 65536");
        switch GridParsing.parseGridPlacement("32768 line") {
            case NamedLine(_, n) if (n == I16_MAX):
            case other: throw '32768 line: got $other';
        }
        switch GridParsing.parseGridPlacement("span 65536 line") {
            case NamedSpan(_, n) if (n == U16_MAX):
            case other: throw 'span 65536 line: got $other';
        }
    }

    static function repetitionParserSaturatesNumericValues():Void {
        switch GridParsing.parseRepetitionCountString("65536") {
            case Count(n) if (n == U16_MAX):
            case other: throw '65536: got $other';
        }
        switch GridParsing.parseGridTemplateComponentString("repeat(65536, 1px)") {
            case Repeat(r):
                switch r.count {
                    case Count(n) if (n == U16_MAX):
                    case other: throw 'repeat count: got $other';
                }
            case other: throw 'repeat(65536, 1px): got $other';
        }
    }

    static function repetitionTrackCountSaturates():Void {
        final repetition = new GridTemplateRepetition(RepetitionCount.Count(1), [for (_ in 0...(U16_MAX + 1)) TrackSizingFunction.AUTO], []);
        eqInt(repetition.trackCount(), U16_MAX, "track count");
    }

    static function maxTrackSizingFunctionRoundTrips():Void {
        final cases = [
            MaxTrackSizingFunction.length(12.0),
            MaxTrackSizingFunction.percent(0.5),
            MaxTrackSizingFunction.auto(),
            MaxTrackSizingFunction.minContent(),
            MaxTrackSizingFunction.maxContent(),
            MaxTrackSizingFunction.fitContentPx(30.0),
            MaxTrackSizingFunction.fitContentPercent(0.75),
            MaxTrackSizingFunction.fr(2.0),
        ];
        for (value in cases)
            check(MaxTrackSizingFunction.fromExpanded(value.expand()).equals(value), 'round trip of $value');
        check(Type.enumEq(MaxTrackSizingFunction.fr(2.0).expand(), ExpandedMaxTrackSizingFunction.Fr(2.0)), "fr expand");
        check(Type.enumEq(MaxTrackSizingFunction.fitContentPx(30.0).expand(), ExpandedMaxTrackSizingFunction.FitContentPx(30.0)), "fit-content expand");
    }

    static function minTrackSizingFunctionRoundTrips():Void {
        final cases = [
            MinTrackSizingFunction.length(12.0),
            MinTrackSizingFunction.percent(0.5),
            MinTrackSizingFunction.auto(),
            MinTrackSizingFunction.minContent(),
            MinTrackSizingFunction.maxContent(),
        ];
        for (value in cases)
            check(MinTrackSizingFunction.fromExpanded(value.expand()).equals(value), 'round trip of $value');
        check(Type.enumEq(MinTrackSizingFunction.maxContent().expand(), ExpandedMinTrackSizingFunction.MaxContent), "max-content expand");
    }

    // style_helpers.rs

    static function checkRepeat(component:GridTemplateComponent, count:RepetitionCount):Void {
        switch component {
            case Repeat(r):
                check(RepetitionCountTools.equals(r.count, count), 'count: got ${r.count}');
                eqInt(r.tracks.length, 0, "tracks");
                eqInt(r.lineNames.length, 0, "line names");
            case other:
                throw 'expected a repeat, got $other';
        }
    }

    static function testRepeatU16():Void {
        checkRepeat(GridHelpers.repeatCount(123, []), Count(123));
    }

    static function testRepeatAutoFitStr():Void {
        checkRepeat(GridHelpers.repeat(RepetitionCountTools.fromString("auto-fit"), []), AutoFit);
    }

    static function testRepeatAutoFillStr():Void {
        checkRepeat(GridHelpers.repeat(RepetitionCountTools.fromString("auto-fill"), []), AutoFill);
    }

    // explicit_grid.rs

    static function explicitGridSizingNoRepeats():Void {
        final gridStyle = intoGrid(600.0, 600.0, 2, 4);
        final r = explicitSizes(gridStyle, preferredSize(gridStyle), MaxRepetitionsThatDoNotOverflow);
        eqInt(r[1], 2, "col_count");
        eqInt(r[3], 4, "row_count");
        eqInt(r[0], 0, "auto_col_reps");
        eqInt(r[2], 0, "auto_row_reps");
    }

    static function explicitGridSizingAutoFillExactFit():Void {
        final style = gridStyle([GridHelpers.repeat(AutoFill, lengths([40.0]))], [GridHelpers.repeat(AutoFill, lengths([20.0]))]);
        style.size = new SizeOf<Dimension>(Dimension.length(120.0), Dimension.length(80.0));
        final r = explicitSizes(style, preferredSize(style), MaxRepetitionsThatDoNotOverflow);
        eqInt(r[1], 3, "col_count");
        eqInt(r[3], 4, "row_count");
        eqInt(r[0], 3, "auto_col_reps");
        eqInt(r[2], 4, "auto_row_reps");
    }

    static function explicitGridSizingAutoFillNonExactFit():Void {
        final style = gridStyle([GridHelpers.repeat(AutoFill, lengths([40.0]))], [GridHelpers.repeat(AutoFill, lengths([20.0]))]);
        style.size = new SizeOf<Dimension>(Dimension.length(140.0), Dimension.length(90.0));
        final r = explicitSizes(style, preferredSize(style), MaxRepetitionsThatDoNotOverflow);
        eqInt(r[1], 3, "col_count");
        eqInt(r[3], 4, "row_count");
        eqInt(r[0], 3, "auto_col_reps");
        eqInt(r[2], 4, "auto_row_reps");
    }

    static function explicitGridSizingAutoFillMinSizeExactFit():Void {
        final style = gridStyle([GridHelpers.repeat(AutoFill, lengths([40.0]))], [GridHelpers.repeat(AutoFill, lengths([20.0]))]);
        style.minSize = new SizeOf<LengthPercentageAuto>(LengthPercentageAuto.length(120.0), LengthPercentageAuto.length(80.0));
        final r = explicitSizes(style, new SizeOpt(OptionalFloat.some(120.0), OptionalFloat.some(80.0)), MinRepetitionsThatDoOverflow);
        eqInt(r[1], 3, "col_count");
        eqInt(r[3], 4, "row_count");
        eqInt(r[0], 3, "auto_col_reps");
        eqInt(r[2], 4, "auto_row_reps");
    }

    static function explicitGridSizingAutoFillMinSizeNonExactFit():Void {
        final style = gridStyle([GridHelpers.repeat(AutoFill, lengths([40.0]))], [GridHelpers.repeat(AutoFill, lengths([20.0]))]);
        style.minSize = new SizeOf<LengthPercentageAuto>(LengthPercentageAuto.length(140.0), LengthPercentageAuto.length(90.0));
        final r = explicitSizes(style, new SizeOpt(OptionalFloat.some(140.0), OptionalFloat.some(90.0)), MinRepetitionsThatDoOverflow);
        eqInt(r[1], 4, "col_count");
        eqInt(r[3], 5, "row_count");
        eqInt(r[0], 4, "auto_col_reps");
        eqInt(r[2], 5, "auto_row_reps");
    }

    static function explicitGridSizingAutoFillMultipleRepeatedTracks():Void {
        final style = gridStyle([GridHelpers.repeat(AutoFill, lengths([40.0, 20.0]))], [GridHelpers.repeat(AutoFill, lengths([20.0, 10.0]))]);
        style.size = new SizeOf<Dimension>(Dimension.length(140.0), Dimension.length(100.0));
        final r = explicitSizes(style, preferredSize(style), MaxRepetitionsThatDoNotOverflow);
        eqInt(r[1], 4, "col_count"); // 2 repetitions * 2 repeated tracks = 4 tracks in total
        eqInt(r[3], 6, "row_count"); // 3 repetitions * 2 repeated tracks = 4 tracks in total
        eqInt(r[0], 2, "auto_col_reps");
        eqInt(r[2], 3, "auto_row_reps");
    }

    static function explicitGridSizingAutoFillGap():Void {
        final style = gridStyle([GridHelpers.repeat(AutoFill, lengths([40.0]))], [GridHelpers.repeat(AutoFill, lengths([20.0]))]);
        style.size = new SizeOf<Dimension>(Dimension.length(140.0), Dimension.length(100.0));
        style.gap = new SizeOf<LengthPercentage>(LengthPercentage.length(20.0), LengthPercentage.length(20.0));
        final r = explicitSizes(style, preferredSize(style), MaxRepetitionsThatDoNotOverflow);
        eqInt(r[1], 2, "col_count"); // 2 tracks + 1 gap
        eqInt(r[3], 3, "row_count"); // 3 tracks + 2 gaps
        eqInt(r[0], 2, "auto_col_reps");
        eqInt(r[2], 3, "auto_row_reps");
    }

    static function explicitGridSizingNoDefinedSize():Void {
        final style = gridStyle([GridHelpers.repeat(AutoFill, [GridHelpers.length(40.0), GridHelpers.percent(0.5), GridHelpers.length(20.0)])],
            [GridHelpers.repeat(AutoFill, lengths([20.0]))]);
        style.gap = new SizeOf<LengthPercentage>(LengthPercentage.length(20.0), LengthPercentage.length(20.0));
        final r = explicitSizes(style, preferredSize(style), MinRepetitionsThatDoOverflow);
        eqInt(r[1], 3, "col_count");
        eqInt(r[3], 1, "row_count");
        eqInt(r[0], 1, "auto_col_reps");
        eqInt(r[2], 1, "auto_row_reps");
    }

    static function explicitGridSizingMixRepeatedAndNonRepeated():Void {
        final style = gridStyle([GridHelpers.single(GridHelpers.length(20.0)), GridHelpers.repeat(AutoFill, lengths([40.0]))],
            [GridHelpers.single(GridHelpers.length(40.0)), GridHelpers.repeat(AutoFill, lengths([20.0]))]);
        style.size = new SizeOf<Dimension>(Dimension.length(140.0), Dimension.length(100.0));
        style.gap = new SizeOf<LengthPercentage>(LengthPercentage.length(20.0), LengthPercentage.length(20.0));
        final r = explicitSizes(style, preferredSize(style), MaxRepetitionsThatDoNotOverflow);
        eqInt(r[1], 3, "col_count"); // 3 tracks + 2 gaps
        eqInt(r[3], 2, "row_count"); // 2 tracks + 1 gap
        eqInt(r[0], 2, "auto_col_reps");
        eqInt(r[2], 1, "auto_row_reps");
    }

    static function explicitGridSizingMixWithPadding():Void {
        final style = gridStyle([GridHelpers.repeat(AutoFill, lengths([20.0]))], [GridHelpers.repeat(AutoFill, lengths([20.0]))]);
        style.size = new SizeOf<Dimension>(Dimension.length(120.0), Dimension.length(120.0));
        style.padding = new RectOf<LengthPercentage>(LengthPercentage.length(10.0), LengthPercentage.length(10.0), LengthPercentage.length(20.0),
            LengthPercentage.length(20.0));
        final r = explicitSizes(style, new SizeOpt(OptionalFloat.some(100.0), OptionalFloat.some(80.0)), MaxRepetitionsThatDoNotOverflow);
        eqInt(r[1], 5, "col_count"); // 40px horizontal padding
        eqInt(r[3], 4, "row_count"); // 20px vertical padding
        eqInt(r[0], 5, "auto_col_reps");
        eqInt(r[2], 4, "auto_row_reps");
    }

    static function autoRepeatClampingPreservesTemplateSourceOrder():Void {
        final autoRepeatFirst = gridStyle([GridHelpers.repeat(AutoFill, lengths([2.0])), GridHelpers.repeatCount(10000, lengths([37.0]))], []);
        final first = ExplicitGrid.computeExplicitGridSizeInAxis(autoRepeatFirst, OptionalFloat.NONE, MaxRepetitionsThatDoNotOverflow, Horizontal);
        eqInt(first.autoRepetitionCount, 1, "repetitions");
        eqInt(first.trackCount, 10000, "track count");
        final tracks:Array<GridTrack> = [];
        ExplicitGrid.initializeGridTracks(tracks, TrackCounts.fromRaw(0, first.trackCount, 0), autoRepeatFirst, Horizontal, first.autoRepetitionCount,
            null);
        check(tracks[1].minTrackSizingFunction.equals(MinTrackSizingFunction.length(2.0)), "tracks[1]");
        check(tracks[3].minTrackSizingFunction.equals(MinTrackSizingFunction.length(37.0)), "tracks[3]");

        final autoRepeatLast = gridStyle([GridHelpers.repeatCount(10000, lengths([37.0])), GridHelpers.repeat(AutoFill, lengths([2.0]))], []);
        final last = ExplicitGrid.computeExplicitGridSizeInAxis(autoRepeatLast, OptionalFloat.NONE, MaxRepetitionsThatDoNotOverflow, Horizontal);
        eqInt(last.autoRepetitionCount, 0, "repetitions (last)");
        eqInt(last.trackCount, 10000, "track count (last)");
    }

    static function explicitTrackCountAccumulationSaturates():Void {
        final repeatedTracks = [for (_ in 0...32769) GridHelpers.length(1.0)];
        final style = gridStyle([
            GridHelpers.repeatCount(U16_MAX, repeatedTracks.copy()),
            GridHelpers.repeatCount(U16_MAX, repeatedTracks),
            GridHelpers.repeat(AutoFill, lengths([1.0]))
        ], []);
        final result = ExplicitGrid.computeExplicitGridSizeInAxis(style, OptionalFloat.NONE, MaxRepetitionsThatDoNotOverflow, Horizontal);
        eqInt(result.autoRepetitionCount, 0, "repetitions");
        eqInt(result.trackCount, 10000, "track count");
    }

    static function testInitializeGridTracks():Void {
        final minpx0 = MinTrackSizingFunction.length(0.0);
        final minpx20 = MinTrackSizingFunction.length(20.0);
        final minpx100 = MinTrackSizingFunction.length(100.0);

        final maxpx0 = MaxTrackSizingFunction.length(0.0);
        final maxpx20 = MaxTrackSizingFunction.length(20.0);
        final maxpx100 = MaxTrackSizingFunction.length(100.0);

        final minAuto = MinTrackSizingFunction.AUTO;
        final maxAuto = MaxTrackSizingFunction.AUTO;

        // Setup test
        final style = gridStyle([
            GridHelpers.single(GridHelpers.length(100.0)),
            GridHelpers.single(GridHelpers.minmax(MinTrackSizingFunction.length(100.0), MaxTrackSizingFunction.fr(2.0))),
            GridHelpers.single(GridHelpers.fr(1.0))
        ], []);
        style.gap = new SizeOf<LengthPercentage>(LengthPercentage.length(20.0), LengthPercentage.length(20.0));
        style.gridAutoColumns = [GridHelpers.auto(), GridHelpers.length(100.0)];
        final trackCounts = new TrackCounts(3, style.gridTemplateColumns.length, 3);

        // Call function
        final tracks:Array<GridTrack> = [];
        ExplicitGrid.initializeGridTracks(tracks, trackCounts, style, Horizontal, 0, null);

        // Assertions
        final expected:Array<{kind:GridTrackKind, min:MinTrackSizingFunction, max:MaxTrackSizingFunction}> = [
            // Gutter
            {kind: Gutter, min: minpx0, max: maxpx0},
            // Negative implicit tracks
            {kind: Track, min: minpx100, max: maxpx100},
            {kind: Gutter, min: minpx20, max: maxpx20},
            {kind: Track, min: minAuto, max: maxAuto},
            {kind: Gutter, min: minpx20, max: maxpx20},
            {kind: Track, min: minpx100, max: maxpx100},
            {kind: Gutter, min: minpx20, max: maxpx20},
            // Explicit tracks
            {kind: Track, min: minpx100, max: maxpx100},
            {kind: Gutter, min: minpx20, max: maxpx20},
            {kind: Track, min: minpx100, max: MaxTrackSizingFunction.fr(2.0)}, // Note: separate min-max functions
            {kind: Gutter, min: minpx20, max: maxpx20},
            {kind: Track, min: minAuto, max: MaxTrackSizingFunction.fr(1.0)}, // Note: min sizing function of flex sizing functions is AUTO
            {kind: Gutter, min: minpx20, max: maxpx20},
            // Positive implicit tracks
            {kind: Track, min: minAuto, max: maxAuto},
            {kind: Gutter, min: minpx20, max: maxpx20},
            {kind: Track, min: minpx100, max: maxpx100},
            {kind: Gutter, min: minpx20, max: maxpx20},
            {kind: Track, min: minAuto, max: maxAuto},
            {kind: Gutter, min: minpx0, max: maxpx0},
        ];

        eqInt(tracks.length, expected.length, "Number of tracks doesn't match");

        for (idx in 0...expected.length) {
            final actual = tracks[idx];
            final e = expected[idx];
            check(actual.kind == e.kind, 'Track $idx (0-based index) kind');
            check(actual.minTrackSizingFunction.equals(e.min), 'Track $idx (0-based index) min: ${actual.minTrackSizingFunction}');
            check(actual.maxTrackSizingFunction.equals(e.max), 'Track $idx (0-based index) max: ${actual.maxTrackSizingFunction}');
        }
    }

    // implicit_grid.rs

    static function childMinMaxLineAuto():Void {
        final r = ImplicitGrid.childMinLineMaxLineSpan(PlacementLine.fromGridPlacementLineIgnoringNamed(new LineOf<GridPlacement>(gLine(5), gSpan(6)), 6));
        eqInt(r.min, 4, "min_col");
        eqInt(r.max, 10, "max_col");
        eqInt(r.span, 1, "span");
    }

    static function childMinMaxLineNegativeTrack():Void {
        final r = ImplicitGrid.childMinLineMaxLineSpan(PlacementLine.fromGridPlacementLineIgnoringNamed(new LineOf<GridPlacement>(gLine(-5), gSpan(3)), 6));
        eqInt(r.min, 2, "min_col");
        eqInt(r.max, 5, "max_col");
        eqInt(r.span, 1, "span");
    }

    static function estimate(explicitColCount:Int, explicitRowCount:Int, childStyles:Array<Style>):GridSizeEstimate {
        final nameResolver = new NamedLineResolver(Style.DEFAULT, 0, 0);
        nameResolver.setExplicitColumnCount(explicitColCount);
        nameResolver.setExplicitRowCount(explicitRowCount);
        final placements = resolveNamedLines(childStyles, nameResolver, explicitColCount, explicitRowCount);
        return ImplicitGrid.computeGridSizeEstimate(explicitColCount, explicitRowCount, placements);
    }

    static function explicitGridSizingWithChildren():Void {
        final childStyles = [
            intoGridChild(gLine(1), gSpan(2), gLine(2), gAuto()),
            intoGridChild(gLine(-4), gAuto(), gLine(-2), gAuto()),
        ];
        final r = estimate(6, 8, childStyles);
        eqCounts(r.columns, new TrackCounts(0, 6, 0), "inline");
        eqCounts(r.rows, new TrackCounts(0, 8, 0), "block");
    }

    static function negativeImplicitGridSizing():Void {
        final childStyles = [
            intoGridChild(gLine(-6), gSpan(2), gLine(-8), gAuto()),
            intoGridChild(gLine(4), gAuto(), gLine(3), gAuto()),
        ];
        final r = estimate(4, 4, childStyles);
        eqCounts(r.columns, new TrackCounts(1, 4, 0), "inline");
        eqCounts(r.rows, new TrackCounts(3, 4, 0), "block");
    }

    // placement.rs

    static function placementTestRunner(explicitColCount:Int, explicitRowCount:Int, ids:Array<Int>, styles:Array<Style>, expected:Array<Array<Int>>,
            expectedColCounts:TrackCounts, expectedRowCounts:TrackCounts, flow:GridAutoFlow):Void {
        // Setup test
        final nameResolver = new NamedLineResolver(Style.DEFAULT, 0, 0);
        nameResolver.setExplicitColumnCount(explicitColCount);
        nameResolver.setExplicitRowCount(explicitRowCount);
        final items = gridItems(ids, styles);
        final placements = resolveNamedLines(styles, nameResolver, explicitColCount, explicitRowCount);
        final estimatedSizes = ImplicitGrid.computeGridSizeEstimate(explicitColCount, explicitRowCount, placements);
        final cellOccupancyMatrix = CellOccupancyMatrix.withTrackCounts(estimatedSizes.columns, estimatedSizes.rows);

        // Run placement algorithm
        Placement.placeGridItems(cellOccupancyMatrix, items, placements, flow);

        // Assert that each item has been placed in the right location (items are in the same order as children)
        eqInt(items.length, styles.length, "item count");
        for (idx in 0...items.length) {
            final item = items[idx];
            eqInt(item.node, ids[idx], 'Item $idx node');
            final e = expected[idx];
            final actual = [item.column.start, item.column.end, item.row.start, item.row.end];
            check(actual[0] == e[0] && actual[1] == e[1] && actual[2] == e[2] && actual[3] == e[3], 'Item $idx (0-indexed): expected $e, got $actual');
        }

        // Assert that the correct number of implicit rows have been generated
        eqCounts(cellOccupancyMatrix.trackCounts(Vertical), expectedRowCounts, "row track counts");
        eqCounts(cellOccupancyMatrix.trackCounts(Horizontal), expectedColCounts, "column track counts");
    }

    static function testOnlyFixedPlacement():Void {
        placementTestRunner(2, 2, [1, 2, 3, 4], [
            intoGridChild(gLine(1), gAuto(), gLine(1), gAuto()),
            intoGridChild(gLine(-4), gAuto(), gLine(-3), gAuto()),
            intoGridChild(gLine(-3), gAuto(), gLine(-4), gAuto()),
            intoGridChild(gLine(3), gSpan(2), gLine(5), gAuto()),
        ], [[0, 1, 0, 1], [-1, 0, 0, 1], [0, 1, -1, 0], [2, 4, 4, 5]], new TrackCounts(1, 2, 2), new TrackCounts(1, 2, 3), Row);
    }

    static function testPlacementSpanningOrigin():Void {
        placementTestRunner(2, 2, [1, 2, 3, 4], [
            intoGridChild(gLine(-1), gLine(-1), gLine(-1), gLine(-1)),
            intoGridChild(gLine(-1), gSpan(2), gLine(-1), gSpan(2)),
            intoGridChild(gLine(-4), gLine(-4), gLine(-4), gLine(-4)),
            intoGridChild(gLine(-4), gSpan(2), gLine(-4), gSpan(2)),
        ], [[2, 3, 2, 3], [2, 4, 2, 4], [-1, 0, -1, 0], [-1, 1, -1, 1]], new TrackCounts(1, 2, 2), new TrackCounts(1, 2, 2), Row);
    }

    static function autoChildren(count:Int):Array<Style> {
        return [for (_ in 0...count) intoGridChild(gAuto(), gAuto(), gAuto(), gAuto())];
    }

    static function testOnlyAutoPlacementRowFlow():Void {
        placementTestRunner(2, 2, [1, 2, 3, 4, 5, 6, 7, 8], autoChildren(8),
            [[0, 1, 0, 1], [1, 2, 0, 1], [0, 1, 1, 2], [1, 2, 1, 2], [0, 1, 2, 3], [1, 2, 2, 3], [0, 1, 3, 4], [1, 2, 3, 4]],
            new TrackCounts(0, 2, 0), new TrackCounts(0, 2, 2), Row);
    }

    static function testOnlyAutoPlacementColumnFlow():Void {
        placementTestRunner(2, 2, [1, 2, 3, 4, 5, 6, 7, 8], autoChildren(8),
            [[0, 1, 0, 1], [0, 1, 1, 2], [1, 2, 0, 1], [1, 2, 1, 2], [2, 3, 0, 1], [2, 3, 1, 2], [3, 4, 0, 1], [3, 4, 1, 2]],
            new TrackCounts(0, 2, 2), new TrackCounts(0, 2, 0), Column);
    }

    static function testOversizedItem():Void {
        placementTestRunner(2, 2, [1], [intoGridChild(gSpan(5), gAuto(), gAuto(), gAuto())], [[0, 5, 0, 1]], new TrackCounts(0, 2, 3),
            new TrackCounts(0, 2, 0), Row);
    }

    static function testFixedInSecondaryAxis():Void {
        placementTestRunner(2, 2, [1, 2, 3, 4], [
            intoGridChild(gSpan(2), gAuto(), gLine(1), gAuto()),
            intoGridChild(gAuto(), gAuto(), gLine(2), gAuto()),
            intoGridChild(gAuto(), gAuto(), gLine(1), gAuto()),
            intoGridChild(gAuto(), gAuto(), gLine(4), gAuto()),
        ], [[0, 2, 0, 1], [0, 1, 1, 2], [2, 3, 0, 1], [0, 1, 3, 4]], new TrackCounts(0, 2, 1), new TrackCounts(0, 2, 2), Row);
    }

    static function testDefiniteInSecondaryAxisWithFullyDefiniteNegative():Void {
        placementTestRunner(2, 2, [2, 1, 3], [
            intoGridChild(gAuto(), gAuto(), gLine(2), gAuto()),
            intoGridChild(gLine(-4), gAuto(), gLine(2), gAuto()),
            intoGridChild(gAuto(), gAuto(), gLine(1), gAuto()),
        ], [[0, 1, 1, 2], [-1, 0, 1, 2], [-1, 0, 0, 1]], new TrackCounts(1, 2, 0), new TrackCounts(0, 2, 0), Row);
    }

    static function testDensePackingAlgorithm():Void {
        placementTestRunner(4, 4, [1, 2, 3], [
            intoGridChild(gLine(2), gAuto(), gLine(1), gAuto()), // Definitely positioned in column 2
            intoGridChild(gSpan(2), gAuto(), gAuto(), gAuto()), // Spans 2 columns, so positioned after item 1
            intoGridChild(gAuto(), gAuto(), gAuto(), gAuto()), // Spans 1 column, so should be positioned before item 1
        ], [[1, 2, 0, 1], [2, 4, 0, 1], [0, 1, 0, 1]], new TrackCounts(0, 4, 0), new TrackCounts(0, 4, 0), RowDense);
    }

    static function testSparsePackingAlgorithm():Void {
        placementTestRunner(4, 4, [1, 2, 3], [
            intoGridChild(gAuto(), gSpan(3), gAuto(), gAuto()), // Width 3
            intoGridChild(gAuto(), gSpan(3), gAuto(), gAuto()), // Width 3 (wraps to next row)
            intoGridChild(gAuto(), gSpan(1), gAuto(), gAuto()), // Width 1 (uses second row as we're already on it)
        ], [[0, 3, 0, 1], [0, 3, 1, 2], [3, 4, 1, 2]], new TrackCounts(0, 4, 0), new TrackCounts(0, 4, 0), Row);
    }

    static function testAutoPlacementInNegativeTracks():Void {
        placementTestRunner(2, 2, [1, 2, 3], [
            intoGridChild(gLine(-5), gAuto(), gLine(1), gAuto()), // Row 1. Definitely positioned in column -2
            intoGridChild(gAuto(), gAuto(), gLine(2), gAuto()), // Row 2. Auto positioned in column -2
            intoGridChild(gAuto(), gAuto(), gAuto(), gAuto()), // Row 1. Auto positioned in column -1
        ], [[-2, -1, 0, 1], [-2, -1, 1, 2], [-1, 0, 0, 1]], new TrackCounts(2, 2, 0), new TrackCounts(0, 2, 0), RowDense);
    }

    static function testOverlargePlacementIsClamped():Void {
        final explicitColCount = 9000;
        final explicitRowCount = 0;
        final styles = [intoGridChild(gLine(-19005), gAuto(), gAuto(), gAuto())];
        final nameResolver = new NamedLineResolver(Style.DEFAULT, 0, 0);
        nameResolver.setExplicitColumnCount(explicitColCount);
        nameResolver.setExplicitRowCount(explicitRowCount);
        final items = gridItems([0], styles);
        final placements = resolveNamedLines(styles, nameResolver, explicitColCount, explicitRowCount);
        final estimatedSizes = ImplicitGrid.computeGridSizeEstimate(explicitColCount, explicitRowCount, placements);
        final cellOccupancyMatrix = CellOccupancyMatrix.withTrackCounts(estimatedSizes.columns, estimatedSizes.rows);
        Placement.placeGridItems(cellOccupancyMatrix, items, placements, Row);
        check(items[0].column.equals(line(-10000, -9999)), 'column: got ${items[0].column}');
    }

    static function autoPlacementCursorSaturatesAtIntegerBounds():Void {
        eqInt(Placement.advancePosition(I16_MAX), I16_MAX, "advance");
    }

    static function indefiniteSpansSaturateAtIntegerBounds():Void {
        check(Placement.resolveIndefiniteGridSpan(I16_MAX, 1).equals(line(I16_MAX, I16_MAX)), "span");
    }

    // types/cell_occupancy.rs

    static function paintMergesTouchingSameStateIntervals():Void {
        final track = new TrackIntervals();
        track.paint(0, 2, AutoPlaced);
        track.paint(4, 6, AutoPlaced);
        track.paint(2, 4, AutoPlaced);
        eqIntervals(track.intervals, [interval(0, 6, AutoPlaced)]);
    }

    static function paintDoesNotMergeDifferentStates():Void {
        final track = new TrackIntervals();
        track.paint(0, 2, AutoPlaced);
        track.paint(2, 4, DefinitelyPlaced);
        eqIntervals(track.intervals, [interval(0, 2, AutoPlaced), interval(2, 4, DefinitelyPlaced)]);
    }

    static function paintOverwritesOverlappedCells():Void {
        final track = new TrackIntervals();
        track.paint(0, 6, AutoPlaced);
        track.paint(2, 4, DefinitelyPlaced);
        eqIntervals(track.intervals, [interval(0, 2, AutoPlaced), interval(2, 4, DefinitelyPlaced), interval(4, 6, AutoPlaced)]);

        // Painting over everything replaces all intervals
        track.paint(-1, 7, AutoPlaced);
        eqIntervals(track.intervals, [interval(-1, 7, AutoPlaced)]);
    }

    static function paintOverwritesMultipleIntervals():Void {
        final track = new TrackIntervals();
        track.paint(0, 2, AutoPlaced);
        track.paint(3, 5, DefinitelyPlaced);
        track.paint(6, 8, AutoPlaced);
        track.paint(1, 7, DefinitelyPlaced);
        eqIntervals(track.intervals, [interval(0, 1, AutoPlaced), interval(1, 7, DefinitelyPlaced), interval(7, 8, AutoPlaced)]);
    }

    static function collisionExtentFindsExtremalOccupiedCell():Void {
        final track = new TrackIntervals();
        track.paint(2, 4, AutoPlaced);
        track.paint(6, 8, DefinitelyPlaced);
        // The last cell of the last overlapping interval
        check(track.collisionExtent(0, 10) == 7, "0..10");
        check(track.collisionExtent(0, 7) == 7, "0..7");
        check(track.collisionExtent(0, 6) == 3, "0..6");
        check(track.collisionExtent(4, 6) == null, "4..6");
    }

    static function stateAtDistinguishesOccupiedIntervalsAndGaps():Void {
        final track = new TrackIntervals();
        track.paint(0, 2, DefinitelyPlaced);
        track.paint(2, 4, AutoPlaced);
        track.paint(6, 8, AutoPlaced);
        track.paint(8, 9, DefinitelyPlaced);
        check(track.stateAt(0) == DefinitelyPlaced, "0");
        check(track.stateAt(3) == AutoPlaced, "3");
        check(track.stateAt(5) == Unoccupied, "5");
        check(track.stateAt(7) == AutoPlaced, "7");
        check(track.stateAt(8) == DefinitelyPlaced, "8");
    }

    static function definitelyPlacedOverwriteHidesAutoPlacedCells():Void {
        final track = new TrackIntervals();
        track.paint(0, 4, AutoPlaced);
        track.paint(2, 4, DefinitelyPlaced);
        check(track.stateAt(1) == AutoPlaced, "1");
        check(track.stateAt(2) == DefinitelyPlaced, "2");
        check(track.stateAt(3) == DefinitelyPlaced, "3");
    }

    static function negativeExpansionPreservesOccupancy():Void {
        final matrix = CellOccupancyMatrix.withTrackCounts(TrackCounts.fromRaw(0, 2, 0), TrackCounts.fromRaw(0, 2, 0));
        matrix.markAreaAs(Horizontal, line(0, 1), line(0, 1), AutoPlaced);
        // Expand by marking an area in negative tracks
        matrix.markAreaAs(Horizontal, line(-2, -1), line(-1, 0), AutoPlaced);

        eqCounts(matrix.trackCounts(Horizontal), TrackCounts.fromRaw(2, 2, 0), "horizontal counts");
        eqCounts(matrix.trackCounts(Vertical), TrackCounts.fromRaw(1, 2, 0), "vertical counts");

        // Original cell still occupied at the same OriginZero coordinates
        check(!matrix.lineAreaIsUnoccupied(Horizontal, line(0, 1), line(0, 1)), "original cell");
        check(!matrix.lineAreaIsUnoccupied(Horizontal, line(-2, -1), line(-1, 0)), "new cell");
        check(matrix.lineAreaIsUnoccupied(Horizontal, line(-1, 0), line(0, 1)), "empty cell");

        // Matrix-index based queries account for the shifted origin
        check(matrix.columnIsOccupied(0), "column 0"); // OriginZero column -2
        check(!matrix.columnIsOccupied(1), "column 1"); // OriginZero column -1
        check(matrix.columnIsOccupied(2), "column 2"); // OriginZero column 0
        check(matrix.rowIsOccupied(0), "row 0"); // OriginZero row -1
        check(matrix.rowIsOccupied(1), "row 1"); // OriginZero row 0
        check(!matrix.rowIsOccupied(2), "row 2"); // OriginZero row 1
    }

    static function autoPlacedItemOnlyAdvancesCursorInFirstSecondaryTrack():Void {
        for (axis in [AbsoluteAxis.Horizontal, AbsoluteAxis.Vertical]) {
            final matrix = CellOccupancyMatrix.withTrackCounts(TrackCounts.fromRaw(0, 4, 0), TrackCounts.fromRaw(0, 4, 0));
            matrix.markAreaAs(axis, line(1, 3), line(1, 4), AutoPlaced);

            check(matrix.autoPlacementCursor(axis, 1) == 3, "cursor 1");
            check(matrix.autoPlacementCursor(axis, 2) == null, "cursor 2");
            check(matrix.autoPlacementCursor(axis, 3) == null, "cursor 3");

            check(!matrix.lineAreaIsUnoccupied(axis, line(1, 3), line(2, 4)), "occupied");
        }
    }

    static function cursorsSurviveIntervalMergingAndGridExpansion():Void {
        for (axis in [AbsoluteAxis.Horizontal, AbsoluteAxis.Vertical]) {
            final matrix = CellOccupancyMatrix.withTrackCounts(TrackCounts.fromRaw(0, 4, 0), TrackCounts.fromRaw(0, 4, 0));
            matrix.markAreaAs(axis, line(2, 4), line(1, 2), AutoPlaced);
            matrix.markAreaAs(axis, line(4, 8), line(0, 2), AutoPlaced);
            matrix.markAreaAs(axis, line(8, 10), line(1, 2), DefinitelyPlaced);
            matrix.markAreaAs(axis, line(-3, -1), line(-2, -1), AutoPlaced);
            matrix.markAreaAs(axis, line(12, 14), line(7, 8), AutoPlaced);
            matrix.markAreaAs(axis, line(0, 1), line(1, 2), AutoPlaced);

            check(matrix.autoPlacementCursor(axis, 1) == 4, "cursor 1");
            check(matrix.autoPlacementCursor(axis, 0) == 8, "cursor 0");
            check(matrix.autoPlacementCursor(axis, -2) == -1, "cursor -2");
            check(matrix.autoPlacementCursor(axis, 7) == 14, "cursor 7");
            for (track in [-3, -1, 2, 8])
                check(matrix.autoPlacementCursor(axis, track) == null, 'cursor $track');
        }
    }

    static function alternatingSpansMergeOccupancyAndSkipTheOccupiedPrefix():Void {
        for (axis in [AbsoluteAxis.Horizontal, AbsoluteAxis.Vertical]) {
            final matrix = CellOccupancyMatrix.withTrackCounts(TrackCounts.fromRaw(0, 0, 0), TrackCounts.fromRaw(0, 0, 0));
            for (i in 0...128)
                matrix.markAreaAs(axis, line(i, i + 1), line(i % 2, 2), AutoPlaced);

            final track = matrix.trackLists(axis.otherAxis())[1];
            eqIntervals(track.intervals, [interval(0, 128, AutoPlaced)]);
            check(matrix.lineAreaCollisionJump(axis, line(0, 1), line(1, 2)) == 128, "collision jump");
        }
    }

    static function collisionJumpReturnsNextSearchPosition():Void {
        final matrix = CellOccupancyMatrix.withTrackCounts(TrackCounts.fromRaw(0, 4, 0), TrackCounts.fromRaw(0, 4, 0));
        matrix.markAreaAs(Horizontal, line(1, 3), line(0, 1), AutoPlaced);

        // Jump past the end of the last colliding interval
        check(matrix.lineAreaCollisionJump(Horizontal, line(0, 2), line(0, 1)) == 3, "0..2");
        check(matrix.lineAreaCollisionJump(Horizontal, line(0, 4), line(0, 1)) == 3, "0..4");
        // No collision in a different row
        check(matrix.lineAreaCollisionJump(Horizontal, line(0, 4), line(1, 2)) == null, "different row");
    }

    static function occupiedTrackJumpSkipsNonEmptyTracks():Void {
        final matrix = CellOccupancyMatrix.withTrackCounts(TrackCounts.fromRaw(0, 4, 0), TrackCounts.fromRaw(0, 4, 0));
        matrix.markAreaAs(Horizontal, line(0, 1), line(1, 2), AutoPlaced);

        // Vertical (row) tracks: row 1 is occupied
        check(matrix.occupiedTrackJump(Vertical, line(0, 4)) == 2, "0..4");
        check(matrix.occupiedTrackJump(Vertical, line(2, 4)) == null, "2..4");
    }

    // types/named.rs

    static function resolver(explicitTrackCount:Int):NamedLineResolver {
        final r = new NamedLineResolver(Style.DEFAULT, 0, 0);
        r.setExplicitColumnCount(explicitTrackCount);
        return r;
    }

    static function resolvedStartLine(resolver:NamedLineResolver, placement:GridPlacement):Int {
        final resolved = resolver.resolveColumnNames(new LineOf<GridPlacement>(placement, Auto));
        if (!resolved.start.isLine())
            throw "expected a resolved line";
        return resolved.start.value;
    }

    static function resolvedEndLine(resolver:NamedLineResolver, placement:GridPlacement):Int {
        final resolved = resolver.resolveColumnNames(new LineOf<GridPlacement>(Auto, placement));
        if (!resolved.end.isLine())
            throw "expected a resolved line";
        return resolved.end.value;
    }

    static inline function namedLine(name:String, index:Int):GridPlacement {
        return GridPlacement.NamedLine(name, index);
    }

    static function extremeMissingNamedLineIndicesDoNotOverflow():Void {
        // Lines are clamped to the limits of the grid, in the same way as `GridLine::into_origin_zero_line`
        final r = resolver(10000);
        eqInt(resolvedStartLine(r, namedLine("missing", I16_MAX)), GridCoordinates.originZeroLineIntoGridLine(GridCoordinates.MAX_OZ_LINE, 10000), "max");
        eqInt(resolvedStartLine(r, namedLine("missing", I16_MIN)), GridCoordinates.originZeroLineIntoGridLine(GridCoordinates.MIN_OZ_LINE, 10000), "min");
    }

    static function largeNamedSpanDoesNotWrapNegative():Void {
        final r = resolver(10000);
        final resolved = r.resolveColumnNames(new LineOf<GridPlacement>(GridPlacement.Line(1), GridPlacement.NamedSpan("missing", U16_MAX)));
        check(resolved.end.isLine(), "expected a resolved line");
        eqInt(resolved.end.value, GridCoordinates.originZeroLineIntoGridLine(GridCoordinates.MAX_OZ_LINE, 10000), "end");
    }

    static function areaLinesSaturateWhenConvertedToGridLines():Void {
        final style = new Style();
        style.gridTemplateAreas = new GridTemplateAreas([new GridTemplateArea("area", 1, 2, U16_MAX, U16_MAX)], 1, U16_MAX);
        final r = new NamedLineResolver(style, 0, 0);
        eqInt(resolvedStartLine(r, namedLine("area-start", 1)), GridCoordinates.originZeroLineIntoGridLine(GridCoordinates.MAX_OZ_LINE, 0), "area-start");
        eqInt(resolvedStartLine(r, namedLine("area", 0)), GridCoordinates.originZeroLineIntoGridLine(GridCoordinates.MAX_OZ_LINE, 0), "area");
    }

    /**
     * A resolver for a grid with 4 explicit columns, the passed names for each of the 5 column lines, and a
     * single grid area named "area" which spans columns 2 and 3 (lines 2 to 4)
     */
    static function areaResolver(columnLineNames:Array<Array<String>>):NamedLineResolver {
        final style = new Style();
        style.gridTemplateColumnNames = columnLineNames;
        style.gridTemplateAreas = new GridTemplateAreas([new GridTemplateArea("area", 1, 2, 2, 4)], 1, 4);
        final r = new NamedLineResolver(style, 0, 0);
        r.setExplicitColumnCount(4);
        r.setExplicitRowCount(1);
        return r;
    }

    static function bareIdentResolvesToAreaEdge():Void {
        final r = areaResolver([[], [], [], [], []]);
        eqInt(resolvedStartLine(r, namedLine("area", 0)), 2, "start");
        eqInt(resolvedEndLine(r, namedLine("area", 0)), 4, "end");

        final rows = r.resolveRowNames(new LineOf<GridPlacement>(namedLine("area", 0), namedLine("area", 0)));
        check(rows.start.equals(GenericGridPlacement.line(1)), 'rows.start: ${rows.start}');
        check(rows.end.equals(GenericGridPlacement.line(2)), 'rows.end: ${rows.end}');
    }

    static function bareIdentResolvesToEdgeOfImplicitlyNamedArea():Void {
        final r = areaResolver([[], ["foo-start"], ["foo-start"], ["foo-end"], ["foo-end"]]);
        eqInt(resolvedStartLine(r, namedLine("foo", 0)), 2, "start");
        eqInt(resolvedEndLine(r, namedLine("foo", 0)), 4, "end");
    }

    static function areaEdgesAreLinesNamedWithStartAndEndSuffixes():Void {
        final r = areaResolver([[], [], [], [], []]);
        eqInt(resolvedStartLine(r, namedLine("area-start", 0)), 2, "area-start 0");
        eqInt(resolvedStartLine(r, namedLine("area-start", 1)), 2, "area-start 1");
        eqInt(resolvedStartLine(r, namedLine("area-end", 1)), 4, "area-end 1");
        eqInt(resolvedStartLine(r, namedLine("area-end", -1)), 4, "area-end -1");
        // There is only one such line, so the second is the first implicit line after the grid
        eqInt(resolvedStartLine(r, namedLine("area-start", 2)), 6, "area-start 2");
    }

    static function areaEdgesAreMergedWithExplicitlyNamedLines():Void {
        // The area's start edge is line 2 and its end edge is line 4
        final r = areaResolver([["area-start"], [], ["area-start"], ["area-end"], ["area-end"]]);
        eqInt(resolvedStartLine(r, namedLine("area-start", 1)), 1, "area-start 1");
        eqInt(resolvedStartLine(r, namedLine("area-start", 2)), 2, "area-start 2");
        eqInt(resolvedStartLine(r, namedLine("area-start", 3)), 3, "area-start 3");
        eqInt(resolvedStartLine(r, namedLine("area-start", -1)), 3, "area-start -1");
        eqInt(resolvedStartLine(r, namedLine("area-start", 4)), 6, "area-start 4");
        // The area's end edge has the same line number as an explicitly named line
        eqInt(resolvedStartLine(r, namedLine("area-end", 1)), 4, "area-end 1");
        eqInt(resolvedStartLine(r, namedLine("area-end", 2)), 5, "area-end 2");
        eqInt(resolvedStartLine(r, namedLine("area-end", 3)), 6, "area-end 3");
        // A bare ident matches the first line of the edge
        eqInt(resolvedStartLine(r, namedLine("area", 0)), 1, "area start");
        eqInt(resolvedEndLine(r, namedLine("area", 0)), 4, "area end");

        final span = r.resolveColumnNames(new LineOf<GridPlacement>(GridPlacement.Line(1), GridPlacement.NamedSpan("area-start", 2)));
        check(span.end.equals(GenericGridPlacement.line(3)), 'span end: ${span.end}');
    }

    static function areaEdgesAreOnlyMatchedByBareIdents():Void {
        final r = areaResolver([[], [], [], [], []]);
        // There are no lines named "area", so these resolve to implicit lines after the grid
        eqInt(resolvedStartLine(r, namedLine("area", 1)), 6, "area 1");
        eqInt(resolvedStartLine(r, namedLine("area", 2)), 7, "area 2");

        final span = r.resolveColumnNames(new LineOf<GridPlacement>(GridPlacement.Line(1), GridPlacement.NamedSpan("area", 0)));
        check(span.end.equals(GenericGridPlacement.line(6)), 'span end: ${span.end}');
    }

    static function areaEdgeIsTheFirstLineWithTheEdgeName():Void {
        // Explicit lines named after the area's edges which come after the area's generated lines (lines 2 and
        // 4) don't replace them
        var r = areaResolver([[], [], ["area-start"], [], ["area-end"]]);
        eqInt(resolvedStartLine(r, namedLine("area", 0)), 2, "area start");
        eqInt(resolvedEndLine(r, namedLine("area", 0)), 4, "area end");
        eqInt(resolvedStartLine(r, namedLine("area-start", 1)), 2, "area-start 1");
        eqInt(resolvedStartLine(r, namedLine("area-start", 2)), 3, "area-start 2");
        eqInt(resolvedStartLine(r, namedLine("area-end", 2)), 5, "area-end 2");

        // An explicit line with the same number as the generated line is the same line
        r = areaResolver([[], ["area-start"], [], ["area-end"], []]);
        eqInt(resolvedStartLine(r, namedLine("area", 0)), 2, "area start (2)");
        eqInt(resolvedEndLine(r, namedLine("area", 0)), 4, "area end (2)");
        eqInt(resolvedStartLine(r, namedLine("area-start", 1)), 2, "area-start 1 (2)");
        eqInt(resolvedStartLine(r, namedLine("area-start", 2)), 6, "area-start 2 (2)");
        eqInt(resolvedStartLine(r, namedLine("area-end", 2)), 6, "area-end 2 (2)");
    }

}
