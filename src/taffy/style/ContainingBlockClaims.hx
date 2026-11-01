// Ported from taffy 0.15.0: src/style/mod.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * Which kinds of out-of-flow boxes a node acts as the containing block for
 */
@:structInit
class ContainingBlockClaims {

    /** Claims no out-of-flow boxes */
    public static final NONE:ContainingBlockClaims = new ContainingBlockClaims(false, false);

    /** Claims all out-of-flow boxes */
    public static final ALL:ContainingBlockClaims = new ContainingBlockClaims(true, true);

    /** Whether the node is the containing block for `position: absolute` descendants */
    public final absolute:Bool;

    /** Whether the node is the containing block for `position: fixed` descendants */
    public final fixed:Bool;

    public inline function new(absolute:Bool, fixed:Bool) {
        this.absolute = absolute;
        this.fixed = fixed;
    }

    /** Whether the node claims boxes with the given position */
    public inline function forPosition(position:Position):Bool {
        return switch position {
            case Absolute: absolute;
            case Fixed: fixed;
            case _: false;
        }
    }

}
