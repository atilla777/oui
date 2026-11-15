# HUD recipe {#hud-recipe}

The HUD recipe is the narrow composition for a hold-to-restore HUD: popup and tooltip scopes from layers, a 1000 ms threshold from hold, and mock HP that the application owns. It is not the Lab screen. [Lab HUD](../lab/hud) is the wider showcase screen with the full shell, strings and atlas resources.

## Dependency closure {#dependency-closure}

Direct selected imports are `ui_layers`, `ui_hold` and `ui_hold/sdl`, plus `ui_base`, `ui_layout`, `ui_interaction`, `ui_style`, `ui_text`, `ui_sdl` and `ui_sdl_text`; the only transitive addition is Unicode through text.

| Import | Role |
| --- | --- |
| `ui_layers` | Modal, popup and tooltip scopes; partition and availability are prepared before hold binding. |
| `ui_hold` | Hold state machine, 1000 ms threshold, progress and completions. |
| `ui_hold/sdl` | Normalizes physical SDL key events into hold intentions for the focused restore control. |
| `ui_base` | Publication, revisions, sequences and owning-copy primitives. |
| `ui_layout` | Deterministic geometry for the bounded fixture. |
| `ui_interaction` | Routing, focus and exclusive capture claims. |
| `ui_style` | Paint metadata for the composed boxes. |
| `ui_text` | Text preparation for labels. |
| `ui_sdl` | Native window, renderer and event intake. |
| `ui_sdl_text` | SDL3_ttf font generation for the supplied font. |
| `unicode_graphemes` | Transitive Unicode segmentation used by text. |

The recipe does not need `ui_controls`, `ui_editor`, `ui_collections`, `ui_gestures`, `ui_rich`, `ui_custom`, `ui_transitions`, translations, `ui_inspect`, `ui_wire` or `ui_debug`. It has no atlas loader, so the HUD recipe itself needs no libpng or zlib.

## Ownership and resources {#ownership-and-resources}

The application owns HP, the hold count and the effect: the kit reports progress and one completion, and the caller applies the restore and rebuilds. The application also supplies the font and its strings, and decides the popup and tooltip content. Prepare candidates, claims and owning copies before the commit barrier; recovery rebuilds the accepted model without replaying an effect or a held input front.

Plain Activate does not bypass the hold, an incomplete hold has no effect, a popup shields the hold, and focus loss cancels an in-progress hold. One new 1000 ms cycle yields at most one completion.

## Build and run {#build-and-run}

From a prepared native checkout/export with Odin, SDL3 and SDL3_ttf (the HUD recipe does not link the image codecs):

```sh
mkdir -p build
odin build tests/ui_recipes/hud/native -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon -out:build/hud-recipe
build/hud-recipe --font resources/font.ttf --locale en --size 800x600 --scale 1
# Or, for Russian:
build/hud-recipe --font resources/font.ttf --locale ru --size 800x600 --scale 1
```

This fixture opens a native window. Press F11 to run the bounded verification scenario; it prints `native-hud=ok threshold=999+1 loss=cancel failure=not-ready recovery=no-replay input=native-synthetic`. Press F12 to quit. Ordinary users run it in their own graphical session; agents must use the isolated display wrapper described in [the ISD document](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/isd.md).

## Verification {#verification}

The headless composition fixture and the native fixture were checked at the pinned revision with the vet flags above and `-define:ODIN_TEST_THREADS=1`:

```sh
odin build tests/ui_recipes/hud -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon -out:build/hud-recipe-headless
build/hud-recipe-headless
# recipe-hud effects=1 conflicts=1 live=0

odin test tests/ui_recipes/hud/native -collection:ui=kit -define:ODIN_TEST_THREADS=1 -vet -vet-style -vet-tabs -vet-semicolon
# Finished 1 test; the test was successful.

odin test kit/ui_hold -collection:ui=kit -define:ODIN_TEST_THREADS=1 -vet -vet-style -vet-tabs -vet-semicolon
# Finished 20 tests; all tests were successful.

odin test kit/ui_hold/sdl -collection:ui=kit -define:ODIN_TEST_THREADS=1 -vet -vet-style -vet-tabs -vet-semicolon
# Finished 4 tests; all tests were successful.

odin test kit/ui_layers -collection:ui=kit -define:ODIN_TEST_THREADS=1 -vet -vet-style -vet-tabs -vet-semicolon
# Finished 24 tests; all tests were successful.
```

The headless fixture checks the 999+1 ms threshold, one application effect, a rejected plain Activate, a rejected conflicting owner, `Not_Ready` after invalidation, recovery without replay, and zero live tracking memory. The native fixture uses a real SDL window and synthetic key events; it does not replace a full native acceptance pass.

## Runtime sources {#runtime-sources}

Pinned to `8bc09cff358aa629410437996520283ff98d77d9`: [headless fixture](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/tests/ui_recipes/hud/main.odin), [native fixture](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/tests/ui_recipes/hud/native/main.odin), [workload cycle](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/tests/ui_recipes/hud/native/cycle.odin), [cycle test](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/tests/ui_recipes/hud/native/cycle_test.odin), [native fixture support](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/tests/ui_recipes/native_fixture/fixture.odin), [Lab HUD composition](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/lab_hud.odin), [catalogue metadata](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/catalogue.odin), [recipes](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md#3-hud) and [resources](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md).

See [Lab HUD](../lab/hud), [HUD hold](../capabilities/hud) and [Using oui](../guide/using-oui) for the screen, its boundary and the package map.