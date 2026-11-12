# Layout {#layout}

Layout arranges geometry for an application's UI. The native showcase demonstrates
row and column placement, overlapping stack items, a grid, anchored absolute
placement and intentional clipping. The surrounding controls and fixture labels
belong to the showcase consumer; they are not a browser implementation of oui.

![Showcase window with row, column, stack, grid, absolute and intentionally clipped examples.](/media/layout-en.png)

Native showcase layout, EN UI; pinned revision, initial state. The clipped label is
intentional. The image records the specific revision below, not every future version.

![Showcase window with row, column, stack, grid, absolute and intentionally clipped examples.](/media/layout-small-en.png)

Native showcase layout, EN UI; 960×720 viewport, initial state.

The viewer selects between the 1280×960 and 960×720 native initial viewport
states; it does not animate or change the native example. Both images above and
their [original 1280×960](/media/layout-en.png) and [960×720](/media/layout-small-en.png)
files remain available without JavaScript. The smaller capture is from revision
`4da8d7a57bd2453227a4c37df6b0b4d171401681`.

<LayoutViewer locale="en" />

## Boundaries and packages {#boundaries}

Layout is experimental. The showcase catalogue explicitly lists **no wrap, span
or auto-placement**. Invalid geometry and allocation refusal are not successful
layout. A layout-only consumer selects `ui_base` and `ui_layout`; it does not need
text, interaction, SDL, fonts or the full showcase. The showcase is a larger
consumer and uses additional packages and resources.

## Source and native example {#source}

These links are pinned to `646dc817cd1b9e3149d6a018ef8bf83f5c87b3bb`:
[showcase fixture](https://github.com/atilla777/oui/blob/646dc817cd1b9e3149d6a018ef8bf83f5c87b3bb/consumer/ui_showcase/app/pages.odin#L160),
[catalogue](https://github.com/atilla777/oui/blob/646dc817cd1b9e3149d6a018ef8bf83f5c87b3bb/consumer/ui_showcase/model/catalogue.odin),
[layout-only fixture](https://github.com/atilla777/oui/blob/646dc817cd1b9e3149d6a018ef8bf83f5c87b3bb/tests/ui_foundation/layout_only/main.odin),
and [resource requirements](https://github.com/atilla777/oui/blob/646dc817cd1b9e3149d6a018ef8bf83f5c87b3bb/docs/resources.md).

From a prepared native checkout/export with the documented Odin, SDL3, SDL3_ttf,
libpng and zlib dependencies, an ordinary user can build and run the showcase:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section layout --locale en --size 1280x960 --scale 1
```

This opens a native window, not a website. Agents must use the
[isolated display wrapper](https://github.com/atilla777/oui/blob/646dc817cd1b9e3149d6a018ef8bf83f5c87b3bb/docs/isd.md), not a main-desktop fallback.
