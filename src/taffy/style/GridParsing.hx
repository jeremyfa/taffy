// Ported from taffy 0.15.0: src/style/grid.rs (FromCss implementations), src/util/parse.rs (simplified tokenizer)
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * The parsed value of `grid-template-rows` / `grid-template-columns` (Rust `GridTemplateTracks`): the tracks and the line names
 */
class GridTemplateTracks {

    /** The track list */
    public final tracks:Array<GridTemplateComponent>;

    /** The line names (one group per line: `tracks.length + 1` groups, empty for unnamed lines) */
    public final lineNames:Array<Array<String>>;

    public function new(tracks:Array<GridTemplateComponent>, lineNames:Array<Array<String>>) {
        this.tracks = tracks;
        this.lineNames = lineNames;
    }

}

/**
 * CSS parsing of grid properties (port of the `FromCss` implementations of the grid style types).
 * Every function returns null if the input is invalid.
 */
class GridParsing {

    /** Parse a `grid-template-rows` / `grid-template-columns` value */
    public static function parseGridTemplateTracks(input:String):Null<GridTemplateTracks> {
        final stream = CssTokenStream.tokenize(input);
        if (stream == null)
            return null;
        final names:Array<Array<String>> = [];
        final tracks:Array<GridTemplateComponent> = [];
        if (!parseTrackList(stream, names, tracks, true, null))
            return null;
        return new GridTemplateTracks(tracks, names);
    }

    /** Parse a `grid-auto-rows` / `grid-auto-columns` value */
    public static function parseGridAutoTracks(input:String):Null<Array<TrackSizingFunction>> {
        final stream = CssTokenStream.tokenize(input);
        if (stream == null)
            return null;
        final tracks:Array<TrackSizingFunction> = [];
        while (!stream.isExhausted()) {
            final track = parseTrackSizingFunction(stream);
            if (track == null)
                return null;
            tracks.push(track);
        }
        if (tracks.length == 0)
            return null;
        return tracks;
    }

    /** Parse a `grid-row-start` (etc) value */
    public static function parseGridPlacement(input:String):Null<GridPlacement> {
        final stream = CssTokenStream.tokenize(input);
        if (stream == null)
            return null;
        var span = false;
        var number:Null<Int> = null;
        var ident:Null<String> = null;

        while (!stream.isExhausted()) {
            final token = stream.next();
            switch token.kind {
                case CssToken.IDENT:
                    switch token.text {
                        case "auto":
                            if (span || number != null || ident != null)
                                return null;
                            if (!stream.isExhausted())
                                return null;
                            return GridPlacement.Auto;
                        case "span":
                            if (span)
                                return null;
                            span = true;
                        case other:
                            if (ident != null)
                                return null;
                            ident = other;
                    }
                case CssToken.NUMBER if (token.intValue != null && token.intValue != 0):
                    if (number != null)
                        return null;
                    number = token.intValue;
                case _:
                    return null;
            }
        }

        if (span) {
            if (number == null && ident == null)
                return GridPlacement.Span(0);
            if (number != null && ident == null)
                return GridPlacement.Span(saturatingU16(number));
            if (number == null && ident != null)
                return GridPlacement.NamedSpan(ident, 0);
            return GridPlacement.NamedSpan(ident, saturatingU16(number));
        }
        else {
            if (number != null && ident == null)
                return GridPlacement.Line(saturatingI16(number));
            if (number != null && ident != null)
                return GridPlacement.NamedLine(ident, saturatingI16(number));
            if (ident != null)
                return GridPlacement.NamedLine(ident, 0);
            return null;
        }
    }

    /** Parse a single track sizing function (`minmax(...)` or a max track sizing function) */
    public static function parseTrackSizingFunctionString(input:String):Null<TrackSizingFunction> {
        final stream = CssTokenStream.tokenize(input);
        if (stream == null)
            return null;
        final result = parseTrackSizingFunction(stream);
        return (result != null && stream.isExhausted()) ? result : null;
    }

    /** Parse a single `grid-template-*` component (a track sizing function or a `repeat()`) */
    public static function parseGridTemplateComponentString(input:String):Null<GridTemplateComponent> {
        final stream = CssTokenStream.tokenize(input);
        if (stream == null)
            return null;
        final result = parseGridTemplateComponent(stream);
        return (result != null && stream.isExhausted()) ? result : null;
    }

    /** Parse a repetition count (`<positive integer>`, `auto-fill` or `auto-fit`) */
    public static function parseRepetitionCountString(input:String):Null<RepetitionCount> {
        final stream = CssTokenStream.tokenize(input);
        if (stream == null)
            return null;
        final result = parseRepetitionCount(stream);
        return (result != null && stream.isExhausted()) ? result : null;
    }

    /** Saturates an integer to the range representable by `i16` */
    static inline function saturatingI16(value:Int):Int {
        return value < -32768 ? -32768 : (value > 32767 ? 32767 : value);
    }

    /** Saturates an integer to the range representable by `u16` */
    static inline function saturatingU16(value:Int):Int {
        return value < 0 ? 0 : (value > 65535 ? 65535 : value);
    }

    /**
     * Parse a track list with line names (Rust `GridTemplateTracks::from_css`), filling `names` and either
     * `components` (when `asComponents`) or `singleTracks`. The stream must be entirely consumed.
     */
    static function parseTrackList(stream:CssTokenStream, names:Array<Array<String>>, components:Null<Array<GridTemplateComponent>>,
            asComponents:Bool, singleTracks:Null<Array<TrackSizingFunction>>):Bool {
        // Line name groups are positional (group `i` names line `i`), so a group is pushed for
        // every line, empty when the line has no `[...]` in the source
        names.push(tryParseLineNames(stream));
        var count = 0;
        while (!stream.isExhausted()) {
            if (asComponents) {
                final component = parseGridTemplateComponent(stream);
                if (component == null)
                    return false;
                components.push(component);
            }
            else {
                final track = parseTrackSizingFunction(stream);
                if (track == null)
                    return false;
                singleTracks.push(track);
            }
            count++;
            names.push(tryParseLineNames(stream));
        }
        return count > 0;
    }

    /** Try to parse a `[name name...]` group, returning an empty list (and consuming nothing) on failure */
    static function tryParseLineNames(stream:CssTokenStream):Array<String> {
        final token = stream.peek();
        if (token == null || token.kind != CssToken.SQUARE)
            return [];
        final lineNames:Array<String> = [];
        for (child in token.children) {
            if (child.kind != CssToken.IDENT)
                return [];
            lineNames.push(child.text);
        }
        stream.next();
        return lineNames;
    }

    /** `GridTemplateComponent::from_css` */
    static function parseGridTemplateComponent(stream:CssTokenStream):Null<GridTemplateComponent> {
        // Try to parse a repeat() function
        final token = stream.peek();
        if (token != null && token.kind == CssToken.FUNCTION && token.text == "repeat") {
            final inner = new CssTokenStream(token.children);
            final count = parseRepetitionCount(inner);
            if (count != null) {
                final comma = inner.next();
                if (comma != null && comma.kind == CssToken.COMMA) {
                    final names:Array<Array<String>> = [];
                    final tracks:Array<TrackSizingFunction> = [];
                    if (parseTrackList(inner, names, null, false, tracks)) {
                        stream.next();
                        return GridTemplateComponent.Repeat(new GridTemplateRepetition(count, tracks, names));
                    }
                }
            }
        }

        // Else parse a track sizing function
        final track = parseTrackSizingFunction(stream);
        return track != null ? GridTemplateComponent.Single(track) : null;
    }

    /** `RepetitionCount::from_css` */
    static function parseRepetitionCount(stream:CssTokenStream):Null<RepetitionCount> {
        final token = stream.next();
        if (token == null)
            return null;
        if (token.kind == CssToken.NUMBER && token.intValue != null && token.intValue > 0)
            return RepetitionCount.Count(saturatingU16(token.intValue));
        if (token.kind == CssToken.IDENT && token.text == "auto-fit")
            return RepetitionCount.AutoFit;
        if (token.kind == CssToken.IDENT && token.text == "auto-fill")
            return RepetitionCount.AutoFill;
        return null;
    }

    /** `TrackSizingFunction::from_css` */
    static function parseTrackSizingFunction(stream:CssTokenStream):Null<TrackSizingFunction> {
        // Try to parse a minmax() function
        final token = stream.peek();
        if (token != null && token.kind == CssToken.FUNCTION && token.text == "minmax") {
            final inner = new CssTokenStream(token.children);
            final min = parseMinTrackSizingFunction(inner);
            if (min != null) {
                final comma = inner.next();
                if (comma != null && comma.kind == CssToken.COMMA) {
                    final max = parseMaxTrackSizingFunction(inner);
                    if (max != null && inner.isExhausted()) {
                        stream.next();
                        return new TrackSizingFunction(min, max);
                    }
                }
            }
        }

        // Else parse a max track sizing function
        final max = parseMaxTrackSizingFunction(stream);
        if (max == null)
            return null;
        return new TrackSizingFunction(MinTrackSizingFunction.fromMax(max), max);
    }

    /** `MaxTrackSizingFunction::from_css` */
    static function parseMaxTrackSizingFunction(stream:CssTokenStream):Null<MaxTrackSizingFunction> {
        final token = stream.next();
        if (token == null)
            return null;
        switch token.kind {
            case CssToken.PERCENTAGE:
                return MaxTrackSizingFunction.percent(token.value);
            case CssToken.DIMENSION if (token.text == "px"):
                return MaxTrackSizingFunction.length(token.value);
            case CssToken.DIMENSION if (token.text == "fr" && isSignPositive(token.value)):
                return MaxTrackSizingFunction.fr(token.value);
            case CssToken.IDENT:
                return switch token.text {
                    case "auto": MaxTrackSizingFunction.auto();
                    case "min-content": MaxTrackSizingFunction.minContent();
                    case "max-content": MaxTrackSizingFunction.maxContent();
                    case _: null;
                }
            case CssToken.FUNCTION if (token.text == "fit-content"):
                final inner = new CssTokenStream(token.children);
                final arg = inner.next();
                if (arg == null || !inner.isExhausted())
                    return null;
                if (arg.kind == CssToken.PERCENTAGE)
                    return MaxTrackSizingFunction.fitContentPercent(arg.value);
                if (arg.kind == CssToken.DIMENSION && arg.text == "px")
                    return MaxTrackSizingFunction.fitContentPx(arg.value);
                return null;
            case _:
                return null;
        }
    }

    /** `MinTrackSizingFunction::from_css` */
    static function parseMinTrackSizingFunction(stream:CssTokenStream):Null<MinTrackSizingFunction> {
        final token = stream.next();
        if (token == null)
            return null;
        switch token.kind {
            case CssToken.PERCENTAGE:
                return MinTrackSizingFunction.percent(token.value);
            case CssToken.DIMENSION if (token.text == "px"):
                return MinTrackSizingFunction.length(token.value);
            case CssToken.IDENT:
                return switch token.text {
                    case "auto": MinTrackSizingFunction.auto();
                    case "min-content": MinTrackSizingFunction.minContent();
                    case "max-content": MinTrackSizingFunction.maxContent();
                    case _: null;
                }
            case _:
                return null;
        }
    }

    static inline function isSignPositive(value:Float):Bool {
        return value > 0 || (value == 0 && 1 / value > 0);
    }

}

/**
 * A CSS token (simplified version of the `cssparser` tokens used by the grid parsers)
 */
private class CssToken {

    public static inline final IDENT:Int = 0;
    public static inline final NUMBER:Int = 1;
    public static inline final DIMENSION:Int = 2;
    public static inline final PERCENTAGE:Int = 3;
    public static inline final FUNCTION:Int = 4;
    public static inline final SQUARE:Int = 5;
    public static inline final COMMA:Int = 6;
    public static inline final DELIM:Int = 7;

    public final kind:Int;

    /** The identifier, function name, unit or delimiter */
    public final text:String;

    /** The numeric value (percentages are divided by 100, like cssparser's `unit_value`) */
    public final value:Float;

    /** The integer value of a number token written without fractional part or exponent */
    public final intValue:Null<Int>;

    /** The tokens of a function or square bracket block */
    public final children:Array<CssToken>;

    public function new(kind:Int, text:String, value:Float, intValue:Null<Int>, children:Array<CssToken>) {
        this.kind = kind;
        this.text = text;
        this.value = value;
        this.intValue = intValue;
        this.children = children;
    }

}

/**
 * A stream of CSS tokens with a cursor
 */
private class CssTokenStream {

    final tokens:Array<CssToken>;

    var pos:Int = 0;

    public function new(tokens:Array<CssToken>) {
        this.tokens = tokens;
    }

    public inline function isExhausted():Bool {
        return pos >= tokens.length;
    }

    public inline function peek():Null<CssToken> {
        return pos < tokens.length ? tokens[pos] : null;
    }

    public inline function next():Null<CssToken> {
        return pos < tokens.length ? tokens[pos++] : null;
    }

    /** Tokenize the input, or return null if it contains unbalanced blocks */
    public static function tokenize(input:String):Null<CssTokenStream> {
        final tokenizer = new CssTokenizer(input);
        final tokens = tokenizer.parseList(-1);
        if (tokens == null || tokenizer.pos < input.length)
            return null;
        return new CssTokenStream(tokens);
    }

}

/**
 * A minimal CSS tokenizer
 */
private class CssTokenizer {

    final input:String;

    public var pos:Int = 0;

    public function new(input:String) {
        this.input = input;
    }

    /** Parse tokens until `closing` (a char code, consumed) or the end of input (`closing == -1`) */
    public function parseList(closing:Int):Null<Array<CssToken>> {
        final tokens:Array<CssToken> = [];
        final len = input.length;
        while (true) {
            skipWhitespace();
            if (pos >= len)
                return closing == -1 ? tokens : null;
            final c = input.charCodeAt(pos);
            if (c == closing) {
                pos++;
                return tokens;
            }
            if (c == ")".code || c == "]".code)
                return null;
            if (c == ",".code) {
                pos++;
                tokens.push(new CssToken(CssToken.COMMA, ",", 0, null, null));
                continue;
            }
            if (c == "[".code) {
                pos++;
                final children = parseList("]".code);
                if (children == null)
                    return null;
                tokens.push(new CssToken(CssToken.SQUARE, "[", 0, null, children));
                continue;
            }
            if (startsNumber()) {
                tokens.push(parseNumeric());
                continue;
            }
            if (startsIdent()) {
                final name = parseIdent();
                if (pos < len && input.charCodeAt(pos) == "(".code) {
                    pos++;
                    final children = parseList(")".code);
                    if (children == null)
                        return null;
                    tokens.push(new CssToken(CssToken.FUNCTION, name, 0, null, children));
                }
                else {
                    tokens.push(new CssToken(CssToken.IDENT, name, 0, null, null));
                }
                continue;
            }
            pos++;
            tokens.push(new CssToken(CssToken.DELIM, String.fromCharCode(c), 0, null, null));
        }
    }

    function skipWhitespace():Void {
        while (pos < input.length) {
            final c = input.charCodeAt(pos);
            if (c == " ".code || c == "\t".code || c == "\n".code || c == "\r".code)
                pos++;
            else
                break;
        }
    }

    inline function charAt(i:Int):Int {
        return i < input.length ? input.charCodeAt(i) : -1;
    }

    static inline function isDigit(c:Int):Bool {
        return c >= "0".code && c <= "9".code;
    }

    static inline function isNameStart(c:Int):Bool {
        return (c >= "a".code && c <= "z".code) || (c >= "A".code && c <= "Z".code) || c == "_".code || c >= 0x80;
    }

    static inline function isNameChar(c:Int):Bool {
        return isNameStart(c) || isDigit(c) || c == "-".code;
    }

    function startsNumber():Bool {
        final c = charAt(pos);
        if (isDigit(c))
            return true;
        if (c == ".".code)
            return isDigit(charAt(pos + 1));
        if (c == "+".code || c == "-".code) {
            final d = charAt(pos + 1);
            return isDigit(d) || (d == ".".code && isDigit(charAt(pos + 2)));
        }
        return false;
    }

    function startsIdentAt(i:Int):Bool {
        final c = charAt(i);
        if (isNameStart(c))
            return true;
        if (c == "-".code) {
            final d = charAt(i + 1);
            return isNameStart(d) || d == "-".code;
        }
        return false;
    }

    inline function startsIdent():Bool {
        return startsIdentAt(pos);
    }

    function parseIdent():String {
        final start = pos;
        while (pos < input.length && isNameChar(input.charCodeAt(pos)))
            pos++;
        return input.substring(start, pos);
    }

    function parseNumeric():CssToken {
        final start = pos;
        var isInteger = true;
        var c = charAt(pos);
        if (c == "+".code || c == "-".code)
            pos++;
        while (isDigit(charAt(pos)))
            pos++;
        if (charAt(pos) == ".".code && isDigit(charAt(pos + 1))) {
            isInteger = false;
            pos++;
            while (isDigit(charAt(pos)))
                pos++;
        }
        c = charAt(pos);
        if ((c == "e".code || c == "E".code)
            && (isDigit(charAt(pos + 1)) || ((charAt(pos + 1) == "+".code || charAt(pos + 1) == "-".code) && isDigit(charAt(pos + 2))))) {
            isInteger = false;
            pos += 2;
            while (isDigit(charAt(pos)))
                pos++;
        }
        final text = input.substring(start, pos);
        final value = Std.parseFloat(text);
        var intValue:Null<Int> = null;
        if (isInteger) {
            // Clamp to the i32 range like cssparser
            intValue = value > 2147483647.0 ? 2147483647 : (value < -2147483648.0 ? -2147483648 : Std.int(value));
        }
        if (charAt(pos) == "%".code) {
            pos++;
            return new CssToken(CssToken.PERCENTAGE, "%", value / 100, null, null);
        }
        if (startsIdent()) {
            final unit = parseIdent();
            return new CssToken(CssToken.DIMENSION, unit.toLowerCase(), value, intValue, null);
        }
        return new CssToken(CssToken.NUMBER, "", value, intValue, null);
    }

}
