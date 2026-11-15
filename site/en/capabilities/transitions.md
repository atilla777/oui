# State transitions {#transitions}

The native transition fixture keeps a card inside a laid-out stage. Activating Target B retargets its paint: the offset track targets (120, 24), scale 0.8, opacity 0.6, new foreground, background and border colours, and the progress track advances from 0.25 to 0.75. Target A returns to the base state. Holding Space for 1000 ms on the Hold 1s control increments the card count once after release; an incomplete hold does not.

![Transitions showcase at Target A: a card at its base position with count zero and a short progress bar; Target A is focused.](/media/transitions-en-initial.png)

Native transitions: initial Target A state, EN UI.

![Transitions showcase after Target B: the card is offset and scaled down, faded with its colours retargeted, and the progress bar is longer; Target B is focused.](/media/transitions-en-after-b.png)

Native transitions: after Target B, EN UI.

## Boundaries and packages {#boundaries}

Experimental: paint and hit projections share the frozen laid-out frame, and only their sampled values change; layout itself is not animated. The application owns the target state and the counter. The selected fixture imports `ui_transitions`, `ui_hold`, `ui_controls`, `ui_base`, `ui_layout`, `ui_interaction`, `ui_layers`, `ui_scroll`, `ui_style`, `ui_text`, plus transitive Unicode. The full showcase uses more packages and resources.

## Source and native example {#source}

Pinned to `8bc09cff358aa629410437996520283ff98d77d9`: [showcase fixture](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/sections/transitions.odin), [catalogue](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/catalogue.odin), [recipes](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md), and [resources](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md).

From a prepared native checkout/export with the documented Odin, SDL3, SDL3_ttf, libpng and zlib dependencies:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section transitions --locale en --size 1280x960 --scale 1
```

Press Tab until Target B is focused and Return to apply state B; press Tab to the Hold 1s control and hold Space for at least one second to increment the count.
