// Ported from taffy 0.15.0 (repository): tests/hand_written.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package hand_written;

import taffy.geometry.Point;
import taffy.geometry.Rect;
import taffy.geometry.Size;
import taffy.tree.Layout;
import taffy.tree.NodeId;

/**
 * Error thrown by a failed assertion
 */
class AssertionError extends haxe.Exception {}

/**
 * Tiny assertion helpers for the hand written tests (Rust `assert!` / `assert_eq!`).
 * Floats are compared with a small tolerance since Haxe computes in f64 while Rust uses f32.
 */
class Assert {

    static inline final EPSILON:Float = 0.001;

    static function fail(text:String, msg:Null<String>, pos:haxe.PosInfos):Void {
        final where = pos != null ? ' at ${pos.fileName}:${pos.lineNumber}' : "";
        throw new AssertionError(msg != null ? '$text [$msg]$where' : '$text$where');
    }

    public static function floatEquals(a:Float, b:Float):Bool {
        if (Math.isNaN(a) || Math.isNaN(b))
            return Math.isNaN(a) && Math.isNaN(b);
        if (a == b)
            return true;
        return Math.abs(a - b) <= EPSILON;
    }

    public static function isTrue(cond:Bool, ?msg:String, ?pos:haxe.PosInfos):Void {
        if (!cond)
            fail("assertion failed", msg, pos);
    }

    public static function isFalse(cond:Bool, ?msg:String, ?pos:haxe.PosInfos):Void {
        if (cond)
            fail("assertion failed (expected false)", msg, pos);
    }

    public static function eq(actual:Float, expected:Float, ?msg:String, ?pos:haxe.PosInfos):Void {
        if (!floatEquals(actual, expected))
            fail('expected $expected, got $actual', msg, pos);
    }

    public static function eqInt(actual:Int, expected:Int, ?msg:String, ?pos:haxe.PosInfos):Void {
        if (actual != expected)
            fail('expected $expected, got $actual', msg, pos);
    }

    public static function eqStr(actual:Null<String>, expected:Null<String>, ?msg:String, ?pos:haxe.PosInfos):Void {
        if (actual != expected)
            fail('expected "$expected", got "$actual"', msg, pos);
    }

    public static function eqSize(actual:Size, width:Float, height:Float, ?msg:String, ?pos:haxe.PosInfos):Void {
        if (!floatEquals(actual.width, width) || !floatEquals(actual.height, height))
            fail('expected size ($width, $height), got (${actual.width}, ${actual.height})', msg, pos);
    }

    public static function eqPoint(actual:Point, x:Float, y:Float, ?msg:String, ?pos:haxe.PosInfos):Void {
        if (!floatEquals(actual.x, x) || !floatEquals(actual.y, y))
            fail('expected point ($x, $y), got (${actual.x}, ${actual.y})', msg, pos);
    }

    static function rectEquals(a:Rect, b:Rect):Bool {
        return floatEquals(a.left, b.left) && floatEquals(a.right, b.right) && floatEquals(a.top, b.top) && floatEquals(a.bottom, b.bottom);
    }

    public static function eqRect(actual:Rect, expected:Rect, ?msg:String, ?pos:haxe.PosInfos):Void {
        if (!rectEquals(actual, expected))
            fail('expected rect $expected, got $actual', msg, pos);
    }

    /** Whether two layouts are equal (Rust `Layout: PartialEq`) */
    public static function layoutEquals(a:Layout, b:Layout):Bool {
        return a.order == b.order
            && floatEquals(a.location.x, b.location.x)
            && floatEquals(a.location.y, b.location.y)
            && floatEquals(a.size.width, b.size.width)
            && floatEquals(a.size.height, b.size.height)
            && rectEquals(a.scrollableOverflowRect, b.scrollableOverflowRect)
            && floatEquals(a.scrollbarSize.width, b.scrollbarSize.width)
            && floatEquals(a.scrollbarSize.height, b.scrollbarSize.height)
            && rectEquals(a.border, b.border)
            && rectEquals(a.padding, b.padding)
            && rectEquals(a.margin, b.margin);
    }

    static function layoutString(l:Layout):String {
        return 'Layout(location: ${l.location}, size: ${l.size}, overflow: ${l.scrollableOverflowRect}, margin: ${l.margin}, border: ${l.border}, padding: ${l.padding})';
    }

    public static function eqLayouts(actual:Array<Layout>, expected:Array<Layout>, ?msg:String, ?pos:haxe.PosInfos):Void {
        if (actual.length != expected.length) {
            fail('expected ${expected.length} layouts, got ${actual.length}', msg, pos);
            return;
        }
        for (i in 0...actual.length) {
            if (!layoutEquals(actual[i], expected[i]))
                fail('layout $i differs: expected ${layoutString(expected[i])}, got ${layoutString(actual[i])}', msg, pos);
        }
    }

    public static function eqIds(actual:Array<NodeId>, expected:Array<NodeId>, ?msg:String, ?pos:haxe.PosInfos):Void {
        var same = actual.length == expected.length;
        if (same) {
            for (i in 0...actual.length) {
                if (actual[i] != expected[i])
                    same = false;
            }
        }
        if (!same)
            fail('expected ids $expected, got $actual', msg, pos);
    }

}
