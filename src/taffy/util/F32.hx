package taffy.util;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
#end

/**
 * Single precision arithmetic, like upstream taffy, which computes in `f32`.
 *
 * Haxe floats are doubles. Layouts that split a length into many parts (96
 * flex items over 140 px) accumulate positions whose rounding to pixels can
 * land on the other side of a half pixel than with `f32`, which moves an item
 * by one pixel. To give the same results as upstream, every class of the
 * `taffy` package is built with `F32.build` (see `extraParams.hxml`): each
 * `+`, `-`, `*`, `/` (and their `op=` forms) on floats, and each float
 * literal, is rounded to the nearest `f32`. Rounding the double result of an
 * operation on two `f32` values gives exactly the `f32` result for these
 * operations, so this is an exact emulation, not an approximation.
 *
 * Define `taffy_f64` to compute in double precision instead.
 */
class F32 {

    /** Rounds a double to the nearest single precision value. */
    // Not inline on hxcpp: an inlined complex argument can become a block
    // expression, which the `(float)` cast below cannot take
    public static #if (js || cs) inline #end function fround(value:Float):Float {
        #if js
        return js.lib.Math.fround(value);
        #elseif cpp
        return untyped __cpp__('((double)(float)({0}))', value);
        #elseif cs
        return untyped __cs__('((double)(float)({0}))', value);
        #else
        final bytes = haxe.io.Bytes.alloc(4);
        bytes.setFloat(0, value);
        return bytes.getFloat(0);
        #end
    }

    /**
     * `fround(e)` when `e` is a float, `e` otherwise (integers, strings).
     */
    public static macro function r(e:Expr):Expr {
        return isFloat(Context.typeof(e)) ? macro @:pos(e.pos) taffy.util.F32.fround($e) : e;
    }

    #if macro

    public static function build():Array<Field> {
        #if taffy_f64
        return null;
        #else
        final local = Context.getLocalClass();
        if (local == null || local.get().name == 'F32')
            return null;
        final fields = Context.getBuildFields();
        for (field in fields) {
            // Inline constants must stay constant: they are written with
            // their exact f32 values
            if (field.access != null && field.access.contains(AInline) && !field.kind.match(FFun(_)))
                continue;
            switch field.kind {
                case FFun(fn) if (fn.expr != null):
                    fn.expr = transform(fn.expr);
                case FVar(t, e) if (e != null):
                    field.kind = FVar(t, transform(e));
                case FProp(get, set, t, e) if (e != null):
                    field.kind = FProp(get, set, t, transform(e));
                case _:
            }
        }
        return fields;
        #end
    }

    static function transform(e:Expr):Expr {
        return switch e.expr {
            case EBinop(op = OpAdd | OpSub | OpMult | OpDiv, a, b):
                final inner = {expr: EBinop(op, transform(a), transform(b)), pos: e.pos};
                macro @:pos(e.pos) taffy.util.F32.r($inner);
            case EBinop(OpAssignOp(op = OpAdd | OpSub | OpMult | OpDiv), a, b):
                // `a op= b` becomes `a = r(a op b)` (the left side has no side
                // effects in this code base)
                final left = transform(a);
                final inner = {expr: EBinop(op, left, transform(b)), pos: e.pos};
                {expr: EBinop(OpAssign, left, macro @:pos(e.pos) taffy.util.F32.r($inner)), pos: e.pos};
            case EConst(CFloat(_)):
                macro @:pos(e.pos) taffy.util.F32.fround($e);
            case ESwitch(subject, cases, edef):
                // Case patterns stay constant
                {expr: ESwitch(transform(subject), [for (c in cases) {
                    values: c.values,
                    guard: c.guard != null ? transform(c.guard) : null,
                    expr: c.expr != null ? transform(c.expr) : null
                }], edef != null ? transform(edef) : null), pos: e.pos};
            case _:
                haxe.macro.ExprTools.map(e, transform);
        }
    }

    static function isFloat(t:Type):Bool {
        return switch Context.follow(t) {
            case TAbstract(_.get() => a, params):
                a.pack.length == 0 && (a.name == 'Float' || (a.name == 'Null' && params.length == 1 && isFloat(params[0])));
            case _: false;
        }
    }

    #end

}
