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
    // On hxcpp the round trip through `cpp.Float32` compiles to a plain
    // `(float)` conversion. It must not use `__cpp__`: an inlined complex
    // argument can become a block expression, which a `__cpp__` cast cannot
    // take.
    public static #if (js || cs || cpp) inline #end function fround(value:Float):Float {
        #if js
        return js.lib.Math.fround(value);
        #elseif cpp
        final single:cpp.Float32 = value;
        return single;
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
        final census = Context.defined('taffy_census') && local.get().name != 'Census' && !StringTools.startsWith(local.get().name, 'OptionalFloat');
        final check = Context.defined('taffy_literal_check') && local.get().name != 'LiteralCheck';
        literals = check ? [] : null;
        for (field in fields) {
            // Inline constants must stay constant: they are written with
            // their exact f32 values
            if (field.access != null && field.access.contains(AInline) && !field.kind.match(FFun(_)))
                continue;
            switch field.kind {
                case FFun(fn) if (fn.expr != null):
                    fn.expr = transform(fn.expr);
                    if (census) {
                        fn.expr = censusInstrument(fn);
                        fn.expr = censusDefinite(fn.expr);
                    }
                case FVar(t, e) if (e != null):
                    field.kind = FVar(t, transform(e));
                case FProp(get, set, t, e) if (e != null):
                    field.kind = FProp(get, set, t, transform(e));
                case _:
            }
        }
        if (check && literals.length > 0) {
            // `-D taffy_literal_check`: a static that registers every literal
            // of this class with the text it was written as, so a test can
            // compare the value the target compiled with the f32 of the text
            final className = local.get().pack.concat([local.get().name]).join('.');
            final sources = [for (l in literals) macro $v{l.source}];
            final values = [for (l in literals) l.expr];
            fields.push({
                name: '__taffyLiterals',
                access: [AStatic, APrivate],
                kind: FVar(macro :Bool, macro taffy.util.LiteralCheck.register($v{className}, [$a{sources}], [$a{values}])),
                pos: local.get().pos
            });
        }
        literals = null;
        return fields;
        #end
    }

    /**
     * `-D taffy_census`: records every `Null<Float>` or `OptionalFloat`
     * argument on entry and every such return value of `fn` with
     * `taffy.util.Census.opt` / `taffy.util.Census.optional`. Nested
     * functions are left alone.
     */
    static function censusInstrument(fn:Function):Expr {
        final body = isOptFloatType(fn.ret) ? censusReturns(fn.expr, isOptionalFloatType(fn.ret)) : fn.expr;
        final records:Array<Expr> = [];
        for (arg in fn.args) {
            if (isOptFloatType(arg.type) || (arg.opt && isFloatType(arg.type))) {
                final name = arg.name;
                final site = sourceSite(fn.expr.pos) + ' arg ' + name;
                if (isOptionalFloatType(arg.type))
                    records.push(macro @:pos(fn.expr.pos) taffy.util.Census.optional($i{name}, $v{site}));
                else
                    records.push(macro @:pos(fn.expr.pos) taffy.util.Census.opt($i{name}, $v{site}));
            }
        }
        if (records.length == 0)
            return body;
        records.push(body);
        return {expr: EBlock(records), pos: fn.expr.pos};
    }

    static function censusReturns(e:Expr, optional:Bool):Expr {
        return switch e.expr {
            case EReturn(v) if (v != null):
                final inner = censusReturns(v, optional);
                final site = sourceSite(e.pos) + ' return';
                if (optional)
                    {expr: EReturn(macro @:pos(e.pos) taffy.util.Census.optional($inner, $v{site})), pos: e.pos};
                else
                    {expr: EReturn(macro @:pos(e.pos) taffy.util.Census.opt($inner, $v{site})), pos: e.pos};
            case EFunction(_, _):
                e;
            case _:
                haxe.macro.ExprTools.map(e, e -> censusReturns(e, optional));
        }
    }

    /**
     * `-D taffy_census`: `Definite(e)` (an `AvailableSpace` built in an
     * expression, not a case pattern) records `e` with
     * `taffy.util.Census.availDefinite`.
     */
    static function censusDefinite(e:Expr):Expr {
        return switch e.expr {
            case ECall({expr: EField(obj, 'match'), pos: p}, args):
                // `v.match(Definite(_))`: the argument is a pattern
                {expr: ECall({expr: EField(censusDefinite(obj), 'match'), pos: p}, args), pos: e.pos};
            case ECall(callee, [arg]) if (isDefiniteCallee(callee)):
                final site = sourceSite(e.pos) + ' Definite';
                final inner = censusDefinite(arg);
                {expr: ECall(callee, [macro @:pos(arg.pos) taffy.util.Census.availDefinite($inner, $v{site})]), pos: e.pos};
            case ESwitch(subject, cases, edef):
                {expr: ESwitch(censusDefinite(subject), [for (c in cases) {
                    values: c.values,
                    guard: c.guard != null ? censusDefinite(c.guard) : null,
                    expr: c.expr != null ? censusDefinite(c.expr) : null
                }], edef != null ? censusDefinite(edef) : null), pos: e.pos};
            case _:
                haxe.macro.ExprTools.map(e, censusDefinite);
        }
    }

    static function isDefiniteCallee(e:Expr):Bool {
        return switch e.expr {
            case EConst(CIdent('Definite')): true;
            case EField(_, 'Definite'): true;
            case _: false;
        }
    }

    static function sourceSite(pos:Position):String {
        final loc = haxe.macro.PositionTools.toLocation(pos);
        return loc.file + ':' + loc.range.start.line;
    }

    static function isOptFloatType(t:Null<ComplexType>):Bool {
        return switch t {
            case TPath({pack: [], name: 'Null', params: [TPType(inner)]}): isFloatType(inner);
            case _: isOptionalFloatType(t);
        }
    }

    static function isOptionalFloatType(t:Null<ComplexType>):Bool {
        return switch t {
            case TPath({name: 'OptionalFloat', params: null | []}): true;
            case _: false;
        }
    }

    static function isFloatType(t:Null<ComplexType>):Bool {
        return switch t {
            case TPath({pack: [], name: 'Float', params: null | []}): true;
            case _: false;
        }
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
            case EConst(CFloat(text)):
                // Rounded here, at compile time: a `fround(literal)` call can be
                // folded away by the analyzer on hxcpp (the `cpp.Float32` local
                // is constant propagated), which left the literal a double
                final single = singleLiteral(text);
                if (single == null)
                    macro @:pos(e.pos) taffy.util.F32.fround($e);
                else {
                    if (literals != null)
                        literals.push({source: text, expr: {expr: EConst(CFloat(single)), pos: e.pos}});
                    {expr: EConst(CFloat(single)), pos: e.pos};
                }
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

    /** The literals rewritten in the class being built (`-D taffy_literal_check`) */
    static var literals:Null<Array<{source:String, expr:Expr}>> = null;

    /**
     * The decimal text of `text` rounded to the nearest f32 (exact as a
     * double, and written with enough digits to read back exactly), or null
     * when the rounded value is not finite.
     */
    static function singleLiteral(text:String):Null<String> {
        final value = Std.parseFloat(text);
        final single = haxe.io.FPHelper.i32ToFloat(haxe.io.FPHelper.floatToI32(value));
        if (!Math.isFinite(single))
            return null;
        var result = Std.string(single);
        if (Std.parseFloat(result) != single)
            Context.fatalError('F32: cannot write the f32 value of $text exactly', Context.currentPos());
        if (result.indexOf('.') == -1 && result.indexOf('e') == -1 && result.indexOf('E') == -1)
            result += '.0';
        return result;
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
