// Ported from taffy 0.15.0: src/tree/traits.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

/**
 * Interface used by `Compute.computeCachedLayout` which allows cached layout results to be stored and retrieved.
 *
 * The `Cache` class implements a per-node cache that is compatible with this interface.
 */
interface CacheTree {

    /** Try to retrieve a cached result from the cache */
    function cacheGet(nodeId:NodeId, input:LayoutInput):Null<LayoutOutput>;

    /** Store a computed size in the cache */
    function cacheStore(nodeId:NodeId, input:LayoutInput, layoutOutput:LayoutOutput):Void;

    /** Clear all cache entries for the node */
    function cacheClear(nodeId:NodeId):Void;

}
