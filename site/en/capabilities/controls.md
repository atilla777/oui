# Controls {#controls}

The native showcase composes a checkbox, toggle and integer slider. The application
owns their values; controls produce proposals which the application may accept and
feed back into the next description. The checkbox starts unchecked, the toggle off,
and the slider at 50. The capture after Space shows the checkbox checked.

![Native controls with an unchecked checkbox, toggle off and slider at 50.](/media/controls-en-initial.png)

Native controls, EN UI; initial state.

![Native controls with a checked checkbox, toggle off and slider at 50.](/media/controls-en-changed.png)

Native controls, EN UI; checkbox activated with Space.

## Boundaries and packages {#boundaries}

This experimental fixture uses a slider from 0 to 100 with step 1; the model
rejects values outside that range. A proposal is not itself application state.
Select `ui_controls` and its headless dependencies: `ui_base`, `ui_layout`,
`ui_interaction`, `ui_style`, `ui_text`, `ui_layers`, `ui_scroll` and
`unicode_graphemes`. The full showcase also needs SDL, text and resources.

## Source and native example {#source}

At revision `4da8d7a57bd2453227a4c37df6b0b4d171401681`, see the
[fixture](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/app/pages.odin#L271),
[model](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/model/model.odin),
[controls API](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/kit/ui_controls/README.md) and
[resources](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md).
From a prepared native checkout or export with documented Odin, SDL3, SDL3_ttf,
libpng and zlib:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section controls --locale en --size 1280x960 --scale 1
```

This opens a native window, not a browser control. Agents use the [isolated wrapper](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/isd.md).
