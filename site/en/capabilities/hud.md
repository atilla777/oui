# HUD hold {#hud}

The native HUD shows HP, plus/minus controls and a hold-to-restore action. Holding for 1000 ms completes once; after release the sample returns to idle with HP 100 and count 1. The application owns HP, the counter and the effect.

![HUD at 60 of 100 HP, idle and count zero, with the hold-to-restore control focused.](/media/hud-idle-en.png)

Native HUD: idle at HP 60, EN UI.

![HUD after a completed hold: HP 100 of 100, idle, count one.](/media/hud-completed-en.png)

Native HUD: after one completed hold and release, EN UI.

## Boundaries and packages {#boundaries}

Experimental: plain Activate does not bypass the hold; an incomplete hold does not restore HP. The selected HUD recipe imports `ui_layers`, `ui_hold`, `ui_hold/sdl`, `ui_base`, `ui_layout`, `ui_interaction`, `ui_style`, `ui_text`, `ui_sdl`, `ui_sdl_text`, plus transitive Unicode. The full showcase uses more packages and resources.

## Source and native example {#source}

Pinned to `4da8d7a57bd2453227a4c37df6b0b4d171401681`: [showcase fixture](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/sections/hud.odin), [catalogue](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/model/catalogue.odin), [selected recipe fixture](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/tests/ui_recipes/hud/main.odin), [recipes](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/recipes.md), and [resources](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md).

From a prepared native checkout/export with the documented Odin, SDL3, SDL3_ttf, libpng and zlib dependencies:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section hud --locale en --size 1280x960 --scale 1
```

Use -10 or +10, then hold Space on the focused restore control for at least one second and release.
