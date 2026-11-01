// Ported from taffy 0.15.0: src/util/parse.rs (simplified, no cssparser dependency)
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.util;

/**
 * A number with an optional unit (`px`, `%`, `fr`, or empty)
 */
class ParsedNumber {

    /** The numeric value */
    public final value:Float;

    /** The unit (lower case), empty if none */
    public final unit:String;

    /** Whether the number was written without fractional part or exponent */
    public final isInteger:Bool;

    public function new(value:Float, unit:String, isInteger:Bool) {
        this.value = value;
        this.unit = unit;
        this.isInteger = isInteger;
    }

}

/**
 * Minimal CSS value parsing helpers used by the `parse()` functions of style types.
 */
class Parse {

    /** Parse a number with an optional unit, like `10`, `-2.5px`, `50%`, `1fr`. Returns null if invalid. */
    public static function parseNumberWithUnit(input:String):Null<ParsedNumber> {
        final s = input;
        var i = 0;
        final len = s.length;
        if (len == 0)
            return null;
        var isInteger = true;
        if (s.charAt(i) == "+" || s.charAt(i) == "-")
            i++;
        final digitsStart = i;
        while (i < len && isDigit(s.charCodeAt(i)))
            i++;
        if (i < len && s.charAt(i) == ".") {
            isInteger = false;
            i++;
            while (i < len && isDigit(s.charCodeAt(i)))
                i++;
        }
        if (i == digitsStart || (i == digitsStart + 1 && s.charAt(digitsStart) == "."))
            return null;
        if (i < len && (s.charAt(i) == "e" || s.charAt(i) == "E")) {
            var j = i + 1;
            if (j < len && (s.charAt(j) == "+" || s.charAt(j) == "-"))
                j++;
            if (j < len && isDigit(s.charCodeAt(j))) {
                isInteger = false;
                i = j;
                while (i < len && isDigit(s.charCodeAt(i)))
                    i++;
            }
        }
        final numStr = s.substring(0, i);
        final value = Std.parseFloat(numStr);
        if (Math.isNaN(value))
            return null;
        final unit = s.substring(i).toLowerCase();
        if (unit != "" && unit != "%") {
            for (k in 0...unit.length) {
                final c = unit.charCodeAt(k);
                if (!((c >= "a".code && c <= "z".code) || c == "-".code))
                    return null;
            }
        }
        return new ParsedNumber(value, unit, isInteger);
    }

    /** Split a CSS value on whitespace, keeping parenthesized and bracketed groups together */
    public static function splitTopLevel(input:String):Array<String> {
        final result:Array<String> = [];
        var depth = 0;
        var current = new StringBuf();
        var hasContent = false;
        for (i in 0...input.length) {
            final c = input.charAt(i);
            if (c == "(" || c == "[")
                depth++;
            else if (c == ")" || c == "]")
                depth--;
            if (depth == 0 && (c == " " || c == "\t" || c == "\n" || c == "\r")) {
                if (hasContent) {
                    result.push(current.toString());
                    current = new StringBuf();
                    hasContent = false;
                }
                continue;
            }
            current.add(c);
            hasContent = true;
            if (depth == 0 && c == "]") {
                result.push(current.toString());
                current = new StringBuf();
                hasContent = false;
            }
        }
        if (hasContent)
            result.push(current.toString());
        return result;
    }

    /** Split the arguments of a CSS function on top level commas */
    public static function splitArgs(input:String):Array<String> {
        final result:Array<String> = [];
        var depth = 0;
        var start = 0;
        for (i in 0...input.length) {
            final c = input.charAt(i);
            if (c == "(" || c == "[")
                depth++;
            else if (c == ")" || c == "]")
                depth--;
            else if (c == "," && depth == 0) {
                result.push(StringTools.trim(input.substring(start, i)));
                start = i + 1;
            }
        }
        result.push(StringTools.trim(input.substring(start)));
        return result;
    }

    static inline function isDigit(c:Int):Bool {
        return c >= "0".code && c <= "9".code;
    }

}
