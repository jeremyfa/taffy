// Ported from taffy 0.15.0: src/tree/traits.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

/**
 * A marker interface which extends `TraversePartialTree`.
 *
 * Implementing this interface implies the additional guarantee that the child/children methods can be used to recurse
 * infinitely down the tree. Is required by `RoundTree` and `PrintTree`.
 */
interface TraverseTree extends TraversePartialTree {}
