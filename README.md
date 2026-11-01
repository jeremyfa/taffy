# taffy (Haxe port)

A pure Haxe port of [taffy](https://github.com/DioxusLabs/taffy) **0.15.0**, the UI layout library written in Rust by the Taffy Authors (originally Visly Inc.), which implements:

- CSS Block layout (including floats, margin collapsing, `clear`, `align-content` on blocks)
- CSS Flexbox (including `flex-wrap: balance`)
- CSS Grid (including named lines and areas, `repeat()`, `minmax()`, `fit-content()`, auto-placement)
- out-of-flow (`position: absolute` / `fixed`) positioning, `direction: rtl`, scrollable overflow (content size), layout caching and pixel rounding.

It has no dependency (no Ceramic, no other haxelib) and targets every Haxe target. It is tuned for hxcpp and JavaScript, where it is meant to run every frame in a UI.

All credit for the layout algorithms goes to the upstream taffy project and its contributors. This port translates the Rust source file by file: each Haxe module starts with a header naming the Rust file it comes from. The code is distributed under the same MIT license as taffy (see [LICENSE](LICENSE)).

## What is ported

Everything enabled by the default feature set of taffy 0.15.0 (`std`, `taffy_tree`, `flexbox`, `flexbox_balance`, `grid`, `block_layout`, `float_layout`, `content_size`, `detailed_layout_info`), except:

- `calc()` values (the `calc` feature): `CompactLength` has no pointer payload, and the `resolve_calc_value` closures are gone from the API.
- `serde` and the `cssparser` based `parse` feature. Simple `parse(String)` functions are provided on style types instead (used by the tests).
- the `debug` / `profile` logging features.

## Differences with the Rust API

- Arithmetic is single precision like upstream (`f32`): every class of the `taffy` package is built with `taffy.util.F32.build` (declared in `extraParams.hxml`, so it applies wherever the library is used with `-lib taffy`), which rounds the result of each float `+`, `-`, `*`, `/` and each float literal to the nearest `f32`. This is exact, not an approximation, and gives the same layouts as upstream where doubles would round some positions to the other side of a half pixel. Define `taffy_f64` to compute in double precision instead (faster, but not identical to upstream). Builds that add `src` with `-cp` instead of `-lib taffy` must add the line of `extraParams.hxml` themselves (as `test/build.hxml` does).

- Names are converted to camelCase (`compute_layout_with_measure` becomes `computeLayoutWithMeasure`). Types keep their Rust names, except `Float` (the CSS `float` property) which is `CssFloat`.
- `Option<f32>` is `Null<Float>`.
- Geometry: `Size`, `Rect`, `Point` and `Line` are concrete `Float` classes. Generic versions are `SizeOf<T>`, `RectOf<T>`, `PointOf<T>`, `LineOf<T>` (for example `SizeOf<AvailableSpace>`, `SizeOf<Null<Float>>`, `RectOf<LengthPercentageAuto>`). Geometry objects are immutable: use `withWidth()`, `withMain()`... instead of mutating them. Helpers for `SizeOf<Null<Float>>` and `SizeOf<AvailableSpace>` are static extensions: `using taffy.geometry.SizeOf;`.
- `AvailableSpace` is a Haxe enum (`Definite(v)`, `MinContent`, `MaxContent`). Compare values with `equals()` (from `using taffy.style.AvailableSpace;`), not `==`.
- `Dimension`, `LengthPercentage`, `LengthPercentageAuto`, `MinTrackSizingFunction` and `MaxTrackSizingFunction` are abstracts over `CompactLength`.
- The Rust style traits (`CoreStyle`, `FlexboxContainerStyle`, `GridContainerStyle`...) are collapsed into the concrete `Style` class. The tree traits (`LayoutPartialTree`, `LayoutFlexboxContainer`, `LayoutGridContainer`, `LayoutBlockContainer`, `LayoutContainingBlock`, `CacheTree`, `RoundTree`, `PrintTree`) are Haxe interfaces, so the layout algorithms can run on any tree implementation, like upstream.
- `TaffyTree` errors are thrown as `TaffyError` values instead of being returned as `Result`.

## Usage

```haxe
import taffy.compute.Leaf;
import taffy.geometry.Size;
import taffy.geometry.SizeOf;
import taffy.style.AvailableSpace;
import taffy.style.Dimension;
import taffy.style.Style;
import taffy.tree.TaffyTree;

class Example {

    static function main() {
        // The type parameter is the context data attached to leaves (here: a text)
        final tree = new TaffyTree<String>();

        final text = tree.newLeafWithContext(new Style(), "Hello");

        final rootStyle = new Style();
        rootStyle.display = Flex;
        rootStyle.size = new SizeOf<Dimension>(Dimension.length(400), Dimension.auto());
        final root = tree.newWithChildren(rootStyle, [text]);

        tree.computeLayoutWithMeasure(
            root,
            new SizeOf<AvailableSpace>(MaxContent, MaxContent),
            (inputs, nodeId, context, style) -> Leaf.computeLeafLayout(inputs, style, (knownDimensions, availableSpace) -> {
                if (context == null)
                    return Size.ZERO;
                // Measure the text here (10 x 20 pixels per character in this example)
                final width = knownDimensions.width != null ? knownDimensions.width : context.length * 10.0;
                final height = knownDimensions.height != null ? knownDimensions.height : 20.0;
                return new Size(width, height);
            })
        );

        final layout = tree.layout(text);
        trace(layout.location.x, layout.location.y, layout.size.width, layout.size.height);
    }

}
```

Main entry points:

| Haxe | Rust |
| --- | --- |
| `taffy.tree.TaffyTree` | `TaffyTree` (`newLeaf`, `newLeafWithContext`, `newWithChildren`, `addChild`, `setChildren`, `setStyle`, `style`, `computeLayout`, `computeLayoutWithMeasure`, `layout`, `unroundedLayout`, `markDirty`...) |
| `taffy.style.Style` | `Style` (all fields, camelCase) |
| `taffy.compute.Leaf.computeLeafLayout` | `compute_leaf_layout` |
| `taffy.compute.Compute` | `compute_root_layout`, `compute_cached_layout`, `compute_hidden_layout`, `round_layout` |
| `taffy.compute.BlockLayout`, `FlexboxLayout`, `GridLayout` | `compute_block_layout`, `compute_flexbox_layout`, `compute_grid_layout` |
| `taffy.compute.Oof` | `compute_oof_layout`, `compute_oof_layout_for_area`, `resolve_static_offset` |
| `taffy.tree.Cache` | `Cache` |

## Tests

The `test` folder contains a runner that does not need Ceramic:

- a port of `tests/xml.rs`, the data driven test harness of taffy: each XML fixture describes a tree of nodes and the layout computed by Chrome, compared with a tolerance of 0.1 like upstream;
- a port of the hand written tests of `tests/hand_written`.

A small representative subset of the fixtures (52 files) is copied in `test/fixtures` (they come from the taffy repository, MIT license, Taffy Authors: see `test/fixtures/LICENSE`). To run the whole upstream suite (about 6500 fixtures), point the runner to the `tests/xml` folder of a taffy checkout.

```sh
cd test
./run.sh                                  # JavaScript build, run with node on test/fixtures
TAFFY_FIXTURES=/path/to/taffy/tests/xml ./run.sh
./run.sh /path/to/taffy/tests/xml --category flex --filter align --verbose
haxe build-cpp.hxml && ./bin/cpp/Main /path/to/taffy/tests/xml   # hxcpp build
```

`run.sh` uses `haxe` from the `PATH` (override with the `HAXE` environment variable).

## License

MIT, like upstream taffy. See [LICENSE](LICENSE): Copyright (c) 2018 Visly Inc., Copyright (c) 2026 Taffy Authors.
