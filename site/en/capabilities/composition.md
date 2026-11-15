# Nested composition {#composition}

Panels compose from owned slots with a fixed title, content and footer order. The native fixture nests a child button inside a composite parent button; activating the child records an intention on the parent route unless Stop is on, and the counts line shows what each activation recorded. Presence, counters and the effect belong to the application.

![Showcase page with a composite parent button containing a nested child button, counts parent zero and child zero, Stop on.](/media/composition-en-initial.png)

Native showcase composition, EN UI; initial state with stop on.

![Same page with Stop off after one child activation; counts parent one and child one.](/media/composition-en-propagated.png)

Native showcase composition, EN UI; child activation propagated to the parent.

## Boundaries and packages {#boundaries}

This is experimental. Callbacks record intentions, with no reentry, and the panel tree is a pre-layout description: it has no own publication stamp, dispatch, clock or focus owner, and the application binds text and interactive descriptions to node IDs itself. The selected packages are `ui_composition`, `ui_base`, `ui_layout`, `ui_interaction` and `ui_style`; the full showcase uses more packages and resources.

## Source and native example {#source}

Pinned to `8bc09cff358aa629410437996520283ff98d77d9`: [showcase fixture](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/sections/composition.odin), [catalogue](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/catalogue.odin), [package README](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/kit/ui_composition/README.md), [recipes](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md) and [resources](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md).

From a prepared native checkout/export with the documented Odin, SDL3, SDL3_ttf, libpng and zlib dependencies:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section composition --locale en --size 1280x960 --scale 1
```

Activate the child with Return, then toggle Stop and activate again to see the intention recorded on the parent route; Remove child and Re-add child change the nested structure.
