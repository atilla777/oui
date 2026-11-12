# Layers {#layers}

Layers partition interaction into explicit modal and popup scopes. The native fixture opens A and a nested B, toggles a popup and a noninteractive tooltip; cancellation follows the selected policy. Counters and effects belong to the application, not to the layer mechanism.

![Layers showcase with an open popup and a noninteractive tooltip above the underlying controls.](/media/layers-popup-tooltip-en.png)

Native layers: popup and noninteractive tooltip, EN UI.

![Modal A with focused counter, scroll rows and controls to open B, close, show a popup or tooltip.](/media/layers-modal-en.png)

Native layers: modal A open, EN UI.

## Boundaries and packages {#boundaries}

This is experimental: scope ownership and focus are explicit, and tooltips do not accept input. The selected mechanism uses `ui_base`, `ui_interaction` and `ui_layers`; actual consumers also choose their geometry, rendering and other needed families. The full showcase is a larger consumer.

## Source and native example {#source}

Pinned to `4da8d7a57bd2453227a4c37df6b0b4d171401681`: [showcase fixture](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/sections/layers.odin), [catalogue](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/model/catalogue.odin), [selected recipe fixture](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/tests/ui_recipes/settings/main.odin), [recipes](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/recipes.md), and [resources](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md).

From a prepared native checkout/export with the documented Odin, SDL3, SDL3_ttf, libpng and zlib dependencies:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section layers --locale en --size 1280x960 --scale 1
```

Open A, then Open B or Close. Toggle Popup and Tooltip on the base scope; Escape closes the popup when open.
