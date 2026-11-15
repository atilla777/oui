# Gestures {#gestures}

The native gestures fixture shows two card panels with repeat-scroll buttons, clipped 48-pixel rows, a pan handle and a drop-target title on each panel. A mouse press on a card starts a drag; while the button is down the fixture reports a proposal and marks the hovered panel title "Drop: accepted". The card still remains in its source panel. The application applies one move only after release, and there is no inertia or automatic repeat of the move.

![Two panels with six cards each, repeat buttons, pan handles and the focused name draft.](/media/gestures-en-initial.png)

Native gestures: both panels at six cards, EN UI.

![A card held over the right panel title, which reads Drop: accepted, while the card stays in the left panel.](/media/gestures-en-proposal.png)

Native gestures: proposal with the mouse button still down, EN UI.

![After release the left panel begins with card-02 and the right panel holds the moved card.](/media/gestures-en-applied.png)

Native gestures: the application applied the move after release, EN UI.

## Boundaries and packages {#boundaries}

Experimental: the proposal is not an application move, and release applies at most one membership change. Same-panel, stale, replayed or unavailable requests are refused without moving a card; no momentum or inertia follows the pointer. The gesture path imports `ui_gestures` and `ui_gestures/sdl` with `ui_base`, `ui_layout`, `ui_interaction`, `ui_scroll` and `ui_sdl`; the showcase adds its own rendering and text families. The full showcase is a larger consumer.

## Source and native example {#source}

Pinned to `8bc09cff358aa629410437996520283ff98d77d9`: [showcase fixture](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/sections/gestures.odin), [gesture runtime](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/gesture_runtime.odin), [model reducer](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/gestures_demo/model/model.odin), [catalogue](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/catalogue.odin), [recipes](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md), and [resources](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md).

From a prepared native checkout/export with the documented Odin, SDL3, SDL3_ttf, libpng and zlib dependencies:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section gestures --locale en --size 1280x960 --scale 1
```

Press on a card, move over the other panel title until it reads "Drop: accepted", then release. Use -24 or +24, or drag a pan handle, to scroll the clipped rows.