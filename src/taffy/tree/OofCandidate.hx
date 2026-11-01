// Ported from taffy 0.15.0: src/tree/layout.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.tree;

import taffy.geometry.PointOf;
import taffy.style.Position;

/**
 * A record of an out-of-flow (`position: absolute` or `position: fixed`) box which has not yet
 * been laid out because its containing block is an ancestor of its parent.
 */
@:structInit
class OofCandidate {

    /** The id of the out-of-flow node */
    public final node:NodeId;

    /** The `order` value that the node's layout should be assigned (its child index within its parent) */
    public final order:Int;

    /** The position style of the node (`Absolute` or `Fixed`) */
    public final position:Position;

    /** The static position of the box in each axis */
    public final staticPosition:PointOf<AxisStaticPosition>;

    public inline function new(node:NodeId, order:Int, position:Position, staticPosition:PointOf<AxisStaticPosition>) {
        this.node = node;
        this.order = order;
        this.position = position;
        this.staticPosition = staticPosition;
    }

}
