package taffy.util;

/**
 * `-D taffy_literal_check`: the float literals of the taffy package, as the
 * target compiled them, with the text they were written as (registered by
 * `F32.build` in a static of each class). `failures()` lists every literal
 * whose compiled value is not the f32 value of its text, which is what the
 * `F32` macro guarantees on every target.
 */
class LiteralCheck {

    #if taffy_literal_check

    // No initializers: the registering statics of other classes may run first
    public static var classes:Array<String>;
    static var sources:Array<String>;
    static var values:Array<Float>;

    public static function register(className:String, texts:Array<String>, compiled:Array<Float>):Bool {
        if (classes == null) {
            classes = [];
            sources = [];
            values = [];
        }
        classes.push(className);
        for (i in 0...texts.length) {
            sources.push(className + ': ' + texts[i]);
            values.push(compiled[i]);
        }
        return true;
    }

    /** The literals whose compiled value differs from the f32 rounding of their text, computed at run time */
    public static function failures():Array<String> {
        final result:Array<String> = [];
        if (sources == null)
            return ['no literal registered'];
        for (i in 0...sources.length) {
            final text = sources[i].substr(sources[i].indexOf(': ') + 2);
            final expected = F32.fround(Std.parseFloat(text));
            final actual = values[i];
            if (!(actual == expected || (actual != actual && expected != expected)))
                result.push(sources[i] + ' compiled as ' + actual + ', expected ' + expected);
        }
        return result;
    }

    #end

}
