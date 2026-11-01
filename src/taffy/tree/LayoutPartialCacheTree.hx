// Ported from taffy 0.15.0: src/tree/traits.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

/**
 * `LayoutPartialTree + CacheTree` (Rust uses `impl A + B` bounds)
 */
interface LayoutPartialCacheTree extends LayoutPartialTree extends CacheTree {}
