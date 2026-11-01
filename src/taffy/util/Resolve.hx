// Ported from taffy 0.15.0: src/util/resolve.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.util;

import taffy.geometry.Rect;
import taffy.geometry.RectOf;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.Dimension;
import taffy.style.LengthPercentage;
import taffy.style.LengthPercentageAuto;

/**
 * Resolution of `Size` / `Rect` of style values against a context (Rust `MaybeResolve` / `ResolveOrZero` traits).
 *
 * The scalar versions are methods of `Dimension`, `LengthPercentage` and `LengthPercentageAuto`.
 * Use with `using taffy.util.Resolve;`.
 */
class ResolveSizeDimension {

    /** Resolve each axis against the matching axis of `context` */
    public static inline function maybeResolve(self:SizeOf<Dimension>, context:SizeOf<Null<Float>>):SizeOf<Null<Float>> {
        return new SizeOf<Null<Float>>(self.width.maybeResolve(context.width), self.height.maybeResolve(context.height));
    }

    /** Resolve each axis against the matching axis of `context`, defaulting to zero */
    public static inline function resolveOrZero(self:SizeOf<Dimension>, context:SizeOf<Null<Float>>):Size {
        return new Size(self.width.resolveOrZero(context.width), self.height.resolveOrZero(context.height));
    }

}

class ResolveSizeLengthPercentageAuto {

    /** Resolve each axis against the matching axis of `context` */
    public static inline function maybeResolve(self:SizeOf<LengthPercentageAuto>, context:SizeOf<Null<Float>>):SizeOf<Null<Float>> {
        return new SizeOf<Null<Float>>(self.width.maybeResolve(context.width), self.height.maybeResolve(context.height));
    }

    /** Resolve each axis against the matching axis of `context`, defaulting to zero */
    public static inline function resolveOrZero(self:SizeOf<LengthPercentageAuto>, context:SizeOf<Null<Float>>):Size {
        return new Size(self.width.resolveOrZero(context.width), self.height.resolveOrZero(context.height));
    }

}

class ResolveSizeLengthPercentage {

    /** Resolve each axis against the matching axis of `context` */
    public static inline function maybeResolve(self:SizeOf<LengthPercentage>, context:SizeOf<Null<Float>>):SizeOf<Null<Float>> {
        return new SizeOf<Null<Float>>(self.width.maybeResolve(context.width), self.height.maybeResolve(context.height));
    }

    /** Resolve each axis against the matching axis of `context`, defaulting to zero */
    public static inline function resolveOrZero(self:SizeOf<LengthPercentage>, context:SizeOf<Null<Float>>):Size {
        return new Size(self.width.resolveOrZero(context.width), self.height.resolveOrZero(context.height));
    }

}

class ResolveRectLengthPercentage {

    /** Resolve all sides against a single context, defaulting to zero */
    public static inline function resolveOrZero(self:RectOf<LengthPercentage>, context:Null<Float>):Rect {
        return new Rect(self.left.resolveOrZero(context), self.right.resolveOrZero(context), self.top.resolveOrZero(context), self.bottom.resolveOrZero(context));
    }

    /** Resolve left/right against `context.width` and top/bottom against `context.height`, defaulting to zero */
    public static inline function resolveOrZeroBySize(self:RectOf<LengthPercentage>, context:SizeOf<Null<Float>>):Rect {
        return new Rect(self.left.resolveOrZero(context.width), self.right.resolveOrZero(context.width), self.top.resolveOrZero(context.height), self.bottom.resolveOrZero(context.height));
    }

    /** Resolve all sides against a single context */
    public static inline function maybeResolve(self:RectOf<LengthPercentage>, context:Null<Float>):RectOf<Null<Float>> {
        return new RectOf<Null<Float>>(self.left.maybeResolve(context), self.right.maybeResolve(context), self.top.maybeResolve(context), self.bottom.maybeResolve(context));
    }

}

class ResolveRectLengthPercentageAuto {

    /** Resolve all sides against a single context, defaulting to zero */
    public static inline function resolveOrZero(self:RectOf<LengthPercentageAuto>, context:Null<Float>):Rect {
        return new Rect(self.left.resolveOrZero(context), self.right.resolveOrZero(context), self.top.resolveOrZero(context), self.bottom.resolveOrZero(context));
    }

    /** Resolve left/right against `context.width` and top/bottom against `context.height`, defaulting to zero */
    public static inline function resolveOrZeroBySize(self:RectOf<LengthPercentageAuto>, context:SizeOf<Null<Float>>):Rect {
        return new Rect(self.left.resolveOrZero(context.width), self.right.resolveOrZero(context.width), self.top.resolveOrZero(context.height), self.bottom.resolveOrZero(context.height));
    }

    /** Resolve all sides against a single context */
    public static inline function maybeResolve(self:RectOf<LengthPercentageAuto>, context:Null<Float>):RectOf<Null<Float>> {
        return new RectOf<Null<Float>>(self.left.maybeResolve(context), self.right.maybeResolve(context), self.top.maybeResolve(context), self.bottom.maybeResolve(context));
    }

    /** Resolve left/right against `context.width` and top/bottom against `context.height` (Rust `zip_size(.., maybe_resolve)`) */
    public static inline function maybeResolveBySize(self:RectOf<LengthPercentageAuto>, context:SizeOf<Null<Float>>):RectOf<Null<Float>> {
        return new RectOf<Null<Float>>(self.left.maybeResolve(context.width), self.right.maybeResolve(context.width), self.top.maybeResolve(context.height), self.bottom.maybeResolve(context.height));
    }

}
