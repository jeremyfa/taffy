// New tests for the Haxe port (not in taffy): `TaffyTree.matchesRelayout`, the early cutoff
// used by Glaze's incremental layout. The fixtures are checked as a whole by `--cutoff-check`.

package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.geometry.SizeOf;
import taffy.style.Dimension;
import taffy.style.Display;
import taffy.style.FlexDirection;
import taffy.style.Style;
import taffy.tree.LayoutInput;
import taffy.tree.LayoutOutput;
import taffy.tree.NodeId;
import taffy.tree.TaffyTree;

class CutoffTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("same_subtree_matches", sameSubtreeMatches),
            new TestCase("other_size_does_not_match", otherSizeDoesNotMatch),
            new TestCase("inner_change_with_fixed_size_does_not_match", innerChangeWithFixedSizeDoesNotMatch),
            new TestCase("cleared_reference_does_not_match", clearedReferenceDoesNotMatch),
            new TestCase("block_container_does_not_match", blockContainerDoesNotMatch),
            new TestCase("block_flex_item_with_own_context_matches", blockFlexItemWithOwnContextMatches),
            new TestCase("block_flex_item_with_own_context_detects_size_change", blockFlexItemWithOwnContextDetectsSizeChange),
        ];
    }

    static function sized(width:Dimension, height:Dimension):Style {
        return st(s -> s.size = new SizeOf<Dimension>(width, height));
    }

    static function flexSized(width:Float, height:Float):Style {
        return st(s -> {
            s.display = Display.Flex;
            s.size = new SizeOf<Dimension>(Dimension.length(width), Dimension.length(height));
        });
    }

    /** A row with two leaves (`first` sized `width` x 20, then 30 x 20), laid out at 200 x 100 */
    static function row(taffy:TaffyTree<TestNodeContext>, firstWidth:Float):{root:NodeId, first:NodeId} {
        final first = taffy.newLeaf(sized(Dimension.length(firstWidth), Dimension.length(20.0)));
        final second = taffy.newLeaf(sized(Dimension.length(30.0), Dimension.length(20.0)));
        final root = taffy.newWithChildren(st(s -> s.flexDirection = FlexDirection.Row), [first, second]);
        taffy.computeLayoutWithMeasure(root, definite(200.0, 100.0), testMeasureFunction);
        return {root: root, first: first};
    }

    /** Replaces `old` by `replacement` in its parent without marking anything dirty */
    static function swap(taffy:TaffyTree<TestNodeContext>, old:NodeId, replacement:NodeId):Void {
        final nodes = @:privateAccess taffy.nodes;
        final parent = nodes[old].parent;
        final siblings = nodes[parent].children;
        siblings[siblings.indexOf(old)] = replacement;
        nodes[replacement].parent = parent;
        nodes[old].parent = -1;
    }

    static function sameSubtreeMatches() {
        final taffy = newTestTree();
        final tree = row(taffy, 50.0);
        final replacement = taffy.newLeaf(sized(Dimension.length(50.0), Dimension.length(20.0)));
        final reference = @:privateAccess taffy.nodes[tree.first].cache;
        swap(taffy, tree.first, replacement);
        Assert.isTrue(taffy.matchesRelayout(replacement, reference, new FunctionMeasurer()));
        // The results stay in the cache of the replacement (its parent placed the old node; the
        // caller gives the replacement its place, see Glaze's `TaffyLayoutEngine.processChanges`)
        Assert.isTrue(@:privateAccess taffy.nodes[replacement].cache.hasFinalLayout());
    }

    static function otherSizeDoesNotMatch() {
        // An auto sized box whose content changes size (`matchesRelayout` compares results, the
        // caller compares styles)
        final taffy = newTestTree();
        final inner = taffy.newLeaf(sized(Dimension.length(50.0), Dimension.length(20.0)));
        final box = taffy.newWithChildren(st(s -> s.display = Display.Flex), [inner]);
        final root = taffy.newWithChildren(st(s -> s.flexDirection = FlexDirection.Row), [box]);
        taffy.computeLayoutWithMeasure(root, definite(200.0, 100.0), testMeasureFunction);
        final newInner = taffy.newLeaf(sized(Dimension.length(60.0), Dimension.length(20.0)));
        final newBox = taffy.newWithChildren(st(s -> s.display = Display.Flex), [newInner]);
        final reference = @:privateAccess taffy.nodes[box].cache;
        swap(taffy, box, newBox);
        Assert.isTrue(!taffy.matchesRelayout(newBox, reference, new FunctionMeasurer()));
    }

    static function innerChangeWithFixedSizeDoesNotMatch() {
        // A fixed size box whose child changes: the box is placed the same by its parent, but a
        // flex row also asks its items for their min-content contribution (the automatic minimum
        // size), which depends on the content (10 then 30 here): a recorded result differs, so
        // the box is not matched and the row is laid out again (conservative)
        final taffy = newTestTree();
        final inner = taffy.newLeaf(sized(Dimension.length(10.0), Dimension.length(10.0)));
        final box = taffy.newWithChildren(flexSized(80.0, 40.0), [inner]);
        final root = taffy.newWithChildren(st(s -> s.flexDirection = FlexDirection.Row), [box]);
        taffy.computeLayoutWithMeasure(root, definite(200.0, 100.0), testMeasureFunction);
        final newInner = taffy.newLeaf(sized(Dimension.length(30.0), Dimension.length(10.0)));
        final newBox = taffy.newWithChildren(flexSized(80.0, 40.0), [newInner]);
        final reference = @:privateAccess taffy.nodes[box].cache;
        swap(taffy, box, newBox);
        Assert.isTrue(!taffy.matchesRelayout(newBox, reference, new FunctionMeasurer()));
    }

    static function blockContainerDoesNotMatch() {
        // Its children may share its parent's block formatting context: never checked alone
        final taffy = newTestTree();
        final inner = taffy.newLeaf(sized(Dimension.length(10.0), Dimension.length(10.0)));
        final box = taffy.newWithChildren(st(s -> s.display = Display.Block), [inner]);
        final root = taffy.newWithChildren(st(s -> s.display = Display.Block), [box]);
        taffy.computeLayoutWithMeasure(root, definite(200.0, 100.0), testMeasureFunction);
        final newInner = taffy.newLeaf(sized(Dimension.length(10.0), Dimension.length(10.0)));
        final newBox = taffy.newWithChildren(st(s -> s.display = Display.Block), [newInner]);
        final reference = @:privateAccess taffy.nodes[box].cache;
        swap(taffy, box, newBox);
        Assert.isTrue(!taffy.matchesRelayout(newBox, reference, new FunctionMeasurer()));
    }

    /** A block box sized by its content (`innerWidth` x 10) in a flex row, laid out at 200 x 100 */
    static function blockItem(taffy:TaffyTree<TestNodeContext>, innerWidth:Float):{root:NodeId, box:NodeId, inner:NodeId} {
        final inner = taffy.newLeaf(sized(Dimension.length(innerWidth), Dimension.length(10.0)));
        final box = taffy.newWithChildren(st(s -> s.display = Display.Block), [inner]);
        final root = taffy.newWithChildren(st(s -> s.flexDirection = FlexDirection.Row), [box]);
        taffy.computeLayoutWithMeasure(root, definite(200.0, 100.0), testMeasureFunction);
        return {root: root, box: box, inner: inner};
    }

    /** Clears the caches of a subtree (laid out again from scratch) */
    static function clearSubtree(taffy:TaffyTree<TestNodeContext>, id:NodeId):Void {
        final data = @:privateAccess taffy.nodes[id];
        data.cache.clear();
        for (child in data.children) {
            clearSubtree(taffy, child);
        }
    }

    static function blockFlexItemWithOwnContextMatches() {
        // A flex item is the root of its own block formatting context: its subtree laid out
        // again from scratch for the inputs its parent gave it gives the same results
        final taffy = newTestTree();
        final tree = blockItem(taffy, 40.0);
        final reference = @:privateAccess taffy.nodes[tree.box].cache.snapshot();
        final replacement = taffy.newLeaf(sized(Dimension.length(40.0), Dimension.length(10.0)));
        swap(taffy, tree.inner, replacement);
        clearSubtree(taffy, tree.box);
        Assert.isTrue(!taffy.matchesRelayout(tree.box, reference, new FunctionMeasurer()), 'refused without the flag');
        Assert.isTrue(taffy.matchesRelayout(tree.box, reference, new FunctionMeasurer(), true));
        Assert.eq(taffy.unroundedLayout(tree.box).size.width, 40.0);
        Assert.eq(taffy.unroundedLayout(replacement).size.width, 40.0);
    }

    static function blockFlexItemWithOwnContextDetectsSizeChange() {
        // Its content is narrower: the flex row measured its content size, which differs
        final taffy = newTestTree();
        final tree = blockItem(taffy, 40.0);
        final reference = @:privateAccess taffy.nodes[tree.box].cache.snapshot();
        final replacement = taffy.newLeaf(sized(Dimension.length(25.0), Dimension.length(10.0)));
        swap(taffy, tree.inner, replacement);
        clearSubtree(taffy, tree.box);
        Assert.isTrue(!taffy.matchesRelayout(tree.box, reference, new FunctionMeasurer(), true));
    }

    static function clearedReferenceDoesNotMatch() {
        final taffy = newTestTree();
        final tree = row(taffy, 50.0);
        final replacement = taffy.newLeaf(sized(Dimension.length(50.0), Dimension.length(20.0)));
        final reference = @:privateAccess taffy.nodes[tree.first].cache.snapshot();
        reference.clear();
        Assert.isTrue(!taffy.matchesRelayout(replacement, reference, new FunctionMeasurer()));
    }

}

/** The test measure function as a measurer */
private class FunctionMeasurer implements taffy.tree.LayoutMeasurer<TestNodeContext> {

    public function new() {}

    public function measureLeafNode(inputs:LayoutInput, nodeId:NodeId, nodeContext:TestNodeContext, style:Style):LayoutOutput {
        return testMeasureFunction(inputs, nodeId, nodeContext, style);
    }

}
