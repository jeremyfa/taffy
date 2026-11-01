// Ported from taffy 0.15.0: src/tree/cache.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

/**
 * Clear operation outcome. See `Cache.clear()`
 */
enum abstract ClearState(Int) {

    /** Cleared some values */
    var Cleared = 0;

    /** Everything was already cleared */
    var AlreadyEmpty = 1;

}
