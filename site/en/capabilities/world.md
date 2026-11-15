# World anchors {#world}

World anchors place ordinary cards at world-space points. The application owns the camera and supplies the projection callback; the kit returns bounds, visibility, clamping and a normalized direction for each anchor. The showcase has three anchors: A follows the object buttons, while B is fixed at world (800, 0) and C at (-800, -500). Each camera button shifts the view by 64 world units, Zoom toggles between 1 and 2, and Reset restores the initial model. Cards show their label and a progress track; the title line reports a per-anchor reason such as Placed or Offscreen.

![Showcase world page with the A card at the centre, A/B/C reasons and Hide policy.](/media/world-initial-en.png)

Native world anchors, EN UI; initial state with A placed and B/C offscreen under Hide.

![Showcase world page after three Camera +X steps: A shifted left and two edge indicators for B and C under Direction policy.](/media/world-indicators-en.png)

Native world anchors, EN UI; after three Camera +X steps and Direction policy.

## Boundaries and packages {#boundaries}

Experimental: the helper stores no anchors, camera or callback and allocates no memory; the application owns the model, the camera snapshot and the projection. The world page selects `ui_base`, `ui_layout`, `ui_interaction`, `ui_style` and `ui_world`; the full showcase uses more packages and resources. Hide omits off-screen anchors, Clamp keeps the whole card inside the viewport, and Direction replaces an off-screen card with an edge indicator. There is no engine, no scene graph and no Game Bridge; the application composes an ordinary clipped viewport.

## Source and native example {#source}

Pinned to `8bc09cff358aa629410437996520283ff98d77d9`: [showcase world section](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/sections/world.odin), [native catalogue](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/catalogue.odin), [world helper](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/kit/ui_world/anchors.odin), [API](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/api.md), [resources](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md) and [ISD](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/isd.md).

From a prepared native checkout/export with the documented Odin, SDL3, SDL3_ttf, libpng and zlib dependencies:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section world --locale en --size 1280x960 --scale 1
```

This opens a native window, not a website. Agents must use the isolated display wrapper, not a main-desktop fallback. Use Tab to move focus and Space or Return to activate the object, camera, Zoom, policy and Reset controls.