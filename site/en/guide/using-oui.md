# Using oui

## Choose a boundary {#choose-a-boundary}

Choose the smallest composition your application needs, then follow its authoritative recipe and fixture. The links describe existing examples, not new APIs or universal build profiles.

| Need | Recipe | Source / fixture |
| --- | --- | --- |
| Headless geometry only | [Layout-only](https://github.com/atilla777/oui/blob/main/docs/recipes.md#1-layout-only) | [layout fixture](https://github.com/atilla777/oui/blob/main/tests/ui_foundation/layout_only/main.odin) |
| Simple interactive screen | [Basic menu](https://github.com/atilla777/oui/blob/main/docs/recipes.md#2-basic-menu) | [standalone menu](https://github.com/atilla777/oui/tree/main/consumer/standalone_menu) |
| Layers and hold | [HUD](https://github.com/atilla777/oui/blob/main/docs/recipes.md#3-hud) | [HUD fixture](https://github.com/atilla777/oui/blob/main/tests/ui_recipes/hud/main.odin) |
| Controls and editor | [Settings](https://github.com/atilla777/oui/blob/main/docs/recipes.md#4-settings) | [settings fixture](https://github.com/atilla777/oui/blob/main/tests/ui_recipes/settings/main.odin) |
| Collections and gestures | [Inventory](https://github.com/atilla777/oui/blob/main/docs/recipes.md#5-inventory) | [inventory fixture](https://github.com/atilla777/oui/blob/main/tests/ui_recipes/inventory/main.odin) |
| Opt-in inspection and debugging | [Development tools](https://github.com/atilla777/oui/blob/main/docs/recipes.md#6-development-tools) | [tools fixture](https://github.com/atilla777/oui/blob/main/tests/ui_recipes/tools/main.odin) |

The [portable check](https://github.com/atilla777/oui/blob/main/scripts/test-ui-showcase#L132) builds these six in separate restricted roots and runs all except the menu in that loop. HUD, settings and inventory fixtures exercise headless publication with deterministic inputs; their compiled adapters do not make them native display tests. The connected showcase is a **larger union**, not the minimum dependency set for any screen. See [qualification](https://github.com/atilla777/oui/blob/main/docs/qualification.md) for the distinct evidence and its limits.

## Package and dependency map {#package-map}

Use the collection mapping `-collection:ui=kit` and narrow imports such as `import layout "ui:ui_layout"`; there is no supported legacy umbrella import. The [API map](https://github.com/atilla777/oui/blob/main/docs/api.md) lists declarations and direct dependency relationships; the [kit source](https://github.com/atilla777/oui/tree/main/kit) and compiler determine the actual graph.

- `ui_base` owns publication primitives; `ui_layout` depends on base. Layout-only needs neither interaction nor text, SDL, fonts or tools.
- `ui_interaction` adds routing and focus; `ui_style` provides paint metadata; `ui_text` adds style and `unicode_graphemes`. Text does not itself select an SDL backend.
- Select families as needed: `ui_layers`, `ui_scroll`, `ui_controls`, `ui_hold`, `ui_editor`, `ui_collections`, `ui_gestures`, `ui_rich`, `ui_transitions`, `ui_custom`, `ui_composition` and `ui_world`. Their dependencies differ: for example controls include layers/scroll/style/text, while collections and gestures add scroll. Consult the API map and chosen recipe rather than assuming independence.
- `ui_sdl` and `ui_sdl_text` are separate backend choices; family `sdl` adapters are selected separately. SDL text needs SDL3_ttf and supplied font resources; a controls SDL adapter alone does not require TTF. Translations and the atlas loader are consumer choices, not UI core.
- `ui_inspect`, `ui_wire`, `ui_debug` and `ui_testing` are opt-in tooling; `ui_testing` is for tests, not a production binary. The tools recipe's headless set does not require SDL, text or fonts. A debug endpoint requires explicit gates and permission, not merely an import.

## Ownership and resources {#ownership-and-resources}

The application owns meaningful model values, revisions and outcomes; UI families own selected technical state. Use one interaction/focus owner and one publication. With SDL, normalize each physical event once and share that input with selected adapters. A proposal is not an applied effect: the application checks it and decides the outcome.

Follow the [lifecycle contract](https://github.com/atilla777/oui/blob/main/docs/lifecycle.md): prepare candidates, claims and all fallible copies before validation and the commit barrier; then publish, dispatch, apply an app outcome, rebuild and render. A failed prepare, copy or render invalidates readiness; explicit recovery rebuilds the accepted model without replaying an effect or input. Old pixels and historical readers are not authority for current actions or snapshots.

Owning copies must be destroyed once with their original allocator; ordinary struct assignment is not an owning copy. Borrowed inputs and callbacks have bounded lifetimes. Retained readers and font/image generations must be released before their allocator or backend; close selected editor input and destroy readers before the backend. Consult the lifecycle for the full shutdown and failure order.

Fonts, Unicode data and native codecs have separate dependencies and notices; the kit's MIT license does not relicense them. See [resources](https://github.com/atilla777/oui/blob/main/docs/resources.md) for pins, notices and selected native dependencies and [quickstart](https://github.com/atilla777/oui/blob/main/docs/quickstart.md) for commands. Native consumers do not need this website's Node tooling.

## Experimental compatibility {#compatibility}

All narrow APIs are experimental. The [compatibility map](https://github.com/atilla777/oui/blob/main/docs/compatibility.md) identifies the first environment and bounded combinations; the [scope](https://github.com/atilla777/oui/blob/main/docs/scope.md) lists included and excluded behavior. A listed package or example does not qualify every combination or platform, and historical qualification is not a new pass for your build. In particular, no general IME, bidi/shaping, physical-gamepad, WCAG, other-platform or native/GPU heap guarantee follows from these examples.

## Prerequisites {#prerequisites}

The first checked environment is Linux x86_64 with Odin `dev-2026-10-nightly:84bc3fc`, SDL3 `3.4.16` and SDL3_ttf `3.2.2`. Install or select these separately; they are not supplied by the kit. The native linker and loader must find their shared libraries. If they are outside system paths, set `LIBRARY_PATH` and `LD_LIBRARY_PATH` to your own absolute library directories. Bash and Git are needed for the acquisition commands below; Python 3 is needed for the export helper. No Node is needed for the native example. Other configurations are not established by this guide.

## Source and portable tree {#source-and-portable}

The [published GitHub repository](https://github.com/atilla777/oui) is the maintained source repository, **not** a portable dependency repository. To inspect it and produce a local portable tree, choose an exact full source commit and a new destination:

```sh
set -euo pipefail
SOURCE_COMMIT='<full-maintained-source-commit>'
git clone --no-checkout https://github.com/atilla777/oui.git oui-source
git -C oui-source checkout --detach "$SOURCE_COMMIT"
test "$(git -C oui-source rev-parse HEAD)" = "$SOURCE_COMMIT"
python3 -B oui-source/scripts/export-ui-kit.py ./oui-portable
```

Replace the placeholder before running; `oui-source` and `oui-portable` must not already exist. The exporter copies the allowlisted files and inventory, without Git history. It does not publish a repository. To use the Git acquisition methods below, obtain an owner-published **portable tree** repository and choose its full commit, or create your own Git repository from the exported tree and commit it. No public portable repository URL is promised here. The portable commit is distinct from the maintained source commit; record their relationship yourself. Preserve `LICENSE`, inventory and all relevant resource notices.

## Pin and acquire {#acquire}

In your consumer repository, choose one method. Replace both placeholders with the portable repository URL and its exact full commit; neither `main` nor a tag is a pin. Use a fresh `vendor/odin-ui` destination. These commands require Bash and stop on errors.

### Vendor copy {#vendor}

```sh
set -euo pipefail
UI_REPOSITORY_URL='<portable-repository-url>'
UI_COMMIT='<full-portable-commit>'
test "$UI_REPOSITORY_URL" != '<portable-repository-url>'
test "$UI_COMMIT" != '<full-portable-commit>'
git clone --no-checkout "$UI_REPOSITORY_URL" ui-source
git -C ui-source checkout --detach "$UI_COMMIT"
test "$(git -C ui-source rev-parse HEAD)" = "$UI_COMMIT"
test ! -e vendor/odin-ui
mkdir -p vendor/odin-ui
git -C ui-source archive "$UI_COMMIT" | tar -x -C vendor/odin-ui
printf '%s\n' "$UI_COMMIT" > vendor/odin-ui/SOURCE_COMMIT
```

Use a fresh `ui-source` name; if you already used that name for the maintained clone, choose another. `SOURCE_COMMIT` records the selected commit, not the integrity of later edits. Commit the copied files in your consumer as appropriate.

### Submodule {#submodule}

```sh
set -euo pipefail
UI_REPOSITORY_URL='<portable-repository-url>'
UI_COMMIT='<full-portable-commit>'
test "$UI_REPOSITORY_URL" != '<portable-repository-url>'
test "$UI_COMMIT" != '<full-portable-commit>'
git submodule add "$UI_REPOSITORY_URL" vendor/odin-ui
git -C vendor/odin-ui checkout --detach "$UI_COMMIT"
test "$(git -C vendor/odin-ui rev-parse HEAD)" = "$UI_COMMIT"
git add .gitmodules vendor/odin-ui
git ls-files --stage vendor/odin-ui
```

Check that the staged entry has mode `160000` and the chosen commit, then commit the gitlink and `.gitmodules` in your consumer. On a fresh consumer checkout, `git submodule update --init -- vendor/odin-ui` obtains that recorded commit; do not use `--remote` for a pinned checkout.

## Build and run the menu {#build-and-run}

From the acquired portable root, build the existing standalone example and supply its included font explicitly:

```sh
cd vendor/odin-ui
mkdir -p build
odin build consumer/standalone_menu -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon -show-import-graph -out:build/menu
build/menu --font resources/font.ttf --locale en --size 800x600 --scale 1
# Or, for Russian:
build/menu --font resources/font.ttf --locale ru --size 800x600 --scale 1
```

Run one command at a time on a suitable graphical session. Tab/Shift-Tab and Return/Space or the pointer operate the menu. The example supplies its own strings; applications supply their own strings and fonts. The included font has separate notices under `resources/`; retain them when distributing it. For package closures, other resources, and native dependency details see the authoritative links above. A successful build alone does not establish graphical operation or qualify other platforms.

These interactive commands are for ordinary users. Agents must not use the main display; they need a separately supplied, verified ISD through the project's wrapper, with their own run, explicit focus and cleanup.
