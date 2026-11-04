// Ported from taffy 0.15.0: src/compute/flexbox.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.flexbox;

import taffy.geometry.SizeOpt;
import taffy.style.FlexDirection;
import taffy.util.OptionalFloat;

/**
 * A mutable size owned by a `FlexItem` (its hypothetical and target sizes, which the algorithm
 * updates one axis at a time: Rust assigns `item.target_size.main = value` in place).
 *
 * Never shared: read its values, do not keep a reference to it.
 */
class FlexItemSize {

    public var width:Float = 0.0;

    public var height:Float = 0.0;

    public inline function new() {}

    /** Set both axes to zero */
    public inline function clear():Void {
        width = 0.0;
        height = 0.0;
    }

    /** Get the main axis value for the given flex direction */
    public inline function main(direction:FlexDirection):Float {
        return direction.isRow() ? width : height;
    }

    /** Get the cross axis value for the given flex direction */
    public inline function cross(direction:FlexDirection):Float {
        return direction.isRow() ? height : width;
    }

    /** Set the main axis value for the given flex direction */
    public inline function setMain(direction:FlexDirection, value:Float):Void {
        if (direction.isRow())
            width = value;
        else
            height = value;
    }

    /** Set the cross axis value for the given flex direction */
    public inline function setCross(direction:FlexDirection, value:Float):Void {
        if (direction.isRow())
            height = value;
        else
            width = value;
    }

    /** Both axes as a (new) `SizeOpt` */
    public inline function toSize():taffy.geometry.Size {
        return new taffy.geometry.Size(width, height);
    }

    public inline function toOptions():SizeOpt {
        return new SizeOpt(OptionalFloat.some(width), OptionalFloat.some(height));
    }

}
