# Custom primitives {#custom}

Two namespaced recipes build side-by-side panels with application-owned circle nodes. A custom description carries immutable payload bytes and trusted pure validate, measure and hit callbacks; the circle activates only inside its round area, and the panel footer counts the recorded activations. Style and Footer toggle the left recipe's styling and its footer slot, and popup and tooltip overlays layer above the panels.

![Showcase page with Style, Footer, Disabled, Popup shield and Tooltip actions above two panels, each with a circle and footer count zero.](/media/custom-en-initial.png)

Native showcase custom primitives, EN UI; initial state.

![Same page with the left panel footer count changed to one by a single circle activation.](/media/custom-en-activated.png)

Native showcase custom primitives, EN UI; left circle activated once.

![Same page with the left panel restyled and its footer note removed; the right panel is unchanged.](/media/custom-en-styled.png)

Native showcase custom primitives, EN UI; style applied and footer slot removed.

![Same page with a popup overlay containing a Close popup button and a reserved-position tooltip label.](/media/custom-en-popup-tooltip.png)

Native showcase custom primitives, EN UI; popup shield and tooltip shown.

## Boundaries and packages {#boundaries}

This is experimental. The hit predicate is pure and allocates no memory; a semantic activation does not call it. Callbacks are trusted process-lifetime functions, not a sandbox or plugin ABI, and rendering lives in a separate SDL adapter. The selected packages are `ui_custom`, `ui_composition`, `ui_base`, `ui_layout`, `ui_interaction` and `ui_style`; the full showcase uses more packages and resources.

## Source and native example {#source}

Pinned to `8bc09cff358aa629410437996520283ff98d77d9`: [showcase fixture](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/sections/custom.odin), [circle runtime](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/custom_runtime.odin), [catalogue](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/catalogue.odin), [package README](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/kit/ui_custom/README.md), [recipes](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md) and [resources](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md).

From a prepared native checkout/export with the documented Odin, SDL3, SDL3_ttf, libpng and zlib dependencies:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section custom --locale en --size 1280x960 --scale 1
```

Activate the focused left circle with Return, then Style, Footer, Popup shield and Tooltip to change the recipes and overlays; clicks outside the round circle area do not activate it.
