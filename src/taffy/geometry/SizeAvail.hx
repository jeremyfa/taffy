// Ported from taffy 0.15.0: src/geometry.rs, src/style/available_space.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.geometry;

import taffy.style.AvailableSpace;
import taffy.style.FlexDirection;
import taffy.util.OptionalFloat;

using taffy.style.AvailableSpace;

/**
 * The available space in each axis (Rust `Size<AvailableSpace>`).
 *
 * `AvailableSpace` is a plain float, so the fields are unboxed (the generic
 * `SizeOf<AvailableSpace>` stored `Dynamic` fields on hxcpp).
 *
 * Immutable: every operation returns a new instance.
 */
@:structInit
class SizeAvail {

    /** Both axes set to `MaxContent` (Rust `Size::MAX_CONTENT`) */
    public static final MAX_CONTENT:SizeAvail = new SizeAvail(MaxContent, MaxContent);

    /** Both axes set to `MinContent` (Rust `Size::MIN_CONTENT`) */
    public static final MIN_CONTENT:SizeAvail = new SizeAvail(MinContent, MinContent);

    /** The x extent of the rectangle */
    public final width:AvailableSpace;

    /** The y extent of the rectangle */
    public final height:AvailableSpace;

    public inline function new(width:AvailableSpace, height:AvailableSpace) {
        #if taffy_census
        taffy.util.Census.availableSpace(width, 'SizeAvail.new');
        taffy.util.Census.availableSpace(height, 'SizeAvail.new');
        #end
        this.width = width;
        this.height = height;
    }

    /** Get either the width or height depending on the `AbsoluteAxis` passed in */
    public inline function getAbs(axis:AbsoluteAxis):AvailableSpace {
        return axis == Horizontal ? width : height;
    }

    /** Get either the width or height depending on the `AbstractAxis` passed in */
    public inline function get(axis:AbstractAxis):AvailableSpace {
        return axis == Inline ? width : height;
    }

    /** Return a copy with the given axis set to value */
    public inline function with(axis:AbstractAxis, value:AvailableSpace):SizeAvail {
        final inl = axis == Inline;
        return new SizeAvail(inl ? value : width, inl ? height : value);
    }

    /** Swap width and height */
    public inline function transpose():SizeAvail {
        return new SizeAvail(height, width);
    }

    /** Applies the function `f` to both the width and height */
    public inline function map(f:AvailableSpace->AvailableSpace):SizeAvail {
        return new SizeAvail(f(width), f(height));
    }

    public inline function withWidth(value:AvailableSpace):SizeAvail {
        return new SizeAvail(value, height);
    }

    public inline function withHeight(value:AvailableSpace):SizeAvail {
        return new SizeAvail(width, value);
    }

    /** Get the main axis value for the given flex direction */
    public inline function main(direction:FlexDirection):AvailableSpace {
        return direction.isRow() ? width : height;
    }

    /** Get the cross axis value for the given flex direction */
    public inline function cross(direction:FlexDirection):AvailableSpace {
        return direction.isRow() ? height : width;
    }

    /** Return a copy with the main axis set to value */
    public inline function withMain(direction:FlexDirection, value:AvailableSpace):SizeAvail {
        final isRow = direction.isRow();
        return new SizeAvail(isRow ? value : width, isRow ? height : value);
    }

    /** Return a copy with the cross axis set to value */
    public inline function withCross(direction:FlexDirection, value:AvailableSpace):SizeAvail {
        final isRow = direction.isRow();
        return new SizeAvail(isRow ? width : value, isRow ? value : height);
    }

    /** Convert into a `SizeOpt`: definite values become present, others absent */
    public inline function intoOptions():SizeOpt {
        return new SizeOpt(width.intoOption(), height.intoOption());
    }

    /** If passed value is set then return `Definite` containing that value, else return self */
    public inline function maybeSet(value:SizeOpt):SizeAvail {
        return new SizeAvail(width.maybeSet(value.width), height.maybeSet(value.height));
    }

    public inline function maybeMin(rhs:SizeOpt):SizeAvail {
        return new SizeAvail(width.maybeMin(rhs.width), height.maybeMin(rhs.height));
    }

    public inline function maybeMax(rhs:SizeOpt):SizeAvail {
        return new SizeAvail(width.maybeMax(rhs.width), height.maybeMax(rhs.height));
    }

    public inline function maybeClamp(min:SizeOpt, max:SizeOpt):SizeAvail {
        return new SizeAvail(width.maybeClamp(min.width, max.width), height.maybeClamp(min.height, max.height));
    }

    public inline function maybeAdd(rhs:SizeOpt):SizeAvail {
        return new SizeAvail(width.maybeAdd(rhs.width), height.maybeAdd(rhs.height));
    }

    public inline function maybeSub(rhs:SizeOpt):SizeAvail {
        return new SizeAvail(width.maybeSub(rhs.width), height.maybeSub(rhs.height));
    }

    /** `maybe_sub` with a concrete rhs */
    public inline function maybeSubSize(rhs:Size):SizeAvail {
        return new SizeAvail(width.maybeSub(OptionalFloat.some(rhs.width)), height.maybeSub(OptionalFloat.some(rhs.height)));
    }

    /** `maybe_max` with a concrete rhs */
    public inline function maybeMaxSize(rhs:Size):SizeAvail {
        return new SizeAvail(width.maybeMax(OptionalFloat.some(rhs.width)), height.maybeMax(OptionalFloat.some(rhs.height)));
    }

    public inline function equals(other:SizeAvail):Bool {
        return width == other.width && height == other.height;
    }

    public function toString():String {
        return 'Size(width: ${width.toString()}, height: ${height.toString()})';
    }

}
