import taffy.tree.TaffyTree;
import taffy.style.Style;
import taffy.geometry.SizeAvail;

class CompileAll {
    static function main() {
        final tree = new TaffyTree<Int>();
        final s = new Style();
        final n = tree.newLeaf(s);
        tree.computeLayout(n, taffy.geometry.SizeAvail.MAX_CONTENT);
        trace(tree.layout(n));
    }
}
