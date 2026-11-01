package;

import taffy.compute.Leaf;
import taffy.geometry.RectOf;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.AvailableSpace;
import taffy.style.Dimension;
import taffy.style.FlexDirection;
import taffy.style.LengthPercentage;
import taffy.style.Style;
import taffy.tree.NodeId;
import taffy.tree.TaffyTree;

/**
 * A small benchmark: a nested flex tree of text-like leaves, fully relaid out (cache cleared) every iteration.
 * Build: haxe -cp ../src -cp src -main Bench -D analyzer-optimize -js bin/bench.js (or -cpp bin/bench)
 */
class Bench {

    static function main() {
        final tree = new TaffyTree<Int>();
        final root = build(tree, 0);
        final available = new SizeOf<AvailableSpace>(Definite(1200), Definite(800));
        final measure = (inputs, nodeId, context:Null<Int>, style) -> Leaf.computeLeafLayout(inputs, style, (known, avail) -> {
            final w = known.width != null ? (known.width : Float) : 8.0 * (context != null ? context : 0);
            final h = known.height != null ? (known.height : Float) : 16.0;
            return new Size(w, h);
        });
        // Warm up
        for (_ in 0...20) {
            tree.markDirty(root);
            tree.computeLayoutWithMeasure(root, available, measure);
        }
        final iterations = 200;
        final start = haxe.Timer.stamp();
        for (_ in 0...iterations) {
            markAllDirty(tree, root);
            tree.computeLayoutWithMeasure(root, available, measure);
        }
        final elapsed = haxe.Timer.stamp() - start;
        final cachedStart = haxe.Timer.stamp();
        for (_ in 0...iterations) {
            tree.computeLayoutWithMeasure(root, available, measure);
        }
        final cachedElapsed = haxe.Timer.stamp() - cachedStart;
        trace('nodes: ${tree.totalNodeCount()}, full relayout: ${Math.round(elapsed / iterations * 100000) / 100} ms, cached: ${Math.round(cachedElapsed / iterations * 100000) / 100} ms');
    }

    static function markAllDirty(tree:TaffyTree<Int>, node:NodeId):Void {
        tree.markDirty(node);
        for (child in tree.children(node))
            markAllDirty(tree, child);
    }

    static function build(tree:TaffyTree<Int>, depth:Int):NodeId {
        final style = new Style();
        style.flexDirection = depth % 2 == 0 ? Column : Row;
        style.padding = new RectOf<LengthPercentage>(LengthPercentage.length(4), LengthPercentage.length(4), LengthPercentage.length(2), LengthPercentage.length(2));
        if (depth == 4) {
            final leafStyle = new Style();
            leafStyle.flexGrow = 1;
            return tree.newLeafWithContext(leafStyle, 3 + depth);
        }
        final children = [for (i in 0...5) build(tree, depth + 1)];
        style.flexGrow = 1;
        return tree.newWithChildren(style, children);
    }

}
