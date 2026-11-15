# Basic menu recipe {#basic-menu}

The standalone menu is the smallest executable example of an ordinary interactive screen: a main page with two buttons, a submenu with a language choice and Back, and no layers, controls or editor. The same program builds from the documented kit sources and runs with a caller-supplied font.

This recipe is not the Integration Lab screen. The Lab's `lab-menu` composes a modal layer, controls and an editor on top of the menu; it is a wider example with its own [Lab menu](../lab/menu) page. The dependency list below applies only to `consumer/standalone_menu`.

## Dependency closure {#dependencies}

The menu imports these selected families directly; `unicode_graphemes` is the only transitive UI package, reached through `ui_text`.

| Import | Role in this menu |
| --- | --- |
| `ui_base` | Publication primitives, errors and shared publication state. |
| `ui_layout` | Node, text and geometry preparation and validation. |
| `ui_interaction` | Targets, focus, routing and input intents. |
| `ui_style` | Paint metadata prepared from the accepted composition. |
| `ui_text` | Text preparation and measured layout. |
| `ui_sdl` | The selected SDL3 renderer, input and event backend. |
| `ui_sdl_text` | SDL3_ttf font and text adapter. |
| `unicode_graphemes` | Transitive through `ui_text`; extended grapheme segmentation. |

No other UI family is needed: this example does not import `ui_layers`, `ui_controls`, `ui_editor`, `ui_collections`, `ui_gestures`, `ui_rich`, `ui_hold`, `translations`, `ui_inspect`, `ui_wire`, `ui_debug` or `ui_testing`. It has no atlas loader, so libpng and zlib are not part of this recipe. Compare the project's [recipes document](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md#2-basic-menu) for the same boundary.

## Ownership and resources {#ownership}

The application owns the meaningful state: the page, the locale and the counter. `model/model.odin` is a pure reducer over those values; `runtime.odin` owns the typed publisher and the retained reader; `strings.odin` holds the application's own English and Russian strings. UI families own only the technical state described by the [lifecycle contract](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/lifecycle.md): prepare candidates, claims and fallible copies before the commit barrier, then publish, dispatch, apply one application outcome, rebuild and render. A proposal is not an effect, and recovery rebuilds the accepted model without replaying input.

The caller supplies the primary font with `--font`; the example does not search system fonts or embed a font through `#load`. Retain the font notices shipped with the selected font. The kit's MIT license does not relicense fonts, Unicode data or native dependencies; see [resources](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md) for pins and notices, and `consumer/standalone_menu/README.md` for the example's own resource note.

## Build and run {#build-and-run}

From a prepared source or portable root with Odin `dev-2026-10-nightly:84bc3fc`, SDL3 `3.4.16` and SDL3_ttf `3.2.2` available to the linker and loader:

```sh
mkdir -p build
odin build consumer/standalone_menu -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon -out:build/menu
build/menu --font resources/font.ttf --locale en --size 800x600 --scale 1
# Or the Russian UI:
build/menu --font resources/font.ttf --locale ru --size 800x600 --scale 1
```

The initial main page shows `Action` and `Submenu`; focus starts on `Action`. Tab reaches `Submenu` and Return opens it, where the language button and `Back` are offered. Return on the language button switches the UI locale. These are ordinary application outcomes, not hidden effects. Run one command at a time on a suitable graphical session.

These interactive commands are for ordinary users. Agents must not use the main display; they need a separately supplied, verified ISD through the project's [wrapper](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/isd.md) with their own run, explicit focus and cleanup.

## Verification {#verify}

The build and the tests below use the existing fixture without extra test flags in the production build:

```sh
odin test consumer/standalone_menu/model -vet -vet-style -vet-tabs -vet-semicolon -out:build/menu-model-tests
odin test consumer/standalone_menu -collection:ui=kit -define:STANDALONE_MENU_TEST=true -define:ODIN_TEST_THREADS=1 -vet -vet-style -vet-tabs -vet-semicolon -out:build/menu-tests
odin test kit/ui_sdl -define:ODIN_TEST_THREADS=1 -out:build/ui-sdl-tests
odin test kit/ui_sdl_text -define:ODIN_TEST_THREADS=1 -out:build/ui-sdl-text-tests
```

These commands were run against the pinned revision on Linux x86_64 with the versions above: the menu built, 2 model tests and 4 consumer tests passed, and the 17 SDL backend tests and 1 SDL text test passed. A passing build and tests do not replace native display qualification or cover other platforms. The README's allocation, reader lifetime and fault tests document the example's remaining bounded proof.

## Runtime sources {#sources}

Pinned to `8bc09cff358aa629410437996520283ff98d77d9`:

| File | Role |
| --- | --- |
| [main.odin](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/standalone_menu/main.odin) | SDL/TTF initialization, window, event loop and shutdown. |
| [options.odin](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/standalone_menu/options.odin) | Command-line options for font, locale, size and scale. |
| [runtime.odin](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/standalone_menu/runtime.odin) | Typed publisher, reader, render and recovery path. |
| [model/model.odin](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/standalone_menu/model/model.odin) | Pure application model and reducer. |
| [strings.odin](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/standalone_menu/strings.odin) | The example's own localized strings. |
| [README.md](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/standalone_menu/README.md) | Independent root, behavior, lifetime and test notes. |

The broader package map, ownership rules and compatibility limits are in [using oui](../guide/using-oui), the [recipes](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md) and the [resource documentation](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md). For the wider screen with layers, controls and an editor, see [Lab menu](../lab/menu).