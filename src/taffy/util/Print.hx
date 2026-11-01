// Ported from taffy 0.15.0: src/util/print.rs
// Original code Copyright (c) 2018 Visly Inc. and (c) 2026 Taffy Authors, licensed under MIT.
// Modified: translated from Rust to Haxe. See LICENSE.

package taffy.util;

import taffy.tree.NodeId;
import taffy.tree.PrintTree;

/**
 * Prints a debug representation of the computed layout for a tree of nodes
 */
class Print {

    /** Prints a debug representation of the computed layout for a tree of nodes, starting with the passed root node. */
    public static function printTree(tree:PrintTree, root:NodeId):Void {
        final s = writeTree(tree, root);
        #if sys
        std.Sys.println(s);
        #elseif js
        js.Syntax.code("console.log({0})", s);
        #else
        trace(s);
        #end
    }

    /** Returns a debug representation of the computed layout for a tree of nodes */
    public static function writeTree(tree:PrintTree, root:NodeId):String {
        final buf = new StringBuf();
        buf.add("TREE\n");
        printNode(buf, tree, root, false, "");
        return buf.toString();
    }

    static function printNode(buf:StringBuf, tree:PrintTree, nodeId:NodeId, hasSibling:Bool, linesString:String):Void {
        final layout = tree.getFinalLayout(nodeId);
        final display = tree.getDebugLabel(nodeId);
        final numChildren = tree.childCount(nodeId);
        final forkString = hasSibling ? "|-- " : "`-- ";
        buf.add('$linesString$forkString $display [x: ${layout.location.x} y: ${layout.location.y} w: ${layout.size.width} h: ${layout.size.height} content_w: ${layout.scrollableOverflowRect.right} content_h: ${layout.scrollableOverflowRect.bottom} border: l:${layout.border.left} r:${layout.border.right} t:${layout.border.top} b:${layout.border.bottom}, padding: l:${layout.padding.left} r:${layout.padding.right} t:${layout.padding.top} b:${layout.padding.bottom}] (NodeId($nodeId))\n');
        final bar = hasSibling ? "|   " : "    ";
        final newString = linesString + bar;
        for (index in 0...numChildren) {
            final child = tree.getChildId(nodeId, index);
            printNode(buf, tree, child, index < numChildren - 1, newString);
        }
    }

}
