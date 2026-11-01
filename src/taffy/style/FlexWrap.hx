// Ported from taffy 0.15.0: src/style/flex.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.style;

/**
 * Controls whether flex items are forced onto one line or can wrap onto multiple lines.
 *
 * The default value is `NoWrap`.
 */
enum abstract FlexWrap(Int) {

    /** Items will not wrap and stay on a single line */
    var NoWrap = 0;

    /** Items will wrap according to this item's `FlexDirection` */
    var Wrap = 1;

    /** Items will wrap in the opposite direction to this item's `FlexDirection` */
    var WrapReverse = 2;

    /** Items will wrap onto `flex_line_count` balanced lines (`flex-wrap: balance`) */
    var Balance = 3;

    /** Like `Balance`, with lines in reverse order */
    var BalanceReverse = 4;

    /** Whether the container is multi-line */
    public inline function isMultiLine():Bool {
        return this != 0;
    }

    /** Whether lines are stacked in reverse order */
    public inline function isReverse():Bool {
        return this == 2 || this == 4;
    }

    /** Whether lines are balanced */
    public inline function isBalance():Bool {
        return this == 3 || this == 4;
    }

    /** Parse a CSS value, or return null */
    public static function parse(input:String):Null<FlexWrap> {
        final parts = StringTools.trim(input).toLowerCase().split(" ").filter(p -> p != "");
        if (parts.length == 0)
            return null;
        if (parts[0] == "nowrap")
            return parts.length == 1 ? NoWrap : null;
        var wrap:Null<FlexWrap> = null;
        var balance = false;
        for (p in parts) {
            switch p {
                case "wrap":
                    if (wrap != null) return null;
                    wrap = Wrap;
                case "wrap-reverse":
                    if (wrap != null) return null;
                    wrap = WrapReverse;
                case "balance":
                    if (balance) return null;
                    balance = true;
                case _:
                    return null;
            }
        }
        if (balance)
            return wrap == WrapReverse ? BalanceReverse : Balance;
        return wrap != null ? wrap : NoWrap;
    }

}
