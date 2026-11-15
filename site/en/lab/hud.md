# Lab HUD {#lab-hud}

The Integration Lab HUD is the teaching screen for a hold-to-restore HUD. Mock HP starts at 60 of 100; −10 and +10 clamp it; the restore control needs a 1000 ms hold of Space; Popup opens a panel with a Close button, and Explain shows a noninteractive tooltip. The native metadata is `Mock HP; hold 1000 ms` with the Lab limitation «Учебные данные; состояние только до завершения процесса»: teaching data whose state lasts only until the process ends.

![Lab HUD at mock HP 60, idle and count zero, with the hold-to-restore control focused.](/media/lab-hud-initial-en.png)

Native Lab HUD, EN UI; mock HP 60, idle and count zero.

![Lab HUD with the popup open over the hold controls.](/media/lab-hud-popup-en.png)

Native Lab HUD, EN UI; popup open over the hold controls.

![Lab HUD during a hold with a partially filled progress bar.](/media/lab-hud-hold-en.png)

Native Lab HUD, EN UI; hold in progress at 683 ms.

![Lab HUD after one completed hold: mock HP 100 and count one.](/media/lab-hud-completed-en.png)

Native Lab HUD, EN UI; after one completed hold and release, HP 100 and count one.

## Mock HP, hold and failure distinctions {#distinctions}

- Threshold: a 999 ms hold followed by release has no effect; a full 1000 ms hold followed by release restores HP to 100 and increments the count once.
- Activate: a plain Activate on the restore control cannot bypass the hold.
- Cancel: an open popup shields the hold, so close it before holding; focus loss cancels an in-progress hold.
- No replay: recovery rebuilds the accepted model and does not repeat a completed restore.
- Completion: a completed hold applies once, and the control returns to idle.

The [contract test](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/lab_contract_test.odin) covers these outcomes in the native composition.

## Boundaries and packages {#boundaries}

`app/lab_hud.odin` imports `ui_base` and `ui_interaction` and composes `sections/hud.odin`, which selects `ui_hold` and, through the shared page helpers, layout, style, text and further showcase families; the Lab page adds `ui_layers` for the popup and tooltip. The running showcase is a wider union: its binary also contains the atlas loader and therefore links libpng and zlib, although this screen has no atlas content. HP, the hold count and the effect stay in the application model; the kit only reports progress and one completion.

## Source and native example {#source}

Pinned to `8bc09cff358aa629410437996520283ff98d77d9`: [Lab HUD composition](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/lab_hud.odin), [HUD section](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/sections/hud.odin), [catalogue metadata](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/catalogue.odin), [contract test](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/lab_contract_test.odin) and [the ISD document](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/isd.md).

From a prepared native checkout/export with the documented Odin, SDL3, SDL3_ttf, libpng and zlib dependencies:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section lab-hud --locale en --size 1280x960 --scale 1
# Or, for Russian:
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section lab-hud --locale ru --size 1280x960 --scale 1
```

Tab moves focus, Return activates the focused button, and Space held for about one second on the restore control performs the hold; release before 1000 ms has no effect. The program opens a native window. Ordinary users run it in their own graphical session; agents must use the isolated display wrapper with a selected verified ISD copy, as described in [the ISD document](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/isd.md).

See [HUD recipe](../recipes/hud) for the narrow dependency closure and [HUD hold](../capabilities/hud) for the gallery boundary.