# Virtual collections {#collections}

Virtual collections materialize a visible range of a uniform list or grid instead of building every item as a visible node. The showcase contains 10,000 items; the Middle action reveals materialized rows around item 05000.

![Native virtual list at the middle of 10000 items, showing items 04995 through 05000.](/media/collections-en.png)

Native showcase collections, EN UI; list materialized at the middle.

## Boundaries and packages {#boundaries}

This is experimental and requires uniform geometry. Each region has exactly one offset owner: do not attach an ordinary scroll state to the same virtual region. Select `ui_collections` with its base, layout and interaction dependencies; the showcase also uses additional packages and resources.

## Source and native example {#source}

[Showcase source](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/app/collection_runtime.odin) · [Native catalogue](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/model/catalogue.odin) · [API](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/api.md) · [Resources](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md) · [ISD](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/isd.md).

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section collections --locale en --size 1280x960 --scale 1
```

This opens a native window, not a website. Agents must use the isolated display wrapper, not a main-desktop fallback.
