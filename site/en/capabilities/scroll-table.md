# Scroll and table {#scroll-table}

Ordinary vertical scrolling moves a table through a viewport. The showcase has three fixed tracks for item, kind and quantity; after wheel input the capture shows rows 24–32.

![Native table scrolled to items 24 through 32, with item, kind and quantity columns.](/media/scroll-table-en.png)

Native showcase scroll-table, EN UI; table scrolled to the end.

## Boundaries and packages {#boundaries}

This is experimental, vertical and non-nested; the example uses three fixed tracks. It is ordinary scrolling, not collection virtualization. Select `ui_scroll` with `ui_base`, `ui_layout` and `ui_interaction` as needed.

## Source and native example {#source}

[Showcase source](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/app/pages.odin) · [Native catalogue](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/model/catalogue.odin) · [API](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/api.md) · [Resources](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md) · [ISD](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/isd.md).

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section scroll-table --locale en --size 1280x960 --scale 1
```

This opens a native window, not a website. Agents must use the isolated display wrapper, not a main-desktop fallback.
