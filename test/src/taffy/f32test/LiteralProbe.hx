package taffy.f32test;

/**
 * Float literals written like the layout code writes them (a local
 * constant, a comparison, a literal inside arithmetic). This class is in the
 * `taffy` package, so the `F32` macro rewrites it like the library: every
 * value returned here must be the f32 value of its literal on every target.
 */
class LiteralProbe {

    /** `TrackSizing.hx`: `final THRESHOLD = 0.000001` */
    public static function localConstant():Float {
        final THRESHOLD = 0.000001;
        return THRESHOLD;
    }

    /** `TrackSizing.hx`: `final THRESHOLD = 0.01` used in a comparison */
    public static function comparedConstant(space:Float):Bool {
        final THRESHOLD = 0.01;
        return space <= THRESHOLD;
    }

    /** A literal operand of an arithmetic expression */
    public static function scaled(value:Float):Float {
        return value * 0.1;
    }

    /** A literal that is already an f32 value */
    public static function exact():Float {
        return 1.17549435e-38;
    }

}
