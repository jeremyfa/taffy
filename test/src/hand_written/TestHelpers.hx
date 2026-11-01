// Ported from taffy 0.15.0 (repository): tests/common/src/lib.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import taffy.compute.Leaf;
import taffy.geometry.LineOf;
import taffy.geometry.RectOf;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.AvailableSpace;
import taffy.style.Display;
import taffy.style.GridParsing;
import taffy.style.GridPlacement;
import taffy.style.GridTemplateComponent;
import taffy.style.LengthPercentage;
import taffy.style.LengthPercentageAuto;
import taffy.style.Position;
import taffy.style.Style;
import taffy.tree.LayoutInput;
import taffy.tree.LayoutOutput;
import taffy.tree.NodeId;
import taffy.tree.TaffyTree;
import taffy.style.AvailableSpace.Definite;
import taffy.geometry.SizeAvail;

/**
 * A named test function
 */
class TestCase {

    public final name:String;

    public final fn:Void->Void;

    public function new(name:String, fn:Void->Void) {
        this.name = name;
        this.fn = fn;
    }

}

/**
 * The measurement data for the node
 */
enum TestMeasureData {
    /** A zero-sized node */
    Zero;
    /** A node with a fixed size */
    Fixed(size:Size);
    /** A node with a width and an aspect ratio (height = width * heightRatio) */
    AspectRatio(width:Float, heightRatio:Float);
    /** A node with text using the Ahem font */
    AhemText(data:XmlTests.TestNodeContext);
}

/**
 * A shared node context for the hand written tests
 */
class TestNodeContext {

    /** How many times the measure function has been called */
    public var count:Int = 0;

    /** The measurement data to compute the intrinsic size from */
    public final measureData:TestMeasureData;

    public function new(measureData:TestMeasureData) {
        this.measureData = measureData;
    }

    /** Create a `TestNodeContext` for a zero-sized node */
    public static function zero():TestNodeContext {
        return new TestNodeContext(Zero);
    }

    /** Create a `TestNodeContext` for a fixed-sized node */
    public static function fixed(width:Float, height:Float):TestNodeContext {
        return new TestNodeContext(Fixed(new Size(width, height)));
    }

    /** Create a `TestNodeContext` for a node with a width and aspect-ratio */
    public static function aspectRatio(width:Float, heightRatio:Float):TestNodeContext {
        return new TestNodeContext(AspectRatio(width, heightRatio));
    }

    /** Create a `TestNodeContext` for a node with text using the Ahem font */
    public static function ahemText(textContent:String, writingMode:XmlTests.WritingMode):TestNodeContext {
        return new TestNodeContext(AhemText(new XmlTests.TestNodeContext(textContent, writingMode)));
    }

}

/**
 * Shared helpers for the hand written tests
 */
class TestHelpers {

    /** The zero width space separating "lines" in Ahem text */
    public static final ZWS:String = String.fromCharCode(0x200B);

    public static final MAX_CONTENT:SizeAvail = new SizeAvail(MaxContent, MaxContent);

    public static function definite(width:Float, height:Float):SizeAvail {
        return new SizeAvail(Definite(width), Definite(height));
    }

    /** Creates a `TaffyTree` that uses `TestNodeContext` */
    public static function newTestTree():TaffyTree<TestNodeContext> {
        return new TaffyTree<TestNodeContext>();
    }

    /** A measure function for tests that works with `TestNodeContext` */
    public static function testMeasureFunction(inputs:LayoutInput, nodeId:NodeId, context:Null<TestNodeContext>, style:Style):LayoutOutput {
        return Leaf.computeLeafLayout(inputs, style, (knownDimensions, availableSpace) -> {
            final kw = knownDimensions.width;
            final kh = knownDimensions.height;
            if (kw.isSome() && kh.isSome())
                return new Size(kw.unwrap(), kh.unwrap());

            if (context == null)
                return new Size(kw.isSome() ? kw.unwrap() : 0.0, kh.isSome() ? kh.unwrap() : 0.0);

            // Increment count
            context.count++;

            final computeSize:Size = switch context.measureData {
                case Zero: Size.ZERO;
                case Fixed(size): size;
                case AspectRatio(width, heightRatio):
                    final w:Float = kw.isSome() ? kw.unwrap() : width;
                    final h:Float = kh.isSome() ? kh.unwrap() : w * heightRatio;
                    new Size(w, h);
                case AhemText(data): data.measure(knownDimensions, availableSpace);
            }

            return new Size(kw.isSome() ? kw.unwrap() : computeSize.width, kh.isSome() ? kh.unwrap() : computeSize.height);
        });
    }

    // Style helpers

    /** Build a style: `st(s -> { s.display = Block; })` (Rust `Style { display: Display::Block, ..Default::default() }`) */
    public static function st(init:Style->Void):Style {
        final s = new Style();
        init(s);
        return s;
    }

    /** Build a style from a copy of `base` (Rust `Style { ..., ..base }`) */
    public static function stFrom(base:Style, init:Style->Void):Style {
        final s = base.clone();
        init(s);
        return s;
    }

    public static inline function length(value:Float):LengthPercentage {
        return LengthPercentage.length(value);
    }

    public static inline function percent(value:Float):LengthPercentage {
        return LengthPercentage.percent(value);
    }

    public static inline function auto():LengthPercentageAuto {
        return LengthPercentageAuto.AUTO;
    }

    public static inline function zero():LengthPercentage {
        return LengthPercentage.ZERO;
    }

    /** A `Rect<LengthPercentageAuto>` (left, right, top, bottom) */
    public static inline function rectLPA(left:LengthPercentageAuto, right:LengthPercentageAuto, top:LengthPercentageAuto, bottom:LengthPercentageAuto):RectOf<LengthPercentageAuto> {
        return new RectOf<LengthPercentageAuto>(left, right, top, bottom);
    }

    /** A `Rect<LengthPercentage>` (left, right, top, bottom) */
    public static inline function rectLP(left:LengthPercentage, right:LengthPercentage, top:LengthPercentage, bottom:LengthPercentage):RectOf<LengthPercentage> {
        return new RectOf<LengthPercentage>(left, right, top, bottom);
    }

    /** Rust `Rect::length(v)` for `Rect<LengthPercentageAuto>` */
    public static function insetAll(value:Float):RectOf<LengthPercentageAuto> {
        return rectLPA(length(value), length(value), length(value), length(value));
    }

    /** Rust `Rect::auto()` for `Rect<LengthPercentageAuto>` */
    public static function rectAuto():RectOf<LengthPercentageAuto> {
        return rectLPA(auto(), auto(), auto(), auto());
    }

    /** Rust `Rect::zero()` for `Rect<LengthPercentageAuto>` */
    public static function rectZeroLPA():RectOf<LengthPercentageAuto> {
        return rectLPA(zero(), zero(), zero(), zero());
    }

    /** Rust `Rect::zero()` for `Rect<LengthPercentage>` */
    public static function rectZeroLP():RectOf<LengthPercentage> {
        return rectLP(zero(), zero(), zero(), zero());
    }

    /** A grid track list, parsed from its CSS form (e.g. `"40px 60px"`) */
    public static function tracks(css:String):Array<GridTemplateComponent> {
        final parsed = GridParsing.parseGridTemplateTracks(css);
        if (parsed == null)
            throw 'invalid track list: $css';
        return parsed.tracks;
    }

    /** The line names of a grid track list, parsed from its CSS form */
    public static function trackLineNames(css:String):Array<Array<String>> {
        final parsed = GridParsing.parseGridTemplateTracks(css);
        if (parsed == null)
            throw 'invalid track list: $css';
        return parsed.lineNames;
    }

    /** Debug name of a display mode (for assertion messages) */
    public static function displayName(display:Display):String {
        return switch display {
            case Block: "Block";
            case FlowRoot: "FlowRoot";
            case Flex: "Flex";
            case Grid: "Grid";
            case None: "None";
        }
    }

    /** Debug name of a position (for assertion messages) */
    public static function positionName(position:Position):String {
        return switch position {
            case Static: "Static";
            case Relative: "Relative";
            case Absolute: "Absolute";
            case Fixed: "Fixed";
            case Sticky: "Sticky";
        }
    }

    /** Rust `line(index)` used as a `Line<GridPlacement>`: `index / auto` */
    public static function gridLine(index:Int):LineOf<GridPlacement> {
        return new LineOf<GridPlacement>(GridPlacement.Line(index), GridPlacement.Auto);
    }

    /** A `Line<GridPlacement>` */
    public static function placement(start:GridPlacement, end:GridPlacement):LineOf<GridPlacement> {
        return new LineOf<GridPlacement>(start, end);
    }

}
