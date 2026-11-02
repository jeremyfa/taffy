package hand_written;

import hand_written.TestHelpers.*;
import hand_written.TestHelpers.TestCase;
import hand_written.TestHelpers.TestNodeContext;
import taffy.compute.BlockLayout;
import taffy.compute.FlexboxLayout;
import taffy.compute.Leaf;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.CssFloat;
import taffy.style.Dimension;
import taffy.style.Display;
import taffy.style.FlexDirection;
import taffy.style.FlexWrap;
import taffy.style.Position;
import taffy.style.Style;
import taffy.tree.LayoutInput;
import taffy.tree.LayoutOutput;
import taffy.tree.NodeId;
import taffy.tree.OofCandidate;
import taffy.tree.OofCandidates;
import taffy.tree.TaffyTree;

/**
 * Tests of the objects that the layout algorithms reuse between calls instead of allocating them:
 * the shared empty `OofCandidates`, and the stacks of inputs, flex items, block items, block
 * formatting contexts and block contexts (taken and given back around each nested call).
 */
class ScratchReuseTests {

    public static function tests():Array<TestCase> {
        return [
            new TestCase("empty_candidates_are_shared_and_read_only", emptyCandidatesAreSharedAndReadOnly),
            new TestCase("reuse_stacks_are_given_back_after_layout", reuseStacksAreGivenBackAfterLayout),
            new TestCase("layout_inside_a_measure_function", layoutInsideAMeasureFunction),
            new TestCase("relayout_gives_the_same_layout", relayoutGivesTheSameLayout),
        ];
    }

    /** The depths of every reuse stack (all zero between two top-level layouts) */
    static function stackDepths():String {
        return @:privateAccess [
            LayoutInput.poolDepth,
            FlexboxLayout.scratchLevel,
            FlexboxLayout.itemPoolTop,
            BlockLayout.bfcPoolTop,
            BlockLayout.itemPoolTop,
            BlockLayout.itemArrayLevel,
            BlockLayout.subContextPoolTop
        ].join(",");
    }

    static function sized(width:Float, height:Float):SizeOf<Dimension> {
        return new SizeOf<Dimension>(Dimension.length(width), Dimension.length(height));
    }

    static function emptyCandidatesAreSharedAndReadOnly() {
        final list = new OofCandidates();
        Assert.isTrue(list.take() == OofCandidates.EMPTY, "taking an empty list gives the shared empty list");
        Assert.isTrue(list.clone() == OofCandidates.EMPTY, "copying an empty list gives the shared empty list");
        Assert.isTrue(OofCandidates.EMPTY.take() == OofCandidates.EMPTY);
        Assert.isTrue(OofCandidates.EMPTY.isEmpty());
        // Reading, translating and appending from the shared list are allowed
        OofCandidates.EMPTY.translate(new taffy.geometry.Point(1.0, 2.0));
        list.append(OofCandidates.EMPTY);
        Assert.isTrue(OofCandidates.EMPTY.isEmpty());
        // Adding to it throws
        var pushThrew = false;
        try {
            OofCandidates.EMPTY.push(new OofCandidate(0, 0, Position.Absolute, null));
        }
        catch (e:Dynamic) {
            pushThrew = true;
        }
        Assert.isTrue(pushThrew, "push on the shared empty list throws");
        final filled = new OofCandidates();
        filled.push(new OofCandidate(0, 0, Position.Absolute, null));
        var appendThrew = false;
        try {
            OofCandidates.EMPTY.append(filled);
        }
        catch (e:Dynamic) {
            appendThrew = true;
        }
        Assert.isTrue(appendThrew, "append into the shared empty list throws");
        Assert.isTrue(OofCandidates.EMPTY.isEmpty());
        Assert.eqInt(filled.length(), 1, "the source list is left untouched when append throws");
    }

    /** A tree mixing flex (single and multi-line), block (with floats, nested block contexts) and absolute boxes */
    static function buildMixedTree(tree:TaffyTree<TestNodeContext>):NodeId {
        final leaf = (w:Float, h:Float) -> tree.newLeaf(st(s -> s.size = sized(w, h)));
        final text = () -> tree.newLeafWithContext(st(s -> {}), TestNodeContext.ahemText("HH HH HHH H", Horizontal));
        final row = tree.newWithChildren(st(s -> {
            s.display = Display.Flex;
            s.flexWrap = FlexWrap.Wrap;
            s.gap = new SizeOf(length(3.0), length(4.0));
        }), [leaf(40.0, 10.0), text(), leaf(60.0, 20.0), text(), leaf(30.0, 30.0)]);
        final floats = tree.newWithChildren(st(s -> s.display = Display.Block), [
            tree.newLeaf(st(s -> {
                s.float = CssFloat.Left;
                s.size = sized(30.0, 15.0);
            })),
            tree.newWithChildren(st(s -> s.display = Display.Block), [text(), leaf(10.0, 5.0)]),
            tree.newLeaf(st(s -> {
                s.position = Position.Absolute;
                s.size = sized(5.0, 5.0);
            })),
            text()
        ]);
        final column = tree.newWithChildren(st(s -> {
            s.display = Display.Flex;
            s.flexDirection = FlexDirection.Column;
            s.position = Position.Relative;
        }), [row, floats, tree.newWithChildren(st(s -> s.display = Display.Grid), [leaf(10.0, 10.0), text()])]);
        return tree.newWithChildren(st(s -> {
            s.display = Display.Block;
            s.size = new SizeOf<Dimension>(Dimension.length(200.0), Dimension.auto());
        }), [column, tree.newLeaf(st(s -> {
            s.position = Position.Absolute;
            s.size = sized(7.0, 7.0);
        }))]);
    }

    static function layoutText(tree:TaffyTree<TestNodeContext>, node:NodeId):String {
        final buf = new StringBuf();
        function visit(id:NodeId, depth:Int) {
            final l = tree.layout(id);
            buf.add('$depth ${l.location.x} ${l.location.y} ${l.size.width} ${l.size.height} ${l.scrollableOverflowRect.right} ${l.scrollableOverflowRect.bottom}\n');
            for (child in tree.children(id))
                visit(child, depth + 1);
        }
        visit(node, 0);
        return buf.toString();
    }

    static function reuseStacksAreGivenBackAfterLayout() {
        final before = stackDepths();
        final tree = newTestTree();
        final root = buildMixedTree(tree);
        tree.computeLayoutWithMeasure(root, definite(300.0, 400.0), testMeasureFunction);
        Assert.eqStr(stackDepths(), before, "every reuse stack is back to its depth");
        tree.computeLayoutWithMeasure(root, MAX_CONTENT, testMeasureFunction);
        Assert.eqStr(stackDepths(), before, "every reuse stack is back to its depth");
    }

    /**
     * A measure function that lays out another tree while the outer layout is in progress (the
     * reuse stacks are shared by every tree): the outer layout must be the same as with a measure
     * function returning the inner sizes directly.
     */
    static function layoutInsideAMeasureFunction() {
        // The size of the inner tree for a given width, computed by a full layout of its own
        final innerSize = (width:Float) -> {
            final inner = newTestTree();
            final innerRoot = buildMixedTree(inner);
            inner.computeLayoutWithMeasure(innerRoot, definite(width, 1000.0), testMeasureFunction);
            return inner.layout(innerRoot).size;
        };
        final build = (tree:TaffyTree<TestNodeContext>) -> {
            final children = [for (i in 0...3) tree.newLeafWithContext(st(s -> s.flexGrow = 1.0), TestNodeContext.zero())];
            children.push(buildMixedTree(tree));
            return tree.newWithChildren(st(s -> {
                s.display = Display.Flex;
                s.size = sized(900.0, 600.0);
            }), children);
        };
        final measure = (nested:Bool) -> (inputs:LayoutInput, nodeId:NodeId, context:Null<TestNodeContext>, style:Style) -> {
            if (context == null || !context.measureData.match(Zero))
                return testMeasureFunction(inputs, nodeId, context, style);
            return Leaf.computeLeafLayout(inputs, style, (known, available) -> {
                final width = known.width.isSome() ? known.width.unwrap() : 150.0;
                final size = nested ? innerSize(width) : cachedSizes.get(Std.string(width));
                if (!nested)
                    return size;
                cachedSizes.set(Std.string(width), size);
                return size;
            });
        };
        cachedSizes = new Map();
        final before = stackDepths();
        final nestedTree = newTestTree();
        final nestedRoot = build(nestedTree);
        nestedTree.computeLayoutWithMeasure(nestedRoot, MAX_CONTENT, measure(true));
        Assert.eqStr(stackDepths(), before, "every reuse stack is back to its depth");
        final plainTree = newTestTree();
        final plainRoot = build(plainTree);
        plainTree.computeLayoutWithMeasure(plainRoot, MAX_CONTENT, measure(false));
        Assert.eqStr(layoutText(nestedTree, nestedRoot), layoutText(plainTree, plainRoot), "same layout with a nested layout in the measure function");
    }

    static var cachedSizes:Map<String, Size>;

    static function markAllDirty(tree:TaffyTree<TestNodeContext>, node:NodeId):Void {
        tree.markDirty(node);
        for (child in tree.children(node))
            markAllDirty(tree, child);
    }

    /** Cache hits share their outputs (no copy): laying out again, with or without caches, gives the same layout */
    static function relayoutGivesTheSameLayout() {
        final tree = newTestTree();
        final root = buildMixedTree(tree);
        tree.computeLayoutWithMeasure(root, definite(300.0, 400.0), testMeasureFunction);
        final first = layoutText(tree, root);
        tree.computeLayoutWithMeasure(root, definite(300.0, 400.0), testMeasureFunction);
        Assert.eqStr(layoutText(tree, root), first, "cached relayout");
        // Another constraint, then back: the measurements cached for both are reused
        tree.computeLayoutWithMeasure(root, MAX_CONTENT, testMeasureFunction);
        final maxContent = layoutText(tree, root);
        tree.computeLayoutWithMeasure(root, definite(300.0, 400.0), testMeasureFunction);
        Assert.eqStr(layoutText(tree, root), first, "relayout after another constraint");
        markAllDirty(tree, root);
        tree.computeLayoutWithMeasure(root, definite(300.0, 400.0), testMeasureFunction);
        Assert.eqStr(layoutText(tree, root), first, "relayout after marking every node dirty");
        final fresh = newTestTree();
        final freshRoot = buildMixedTree(fresh);
        fresh.computeLayoutWithMeasure(freshRoot, MAX_CONTENT, testMeasureFunction);
        Assert.eqStr(layoutText(fresh, freshRoot), maxContent, "a new tree gives the same layout");
    }

}
