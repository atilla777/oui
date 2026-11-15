# Settings recipe {#settings-recipe}

The Settings recipe is the restricted headless composition for the settings
pattern: one modal layer with a single-line name editor and one checkbox, built
from `ui:ui_layers`, `ui:ui_controls` and `ui:ui_editor`. Its executable subject is
`tests/ui_recipes/settings/main.odin`. The windowed draft, apply, confirmation and
discard flow is the existing consumer code in
`consumer/ui_showcase/app/lab_menu*`; this recipe adds no second
implementation. The [Lab settings](../labs/settings) page shows that screen and
its genuine native captures.

## Boundary {#boundaries}

Selected direct imports of the fixture are `ui_layers`, `ui_controls`,
`ui_editor`, `ui_controls/sdl`, `ui_editor/sdl`, `ui_base`, `ui_layout`,
`ui_interaction` and `ui_text`. The complete compile closure also contains
`ui_scroll`, `ui_style`, `ui_sdl`, `ui_sdl_text` and `unicode_graphemes`, and
nothing else. It does not import collections, gestures, hold, rich text, custom
pages, transitions, inspection, testing, debug transport, translations or a
resource/atlas loader. The fixture supplies its own `Name`/`Enabled` strings and
deterministic text metrics. The SDL control and editor adapters are compiled and
constructed, but no SDL window, renderer, font, event loop or real text metrics
run, so this is not a second windowed application.

The fixture is deliberately smaller than the screen it supports. It publishes the
modal scope, the editor field and a checkbox, and checks the shared publication
rules; it has no slider, confirmation dialog, discard question or applied-value
display. Those remain the consumer's responsibility in the runtime reference
below.

## Runnable fixture {#fixture}

The snippet is complete: it builds the fixture with the exact flags and runs it.
From an oui root with Odin and the kit available as the `ui` collection:

```sh
mkdir -p build
odin build tests/ui_recipes/settings -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon -out:build/settings-recipe
build/settings-recipe
```

Verified stdout on the documented native environment:

```text
recipe-settings effects=1 conflicts=1 live=0
```

The numbers are the fixture's own results, not a smoke signal. `effects=1` is one
checkbox proposal that yields exactly one application outcome; `conflicts=1` is
the deliberate refusal of a second capture family claiming the same editor field
before anything is published; `live=0` is the tracking allocator after destroy.
The same run also asserts the modal initial focus and editor scope, that a second
action cannot consume an already invalidated frame, that submitting after
invalidation is `Not_Ready`, and that an owning reader copied before commit still
reads its value after the publisher is destroyed.

## Runtime reference {#runtime}

The windowed reference is the existing showcase section, not a new example:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section lab-settings --locale en --size 1280x960 --scale 1
```

`--section lab-menu` opens the same consumer on its Lab menu page, where the
settings entry leads to the same dialog. The build adds libpng and zlib through
`pkg-config` and links SDL3 and SDL3_ttf through Odin's vendor bindings; SDL3,
SDL3_ttf, libpng, zlib, the two supplied fonts and both atlas manifests must be
installed and present at runtime. The showcase binary is the large union of all
gallery and Lab packages, so it is wider than the fixture closure above; that
union is what makes the connected render, input and confirmation flow available. The command
opens a native window. Agents must use the
[isolated display wrapper](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/isd.md),
never the main desktop.

## Ownership and limits {#ownership}

The consumer owns the name draft and applied name, the Enabled and Amount drafts,
and the decisions that confirm or discard them. Apply validates the 1–64 grapheme
draft and asks for confirmation; only Confirm copies the shown revision into the
applied values, once, guarded by a pending revision and a consumed-token check, so
a stale confirmation applies nothing and recovery never replays Apply. Cancel or
Back to catalogue ask before discarding a dirty draft and restore the applied
values when that is chosen. The name is single-line with no IME, undo or
normalization; the 64-cluster bound belongs to the consumer, not to `ui_editor`.
Everything is process-local: the values are a mock with no disk persistence.

## Sources {#sources}

Sources at `8bc09cff358aa629410437996520283ff98d77d9`:
[restricted fixture](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/tests/ui_recipes/settings/main.odin),
[settings recipe contract](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md),
[dialog composition](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/lab_menu.odin),
[applied settings model](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/lab.odin),
[editor package](https://github.com/atilla777/oui/tree/8bc09cff358aa629410437996520283ff98d77d9/kit/ui_editor),
[controls package](https://github.com/atilla777/oui/tree/8bc09cff358aa629410437996520283ff98d77d9/kit/ui_controls),
and [resource requirements](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md).
