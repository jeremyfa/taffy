// Ported from taffy 0.15.0: src/compute/block.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.compute.block;

import taffy.compute.float.FloatContext;

/**
 * Context for positioning Block and Float boxes within a Block Formatting Context
 */
class BlockFormattingContext {

    /** The float positioning context that handles positioning floats within this Block Formatting Context */
    public final floatContext:FloatContext = new FloatContext();

    /** Create a new `BlockFormattingContext` */
    public function new() {}

    /** Create an initial `BlockContext` for this `BlockFormattingContext` */
    public function rootBlockContext():BlockContext {
        return new BlockContext(this, 0.0, 0.0, 0.0, true, false, false);
    }

}
