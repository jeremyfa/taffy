// Ported from taffy 0.15.0: src/compute/float.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.float;

import taffy.style.AvailableSpace;
import taffy.style.Clear;
import taffy.style.FloatDirection;
import taffy.util.Sys;

/**
 * Context for computing the intrinsic width contribution of a set of floats
 */
class FloatIntrinsicWidthCalculator {

    /** The available width of the container */
    final availableWidth:AvailableSpace;

    /** The running sums of the widths of adjacent uncleared floats on the left side */
    var sideSumLeft:Float = 0.0;

    /** The running sums of the widths of adjacent uncleared floats on the right side */
    var sideSumRight:Float = 0.0;

    /** The running total intrinsic width contribution */
    var contribution:Float = 0.0;

    /** The widest single float (the floats' min-content contribution) */
    var widest:Float = 0.0;

    public function new(availableWidth:AvailableSpace) {
        this.availableWidth = availableWidth;
    }

    /** Add a float to the computation */
    public function addFloat(width:Float, direction:FloatDirection, clear:Clear):Void {
        switch availableWidth {
            // Definite available width means the container is being fit-content sized.
            // The floats' max-content contribution (widths summed) is clamped by the available width in `result`.
            case Definite(_) | MaxContent:
                // A float that clears a side is placed below the floats on that side, so its
                // width does not accumulate with theirs.
                if (clear == Clear.Left || clear == Clear.Both)
                    sideSumLeft = 0.0;
                if (clear == Clear.Right || clear == Clear.Both)
                    sideSumRight = 0.0;
                if (direction == FloatDirection.Left)
                    sideSumLeft += width;
                else
                    sideSumRight += width;
                contribution = Sys.f32Max(contribution, sideSumLeft + sideSumRight);
            case MinContent:
                contribution = Sys.f32Max(contribution, width);
        }
        widest = Sys.f32Max(widest, width);
    }

    /** Get the computed float contribution to intrinsic width */
    public function result():Float {
        return switch availableWidth {
            // Fit-content sizing: clamp the max-content contribution between the available
            // width and the min-content contribution.
            case Definite(available): Sys.f32Max(Sys.f32Min(contribution, available), widest);
            case _: contribution;
        }
    }

}
