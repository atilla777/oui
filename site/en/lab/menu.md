# Lab menu {#lab-menu}

The Integration Lab's `lab-menu` screen is a mock settings flow built from the existing menu, layers, controls and editor families. Its main page offers `Open submenu`; the submenu offers `Settings` and `Main menu`; Settings opens a modal with a single-line name draft, Apply and Cancel, an `Enabled` checkbox, an `Amount` slider and `Back to catalogue`. Apply raises a confirmation for the shown draft; Confirm applies it once and Keep editing returns to the draft.

The settings are teaching data. The catalogue entry for `lab-menu` is described as **Mock settings; process-local**, and the Russian section limitation is «Учебные данные; состояние только до завершения процесса». The settings values are not read from or written to disk, and they end with the process. The name field reuses the single-line editor: 1–64 extended grapheme clusters on apply, no IME, undo or normalization.

![Lab menu initial screen with the Open submenu button focused.](/media/lab-menu-initial-en.png)

Native Lab menu, EN UI; initial screen with Open submenu focused.

![Lab menu submenu with Settings focused and Main menu below.](/media/lab-menu-submenu-en.png)

Native Lab menu, EN UI; submenu with Settings and Main menu.

![Lab menu settings modal with a name draft, Apply and Cancel, Enabled checkbox, Amount slider and Back to catalogue.](/media/lab-menu-settings-en.png)

Native Lab menu, EN UI; settings modal with the name draft focused.

![Lab menu apply confirmation showing the draft name, Enabled false, Amount 50, Keep editing and Confirm.](/media/lab-menu-confirm-en.png)

Native Lab menu, EN UI; apply confirmation for the unchanged draft.

## Boundaries and packages {#boundaries}

This is experimental. The screen demonstrates a modal layer, checkbox and slider controls and an editor in one composition; it is not a general settings system, a persistence layer or a form framework. Draft and applied values are separate, and only the confirmation applies the shown draft. Departing with changes raises the existing Stay/Discard choice. Invalid or stale pending values are not applied; recovery does not replay Apply.

`consumer/ui_showcase/app/lab_menu.odin` imports the UI families `ui_base`, `ui_interaction`, `ui_layers`, `ui_controls`, `ui_editor` and `ui_sdl_text`, plus the showcase's own `model` and `sections` packages. The shared `sections` composition also selects layout, style and text, and the running showcase is a **wider union**: it includes every gallery and Lab screen, the SDL backend and the consumer atlas loader with libpng and zlib. That union is not the dependency set of this screen alone. For the narrow executable menu without layers, controls, editor or atlases, see the [Basic menu recipe](../recipes/menu).

## Source and native example {#source}

Pinned to `8bc09cff358aa629410437996520283ff98d77d9`:
[lab-menu screen](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/lab_menu.odin),
[Lab strings](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/lab_strings.odin),
[name editor](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/sections/name.odin),
[model](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/model.odin),
[catalogue IDs and limits](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/catalogue.odin),
[recipe boundary](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md#4-settings), and
[resources](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md).

The showcase links the consumer atlas loader and therefore needs libpng and zlib in addition to Odin, SDL3 and SDL3_ttf. The current resource pins are libpng 1.6.59 and zlib 1.4. Prepare that pair in a private prefix and point both `pkg-config` and the runtime loader at the same libraries; do not mix system headers or libraries with it. The [resource documentation](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md) records the archives, digests and notices.

From a prepared native checkout or export with those dependencies:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section lab-menu --locale en --size 1280x960 --scale 1
# Russian UI:
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section lab-menu --locale ru --size 1280x960 --scale 1
```

Return opens the focused element. From the initial screen, Return on `Open submenu` opens the submenu; Return on `Settings` opens the settings modal. Tab reaches Apply; Return raises the confirmation, where Tab moves to Confirm and Return applies it once, or Return on Keep editing returns to the draft.

This opens a native window, not a website. Agents must use the [isolated display wrapper](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/isd.md), not the main desktop.