# Atlas {#atlas}

The native showcase loads image pages and named regions, then uses them for a panel,
button states, stretch/repeat nine-slices and an image positioned by its pivot.
The A/B control switches between two supplied resource sets. Reload reads the
currently selected set again; it is not a browser implementation of the kit.

![Native Atlas page with blue A resources, pivot 0.5,0.5 and reload counter zero.](/media/atlas-en-initial.png)

Atlas A, initial state; B=false and reload=0.

![Native Atlas page after switching to gold B resources, pivot 1,0 and reload counter zero.](/media/atlas-en-alternate.png)

Atlas B after switching resources; B=true and reload=0.

![Native Atlas page after reloading B; the status reports B=true and reload=1.](/media/atlas-en-reload.png)

Atlas B after reload; B=true and reload=1. Reloading unchanged files need not
change their appearance. All three images are actual native captures at the
revision below, 1280×960, scale 1.

## Boundaries and resources {#boundaries}

The showcase selects `ui_style` for atlas metadata and `ui_sdl` for rendering;
the separate consumer loader reads files using libpng and zlib. These are not a
PNG parser in UI core. The example sets A and B contain distinct manifests and
images; their SHA-256 identities and the fonts are recorded in the
[resource documentation](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md).

The consumer accepts UTF-8 JSON manifest version 1, at most 1 MiB, 16 pages and
4096 regions, with unique IDs and valid page references. Its PNG envelope accepts
non-interlaced 8-bit RGB or RGBA, at most 4096×4096 and 16 MiB encoded; CRC and
framing are checked, and APNG is rejected. These are loader limits, not a claim
that arbitrary PNGs or manifests work. Failure does not constitute a successful
resource replacement.

## Source and native example {#source}

Pinned to `4da8d7a57bd2453227a4c37df6b0b4d171401681`:
[showcase](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/sections/content.odin),
[loader](https://github.com/atilla777/oui/tree/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/atlas_catalog/loader),
[resource pins and dependencies](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md).
From a prepared native checkout/export with documented Odin, SDL3, SDL3_ttf,
libpng and zlib:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section atlas --locale en --size 1280x960 --scale 1
```

This opens a native window. Agents use the [isolated display wrapper](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/isd.md), not the main desktop.
