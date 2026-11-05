// Ported from taffy 0.15.0 (repository): tests/xml.rs, tests/common/src/lib.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package;

import taffy.compute.Leaf;
import taffy.geometry.AbsoluteAxis;
import taffy.geometry.LineOf;
import taffy.geometry.PointOf;
import taffy.geometry.RectOf;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.geometry.SizeOpt;
import taffy.util.OptionalFloat;
import taffy.style.AlignContent;
import taffy.style.AlignItems;
import taffy.style.AvailableSpace;
import taffy.style.BoxSizing;
import taffy.style.Clear;
import taffy.style.Contain;
import taffy.style.CssFloat;
import taffy.style.Dimension;
import taffy.style.Direction;
import taffy.style.Display;
import taffy.style.FlexDirection;
import taffy.style.FlexWrap;
import taffy.style.GridAutoFlow;
import taffy.style.GridParsing;
import taffy.style.GridPlacement;
import taffy.style.LengthPercentage;
import taffy.style.LengthPercentageAuto;
import taffy.style.Overflow;
import taffy.style.Position;
import taffy.style.Style;
import taffy.style.TextAlign;
import taffy.tree.LayoutInput;
import taffy.tree.LayoutOutput;
import taffy.tree.NodeId;
import taffy.tree.TaffyTree;
import taffy.style.AvailableSpace.Definite;
import taffy.geometry.SizeAvail;

using StringTools;
using taffy.style.AvailableSpace;

/**
 * Writing mode of the Ahem text measure function
 */
enum abstract WritingMode(Int) {
    var Horizontal = 0;
    var Vertical = 1;
}

/**
 * Context of a test leaf node: some "Ahem" text where every glyph is a 10x10 square.
 * Lines are separated by zero width spaces (U+200B).
 */
class TestNodeContext {

    public var count:Int = 0;

    public final textContent:String;

    public final writingMode:WritingMode;

    public function new(textContent:String, writingMode:WritingMode) {
        this.textContent = textContent;
        this.writingMode = writingMode;
    }

    static inline final H_WIDTH:Float = 10.0;
    static inline final H_HEIGHT:Float = 10.0;

    public function measure(knownDimensions:SizeOpt, availableSpace:SizeAvail):Size {
        final inlineAxis:AbsoluteAxis = writingMode == Horizontal ? Horizontal : Vertical;
        final blockAxis = inlineAxis.otherAxis();
        final lines = textContent.split("​");
        if (lines.length == 0)
            return Size.ZERO;

        var minLineLength = 0;
        var maxLineLength = 0;
        for (line in lines) {
            final len = haxe.io.Bytes.ofString(line).length;
            if (len > minLineLength)
                minLineLength = len;
            maxLineLength += len;
        }

        final knownInline = knownDimensions.getAbs(inlineAxis);
        var inlineSize:Float = if (knownInline.isSome()) {
            knownInline.unwrap();
        }
        else {
            switch availableSpace.getAbs(inlineAxis) {
                case MinContent: minLineLength * H_WIDTH;
                case MaxContent: maxLineLength * H_WIDTH;
                case definite: Math.min(definite.definiteValue(), maxLineLength * H_WIDTH);
            }
        }
        inlineSize = Math.max(inlineSize, minLineLength * H_WIDTH);

        final knownBlock = knownDimensions.getAbs(blockAxis);
        final blockSize:Float = if (knownBlock.isSome()) {
            knownBlock.unwrap();
        }
        else {
            final inlineLineLength = Math.floor(inlineSize / H_WIDTH);
            var lineCount = 1;
            var currentLineLength = 0;
            for (line in lines) {
                final len = haxe.io.Bytes.ofString(line).length;
                if (currentLineLength + len > inlineLineLength) {
                    if (currentLineLength > 0)
                        lineCount++;
                    currentLineLength = len;
                }
                else {
                    currentLineLength += len;
                }
            }
            lineCount * H_HEIGHT;
        }

        return writingMode == Horizontal ? new Size(inlineSize, blockSize) : new Size(blockSize, inlineSize);
    }

}

/**
 * The expected (or computed) layout of a node
 */
class OutputNode {

    public var nodeId:NodeId;
    public var x:Float = 0;
    public var y:Float = 0;
    public var width:Float = 0;
    public var height:Float = 0;
    public var scrollWidth:Null<Float> = null;
    public var scrollHeight:Null<Float> = null;
    public var resolvedRows:Null<String> = null;
    public var resolvedColumns:Null<String> = null;
    public var children:Array<OutputNode> = [];

    public function new(nodeId:NodeId) {
        this.nodeId = nodeId;
    }

    public function matches(actual:OutputNode):Bool {
        if (nodeId != actual.nodeId)
            return false;
        if (Math.abs(x - actual.x) >= 0.1 || Math.abs(y - actual.y) >= 0.1)
            return false;
        if (Math.abs(width - actual.width) >= 0.1 || Math.abs(height - actual.height) >= 0.1)
            return false;
        if (scrollWidth != null && scrollHeight != null && actual.scrollWidth != null && actual.scrollHeight != null) {
            if (Math.abs(scrollWidth - actual.scrollWidth) >= 0.1 || Math.abs(scrollHeight - actual.scrollHeight) >= 0.1)
                return false;
        }
        if (resolvedRows != null && actual.resolvedRows != null && !XmlTests.trackListsMatch(resolvedRows, actual.resolvedRows))
            return false;
        if (resolvedColumns != null && actual.resolvedColumns != null && !XmlTests.trackListsMatch(resolvedColumns, actual.resolvedColumns))
            return false;
        if (children.length != actual.children.length)
            return false;
        for (i in 0...children.length) {
            if (!children[i].matches(actual.children[i]))
                return false;
        }
        return true;
    }

    public function writeTree(buf:StringBuf, indent:String):Void {
        buf.add('$indent[node ${(nodeId : Int)}] x: $x y: $y w: $width h: $height');
        if (scrollWidth != null)
            buf.add(' scroll_w: $scrollWidth scroll_h: $scrollHeight');
        if (resolvedRows != null)
            buf.add(' rows: $resolvedRows');
        if (resolvedColumns != null)
            buf.add(' columns: $resolvedColumns');
        buf.add("\n");
        for (child in children)
            child.writeTree(buf, indent + "    ");
    }

}

/**
 * The result of running one fixture
 */
class FixtureResult {

    public final passed:Bool;

    public final details:String;

    public function new(passed:Bool, details:String) {
        this.passed = passed;
        this.details = details;
    }

}

/**
 * Runs the XML fixtures of the taffy repository (tests/xml/<category>/<name>.xml), like tests/xml.rs
 */
class XmlTests {

    /**
     * When set (`--relayout-check` of the runner), every fixture is laid out twice more and must
     * give exactly the same layout: once again with every cache entry in place (cache hits all the
     * way down), and once with every node marked dirty
     */
    public static var relayoutCheck:Bool = false;

    /** When set (`--dump <file>` of the runner), receives the computed layout of every fixture */
    public static var dump:Null<StringBuf> = null;

    public static final CATEGORIES = ["block", "blockflex", "blockgrid", "contain", "flex", "float", "grid", "gridflex", "leaf"];

    /** Run a single fixture from its XML source */
    public static function runXmlTest(rawXml:String):FixtureResult {
        final doc = Xml.parse(rawXml);
        final root = doc.firstElement();
        final useRounding = parseBool(root.get("use-rounding"), true);
        final viewport = firstChildElement(root, "viewport");
        final input = firstChildElement(root, "input");
        final expectations = firstChildElement(root, "expectations");

        final availableSpace = new SizeAvail(
            parseOr(viewport.get("width"), AvailableSpaceTools.parse, MaxContent),
            parseOr(viewport.get("height"), AvailableSpaceTools.parse, MaxContent)
        );

        final tree = new TaffyTree<TestNodeContext>();
        if (useRounding)
            tree.enableRounding();
        else
            tree.disableRounding();

        final expected = constructTree(input.firstElement(), expectations.firstElement(), tree, null);
        final rootNodeId = expected.nodeId;

        tree.computeLayoutWithMeasure(rootNodeId, availableSpace, testMeasureFunction);

        final actual = getComputedExpectations(tree, rootNodeId);
        if (dump != null)
            actual.writeTree(dump, "  ");
        if (relayoutCheck) {
            final first = new StringBuf();
            actual.writeTree(first, "  ");
            tree.computeLayoutWithMeasure(rootNodeId, availableSpace, testMeasureFunction);
            final cached = new StringBuf();
            getComputedExpectations(tree, rootNodeId).writeTree(cached, "  ");
            markAllDirty(tree, rootNodeId);
            tree.computeLayoutWithMeasure(rootNodeId, availableSpace, testMeasureFunction);
            final dirty = new StringBuf();
            getComputedExpectations(tree, rootNodeId).writeTree(dirty, "  ");
            if (cached.toString() != first.toString())
                return new FixtureResult(false, "RELAYOUT WITH CACHE DIFFERS\n" + first.toString() + "CACHED\n" + cached.toString());
            if (dirty.toString() != first.toString())
                return new FixtureResult(false, "RELAYOUT AFTER MARKING DIRTY DIFFERS\n" + first.toString() + "DIRTY\n" + dirty.toString());
            // The same layout with the measure function given as an object
            markAllDirty(tree, rootNodeId);
            tree.computeLayoutWithMeasurer(rootNodeId, availableSpace, new TestMeasurer());
            final measurer = new StringBuf();
            getComputedExpectations(tree, rootNodeId).writeTree(measurer, "  ");
            if (measurer.toString() != first.toString())
                return new FixtureResult(false, "RELAYOUT WITH A MEASURER DIFFERS\n" + first.toString() + "MEASURER\n" + measurer.toString());
        }
        if (expected.matches(actual))
            return new FixtureResult(true, "");
        final buf = new StringBuf();
        buf.add("EXPECTED\n");
        expected.writeTree(buf, "  ");
        buf.add("ACTUAL\n");
        actual.writeTree(buf, "  ");
        return new FixtureResult(false, buf.toString());
    }

    static function markAllDirty(tree:TaffyTree<TestNodeContext>, node:NodeId):Void {
        tree.markDirty(node);
        for (child in tree.children(node))
            markAllDirty(tree, child);
    }

    /** The measure function used by the fixtures (`test_measure_function`) */
    public static function testMeasureFunction(inputs:LayoutInput, nodeId:NodeId, context:Null<TestNodeContext>, style:Style):LayoutOutput {
        return Leaf.computeLeafLayout(inputs, style, (knownDimensions, availableSpace) -> {
            if (knownDimensions.width.isSome() && knownDimensions.height.isSome())
                return new Size(knownDimensions.width.unwrap(), knownDimensions.height.unwrap());
            if (context == null)
                return new Size(knownDimensions.width.isSome() ? knownDimensions.width.unwrap() : 0.0, knownDimensions.height.isSome() ? knownDimensions.height.unwrap() : 0.0);
            context.count++;
            final computeSize = context.measure(knownDimensions, availableSpace);
            return new Size(
                knownDimensions.width.isSome() ? knownDimensions.width.unwrap() : computeSize.width,
                knownDimensions.height.isSome() ? knownDimensions.height.unwrap() : computeSize.height
            );
        });
    }

    static function constructTree(input:Xml, expectedX:Xml, tree:TaffyTree<TestNodeContext>, parent:Null<NodeId>):OutputNode {
        if (input.firstElement() != null) {
            final tnode = tree.newWithChildren(buildStyle(input), []);
            final expected = buildExpectations(expectedX, tnode);
            if (parent != null)
                tree.addChild(parent, tnode);
            final inputChildren = [for (c in input.elements()) c];
            final expectedChildren = [for (c in expectedX.elements()) c];
            for (i in 0...Std.int(Math.min(inputChildren.length, expectedChildren.length))) {
                expected.children.push(constructTree(inputChildren[i], expectedChildren[i], tree, tnode));
            }
            return expected;
        }
        else {
            var textContent:Null<String> = null;
            final first = input.firstChild();
            if (first != null && (first.nodeType == PCData || first.nodeType == CData))
                textContent = StringTools.trim(first.nodeValue);
            final wm = input.get("writing-mode");
            final writingMode:WritingMode = (wm != null && wm.indexOf("vertical") != -1) ? Vertical : Horizontal;
            final tnode = tree.newLeaf(buildStyle(input));
            tree.setNodeContext(tnode, textContent != null ? new TestNodeContext(textContent, writingMode) : null);
            if (parent != null)
                tree.addChild(parent, tnode);
            return buildExpectations(expectedX, tnode);
        }
    }

    static function getComputedExpectations(tree:TaffyTree<TestNodeContext>, nodeId:NodeId):OutputNode {
        final layout = tree.getFinalLayout(nodeId);
        final output = new OutputNode(nodeId);
        output.x = layout.location.x;
        output.y = layout.location.y;
        output.width = layout.size.width;
        output.height = layout.size.height;
        output.scrollWidth = layout.scrollWidth();
        output.scrollHeight = layout.scrollHeight();
        switch tree.detailedLayoutInfo(nodeId) {
            case Grid(info):
                output.resolvedRows = info.gridTemplateRows(1.0);
                output.resolvedColumns = info.gridTemplateColumns(1.0);
            case None:
        }
        for (child in tree.children(nodeId))
            output.children.push(getComputedExpectations(tree, child));
        return output;
    }

    static function buildExpectations(xnode:Xml, nodeId:NodeId):OutputNode {
        final output = new OutputNode(nodeId);
        output.x = Std.parseFloat(xnode.get("x"));
        output.y = Std.parseFloat(xnode.get("y"));
        output.width = Std.parseFloat(xnode.get("width"));
        output.height = Std.parseFloat(xnode.get("height"));
        final sw = xnode.get("scroll_width");
        final sh = xnode.get("scroll_height");
        if (sw != null && sh != null) {
            output.scrollWidth = Std.parseFloat(sw);
            output.scrollHeight = Std.parseFloat(sh);
        }
        output.resolvedRows = xnode.get("resolved-rows");
        output.resolvedColumns = xnode.get("resolved-columns");
        return output;
    }

    static function buildStyle(x:Xml):Style {
        final style = new Style();
        style.display = parseOr(x.get("display"), Display.parse, Display.DEFAULT);
        style.direction = parseOr(x.get("direction"), Direction.parse, Ltr);
        style.boxSizing = parseOr(x.get("box-sizing"), BoxSizing.parse, BorderBox);
        style.overflow = new PointOf<Overflow>(
            parseOr(x.get("overflow-x"), Overflow.parse, Visible),
            parseOr(x.get("overflow-y"), Overflow.parse, Visible)
        );
        final sbw = x.get("scrollbar-width");
        style.scrollbarWidth = sbw != null ? Std.parseFloat(sbw) : 0.0;
        style.contain = parseOr(x.get("contain"), Contain.parse, Contain.NONE);
        style.float = parseOr(x.get("float"), CssFloat.parse, CssFloat.None);
        style.clear = parseOr(x.get("clear"), Clear.parse, Clear.None);
        style.position = parseOr(x.get("position"), Position.parse, Static);

        style.size = new SizeOf<Dimension>(
            parseOr(x.get("width"), Dimension.parse, Dimension.AUTO),
            parseOr(x.get("height"), Dimension.parse, Dimension.AUTO)
        );
        style.minSize = new SizeOf<LengthPercentageAuto>(
            parseOr(x.get("min-width"), LengthPercentageAuto.parse, LengthPercentageAuto.AUTO),
            parseOr(x.get("min-height"), LengthPercentageAuto.parse, LengthPercentageAuto.AUTO)
        );
        style.maxSize = new SizeOf<LengthPercentageAuto>(
            parseOr(x.get("max-width"), LengthPercentageAuto.parse, LengthPercentageAuto.AUTO),
            parseOr(x.get("max-height"), LengthPercentageAuto.parse, LengthPercentageAuto.AUTO)
        );
        style.inset = new RectOf<LengthPercentageAuto>(
            parseOr(x.get("left"), LengthPercentageAuto.parse, LengthPercentageAuto.AUTO),
            parseOr(x.get("right"), LengthPercentageAuto.parse, LengthPercentageAuto.AUTO),
            parseOr(x.get("top"), LengthPercentageAuto.parse, LengthPercentageAuto.AUTO),
            parseOr(x.get("bottom"), LengthPercentageAuto.parse, LengthPercentageAuto.AUTO)
        );
        style.margin = new RectOf<LengthPercentageAuto>(
            parseOr(x.get("margin-left"), LengthPercentageAuto.parse, LengthPercentageAuto.ZERO),
            parseOr(x.get("margin-right"), LengthPercentageAuto.parse, LengthPercentageAuto.ZERO),
            parseOr(x.get("margin-top"), LengthPercentageAuto.parse, LengthPercentageAuto.ZERO),
            parseOr(x.get("margin-bottom"), LengthPercentageAuto.parse, LengthPercentageAuto.ZERO)
        );
        style.padding = new RectOf<LengthPercentage>(
            parseOr(x.get("padding-left"), LengthPercentage.parse, LengthPercentage.ZERO),
            parseOr(x.get("padding-right"), LengthPercentage.parse, LengthPercentage.ZERO),
            parseOr(x.get("padding-top"), LengthPercentage.parse, LengthPercentage.ZERO),
            parseOr(x.get("padding-bottom"), LengthPercentage.parse, LengthPercentage.ZERO)
        );
        style.border = new RectOf<LengthPercentage>(
            parseOr(x.get("border-left"), LengthPercentage.parse, LengthPercentage.ZERO),
            parseOr(x.get("border-right"), LengthPercentage.parse, LengthPercentage.ZERO),
            parseOr(x.get("border-top"), LengthPercentage.parse, LengthPercentage.ZERO),
            parseOr(x.get("border-bottom"), LengthPercentage.parse, LengthPercentage.ZERO)
        );
        style.gap = new SizeOf<LengthPercentage>(
            parseOr(x.get("column-gap"), LengthPercentage.parse, LengthPercentage.ZERO),
            parseOr(x.get("row-gap"), LengthPercentage.parse, LengthPercentage.ZERO)
        );

        final ar = x.get("aspect-ratio");
        if (ar != null) {
            final v = Std.parseFloat(ar);
            style.aspectRatio = Math.isNaN(v) ? OptionalFloat.NONE : OptionalFloat.some(v);
        }
        style.alignItems = parseOr(x.get("align-items"), AlignItems.parse, AlignItems.NORMAL);
        style.alignSelf = parseSelfAlignment(x.get("align-self"));
        style.justifyItems = parseOr(x.get("justify-items"), AlignItems.parse, AlignItems.NORMAL);
        style.justifySelf = parseSelfAlignment(x.get("justify-self"));
        style.alignContent = parseOr(x.get("align-content"), AlignContent.parse, AlignContent.NORMAL);
        style.justifyContent = parseOr(x.get("justify-content"), AlignContent.parse, AlignContent.NORMAL);

        style.textAlign = parseOr(x.get("text-align"), TextAlign.parse, TextAlign.Auto);
        style.flexDirection = parseOr(x.get("flex-direction"), FlexDirection.parse, Row);
        style.flexWrap = parseOr(x.get("flex-wrap"), FlexWrap.parse, NoWrap);
        final flc = x.get("flex-line-count");
        style.flexLineCount = flc != null ? Std.parseInt(flc) : 1;
        final fg = x.get("flex-grow");
        style.flexGrow = fg != null ? Std.parseFloat(fg) : 0.0;
        final fs = x.get("flex-shrink");
        style.flexShrink = fs != null ? Std.parseFloat(fs) : 1.0;
        style.flexBasis = parseOr(x.get("flex-basis"), Dimension.parse, Dimension.AUTO);

        style.gridAutoFlow = parseOr(x.get("grid-auto-flow"), GridAutoFlow.parse, GridAutoFlow.Row);

        final rows = x.get("grid-template-rows");
        if (rows != null) {
            final tracks = GridParsing.parseGridTemplateTracks(rows);
            if (tracks != null) {
                style.gridTemplateRows = tracks.tracks;
                style.gridTemplateRowNames = tracks.lineNames;
            }
        }
        final columns = x.get("grid-template-columns");
        if (columns != null) {
            final tracks = GridParsing.parseGridTemplateTracks(columns);
            if (tracks != null) {
                style.gridTemplateColumns = tracks.tracks;
                style.gridTemplateColumnNames = tracks.lineNames;
            }
        }
        final autoRows = x.get("grid-auto-rows");
        if (autoRows != null) {
            final tracks = GridParsing.parseGridAutoTracks(autoRows);
            if (tracks != null)
                style.gridAutoRows = tracks;
        }
        final autoColumns = x.get("grid-auto-columns");
        if (autoColumns != null) {
            final tracks = GridParsing.parseGridAutoTracks(autoColumns);
            if (tracks != null)
                style.gridAutoColumns = tracks;
        }

        style.gridRow = new LineOf<GridPlacement>(
            parseOr(x.get("grid-row-start"), GridParsing.parseGridPlacement, GridPlacement.Auto),
            parseOr(x.get("grid-row-end"), GridParsing.parseGridPlacement, GridPlacement.Auto)
        );
        style.gridColumn = new LineOf<GridPlacement>(
            parseOr(x.get("grid-column-start"), GridParsing.parseGridPlacement, GridPlacement.Auto),
            parseOr(x.get("grid-column-end"), GridParsing.parseGridPlacement, GridPlacement.Auto)
        );

        return style;
    }

    static function parseSelfAlignment(input:Null<String>):Null<AlignItems> {
        if (input == null || input.trim().toLowerCase() == "auto")
            return null;
        return AlignItems.parse(input);
    }

    static function parseOr<T>(input:Null<String>, parse:(String) -> Null<T>, fallback:T):T {
        if (input == null)
            return fallback;
        final result = parse(input);
        if (result == null)
            throw 'Could not parse value "$input"';
        return result;
    }

    static function parseBool(input:Null<String>, fallback:Bool):Bool {
        if (input == null)
            return fallback;
        return input.trim() == "true";
    }

    static function firstChildElement(xml:Xml, name:String):Xml {
        for (e in xml.elementsNamed(name))
            return e;
        throw 'Missing <$name> element';
    }

    /** Compare two resolved track list strings, comparing line names exactly and track sizes with a tolerance */
    public static function trackListsMatch(expected:String, actual:String):Bool {
        final e = parseTrackList(expected);
        final a = parseTrackList(actual);
        if (e.length != a.length)
            return false;
        for (i in 0...e.length) {
            final et = e[i];
            final at = a[i];
            if (et.size != null && at.size != null) {
                if (Math.abs(et.size - at.size) >= 0.1)
                    return false;
            }
            else if (et.names != at.names) {
                return false;
            }
        }
        return true;
    }

    static function parseTrackList(input:String):Array<TrackListToken> {
        final s = input.trim();
        final tokens:Array<TrackListToken> = [];
        if (s == "none")
            return tokens;
        var rest = s;
        while (rest.length > 0) {
            rest = rest.ltrim();
            if (rest.length == 0)
                break;
            if (rest.charAt(0) == "[") {
                final end = rest.indexOf("]");
                final names = rest.substring(1, end).split(" ").filter(n -> n != "").join(" ");
                tokens.push(new TrackListToken(names, null));
                rest = rest.substring(end + 1);
            }
            else {
                var end = rest.indexOf(" ");
                if (end == -1)
                    end = rest.length;
                var token = rest.substring(0, end);
                if (token.endsWith("px"))
                    token = token.substring(0, token.length - 2);
                tokens.push(new TrackListToken(null, Std.parseFloat(token)));
                rest = rest.substring(end);
            }
        }
        return tokens;
    }

}

class TrackListToken {

    public final names:Null<String>;

    public final size:Null<Float>;

    public function new(names:Null<String>, size:Null<Float>) {
        this.names = names;
        this.size = size;
    }

}

/**
 * `testMeasureFunction` as a `LayoutMeasurer` (`TaffyTree.computeLayoutWithMeasurer`) and a
 * `LeafMeasurer` (`Leaf.computeLeafLayoutWithMeasurer`, the sizes as values)
 */
private class TestMeasurer implements taffy.tree.LayoutMeasurer<TestNodeContext> implements taffy.compute.Leaf.LeafMeasurer {

    var context:Null<TestNodeContext> = null;

    public function new() {}

    public function measureLeafNode(inputs:taffy.tree.LayoutInput, nodeId:taffy.tree.NodeId, nodeContext:TestNodeContext, style:taffy.style.Style):taffy.tree.LayoutOutput {
        final previous = context;
        context = nodeContext;
        final output = taffy.compute.Leaf.computeLeafLayoutWithMeasurer(inputs, style, this);
        context = previous;
        return output;
    }

    var lastWidth:Float = 0.0;
    var lastHeight:Float = 0.0;

    /** The measure of `testMeasureFunction` */
    public function measureLeafSize(knownWidth:taffy.util.OptionalFloat, knownHeight:taffy.util.OptionalFloat, availableWidth:taffy.style.AvailableSpace, availableHeight:taffy.style.AvailableSpace):Void {
        if (knownWidth.isSome() && knownHeight.isSome()) {
            lastWidth = knownWidth.unwrap();
            lastHeight = knownHeight.unwrap();
            return;
        }
        if (context == null) {
            lastWidth = knownWidth.isSome() ? knownWidth.unwrap() : 0.0;
            lastHeight = knownHeight.isSome() ? knownHeight.unwrap() : 0.0;
            return;
        }
        context.count++;
        final computeSize = context.measure(new taffy.geometry.SizeOpt(knownWidth, knownHeight), new taffy.geometry.SizeAvail(availableWidth, availableHeight));
        lastWidth = knownWidth.isSome() ? knownWidth.unwrap() : computeSize.width;
        lastHeight = knownHeight.isSome() ? knownHeight.unwrap() : computeSize.height;
    }

    public function measuredWidth():Float {
        return lastWidth;
    }

    public function measuredHeight():Float {
        return lastHeight;
    }

}
