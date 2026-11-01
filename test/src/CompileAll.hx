import taffy.tree.TaffyTree;
import taffy.style.Style;

class CompileAll {
    static function main() {
        final tree = new TaffyTree<Int>();
        final s = new Style();
        final n = tree.newLeaf(s);
        tree.computeLayout(n, new taffy.geometry.SizeOf<taffy.style.AvailableSpace>(MaxContent, MaxContent));
        trace(tree.layout(n));
    }
}
