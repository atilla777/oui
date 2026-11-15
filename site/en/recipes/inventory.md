# Inventory recipe {#inventory-recipe}

The restricted inventory recipe is a headless Odin program: `tests/ui_recipes/inventory/main.odin` publishes two non-nested uniform list regions and one drag gesture chain in a single publication. It prepares and materializes both collections, projects them through one layout, binds one layers candidate and one gestures candidate, copies every reader before the commit barrier, and destroys the readers and states at the end. It opens no window, loads no font and has no event loop or renderer.

This recipe is not the Integration Lab screen. The Lab's `lab-inventory` adds the visible selection row, the pending-transfer modal with Cancel and Confirm, localized status messages and a display-order toggle on top of the same application decision. The wider example has its own [Lab inventory](../lab/inventory) page. The dependency list below applies only to `tests/ui_recipes/inventory`.

## Dependency closure {#dependencies}

The fixture imports `ui_base`, `ui_layout`, `ui_interaction`, `ui_layers`, `ui_collections`(+`/sdl`), `ui_gestures`(+`/sdl`), `ui_text` and `ui_sdl_text` directly. The selected SDL adapters reach `ui_sdl`, and the transitive closure adds `ui_style`, `ui_scroll` and `unicode_graphemes`.

| Import | Role in this recipe |
| --- | --- |
| `ui_base` | Publication primitives, errors, commit barrier and frame stamps. |
| `ui_layout` | Node, text and geometry preparation and validation. |
| `ui_interaction` | Targets, capture claims, focus and routing. |
| `ui_style` | Transitive through `ui_text` and `ui_sdl_text`; paint metadata. |
| `ui_text` | Deterministic headless text preparation and measured layout. |
| `ui_sdl` | The selected SDL3 backend, reached through the collection and gesture SDL adapters; compiled, but no window or event loop runs. |
| `ui_sdl_text` | SDL3_ttf font and text adapter; compiled, no font is loaded. |
| `ui_scroll` | Transitive through collections and gestures; one offset owner per region. |
| `ui_collections` | Two uniform list descriptions, materialization, stable item IDs and selection. |
| `ui_collections/sdl` | SDL adapter for collection input; referenced, not driven by physical input here. |
| `ui_gestures` | Drag source, drop targets, Begin/Aim/End and the bounded proposal. |
| `ui_gestures/sdl` | SDL adapter for gesture input; referenced, not driven by physical input here. |
| `unicode_graphemes` | Transitive through `ui_text`; extended grapheme segmentation. |

No other UI family is needed: the recipe does not import `ui_controls`, `ui_editor`, `ui_hold`, `ui_rich`, `ui_custom`, `ui_composition`, `ui_world`, `ui_transitions`, `translations`, `ui_inspect`, `ui_wire`, `ui_debug` or `ui_testing`. It has no atlas loader, so libpng and zlib are not part of this recipe. Compare the project's [recipes document](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md#5-inventory) for the same boundary.

## Ownership and resources {#ownership}

The application owns the meaningful state: both panels, their card membership, the selected row and the pending transfer decision. `tests/ui_recipes/inventory/main.odin` is a pure headless publisher over that state. UI families own only the technical state described by the [lifecycle contract](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/lifecycle.md): prepared candidates, capture claims and fallible copies are validated before the commit barrier, then publication, dispatch, one application outcome, rebuild and render follow. A proposal is not an effect, and recovery rebuilds the accepted model without replaying input.

Stable row IDs come from the application's item data, not from a display index. Row activation selects an item; the separate handle of the selected item is the `Drag_Source`, and panel headers are `Drop_Target`s. Rows never own drag and never own an ordinary scroll state: each list region has exactly one offset owner, and two regions in one publication must not share a region ID. `Begin`/`Aim`/`End` produces a copied, bounded pending proposal and does not move the item. `Cancel` has no membership effect. `Confirm` re-checks the reader lifetime, pending token, model revision and source membership and moves the item exactly once; same-panel, stale-model, unknown-card and unknown-target requests are refused. After the confirmed move the stable ID is looked up in the other container, so selection follows the item rather than a display position.

This fixture needs no native resources. It compiles the SDL and SDL3_ttf adapters and asserts only their presence, uses deterministic geometry instead of real text metrics, and loads no font, atlas, PNG or system library. Do not infer font licensing or atlas notices from this recipe: the project's MIT license does not relicense fonts, Unicode data or native dependencies; pins and notices are in [resources](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md).

## Build and run {#build-and-run}

From a prepared source or portable root with Odin `dev-2026-10-nightly:84bc3fc`:

```sh
mkdir -p build
odin build tests/ui_recipes/inventory -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon -out:build/inventory-recipe
./build/inventory-recipe
```

This is a headless fragment: the program opens no window, accepts no physical input and prints one oracle line. On the pinned revision the actual output was:

```text
recipe-inventory effects=1 conflicts=1 live=0
```

`effects=1` is the single applied application outcome after the copied proposal; `conflicts=1` is the refused attempt to give one row both a collections claim and a gestures claim; `live=0` is the tracking allocator's live byte count after every reader and state was destroyed. The command exited 0. The oracle proves the real dispatch, publication and retention path with a tracking allocator, not merely non-nil symbols.

## Verification {#verify}

The headless oracle above was executed on Linux x86_64 with the pinned Odin release. It does not render or accept physical input, so it is not a display qualification.

The existing native fixture `tests/ui_recipes/inventory/native/main.odin` exercises the same recipe with a window, a supplied font and synthetic pointer events. It was built and run once through the project's verified isolated display wrapper: the window started, explicit focus was delivered, F11 ran the bounded scenario and printed

```text
native-inventory=ok two-regions=true drag-effect=1 stable-membership=true recovery=no-replay input=native-synthetic
```

then F12 requested cleanup, the application exited 0, and the run was stopped in `finally`. That scenario asserts one drag effect, the stable membership lookup in the other container, and a refused dispatch after publication invalidation without replay. The screenshots from that run are private evidence and are not site media.

> Fragment: the two commands below are not a complete agent session. `start` returns a run id, and the agent must then use `focus`, address every key/input/PNG to that run, send F11, read the journal, send F12, verify the application exit, and always `stop` in `finally`. Ordinary users should run the existing native example in the [Lab inventory](../lab/inventory) section instead.

```sh
odin build tests/ui_recipes/inventory/native -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon -out:build/inventory-native
python3 -B scripts/ui_isd.py start --profile standalone-menu --isd "$ISD" --consumer-root tests/ui_recipes/inventory/native --kit-root kit --font resources/font.ttf --locale en --size 800x600 --scale 1
```

The full portable check used for this documentation builds both fixtures from the exported root; see [checks](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/rules/checks.md). A passing build and this bounded scenario do not replace native display qualification and cover only Linux with the pinned inputs.

## Runtime sources {#sources}

Pinned to `8bc09cff358aa629410437996520283ff98d77d9`:

| File | Role |
| --- | --- |
| [main.odin](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/tests/ui_recipes/inventory/main.odin) | Headless publication, two list regions, gesture chain, copied readers and the oracle. |
| [native/main.odin](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/tests/ui_recipes/inventory/native/main.odin) | Native window, synthetic pointer scenario and F11/F12 controls. |
| [native_fixture/fixture.odin](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/tests/ui_recipes/native_fixture/fixture.odin) | Shared fixture initialization, event normalization, font and teardown checks. |
| [ui_collections](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/kit/ui_collections/README.md) | Region ownership, materialization, stable IDs and selection. |
| [ui_gestures](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/kit/ui_gestures/README.md) | Drag/drop candidates, proposal lifetime and refusal rules. |
| [recipes](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md#5-inventory) | The restricted recipe contract and its stated limits. |
| [lifecycle](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/lifecycle.md) | Prepare, commit, publish, outcome and recovery rules. |
| [ISD](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/isd.md) | The isolated display wrapper used for the native scenario. |

The broader package map and ownership rules are in [using oui](../guide/using-oui). For the visible screen with the modal, status messages and display-order toggle, see [Lab inventory](../lab/inventory).