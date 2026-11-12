# Text {#text}

The native showcase renders a localized paragraph with explicit line breaks,
an empty line, combining marks and non-breaking spaces. It also shows wrapping,
clipping, ellipsis and alignment. The key button switches to a shorter localized
string; the limit fixture changes the consumer's grapheme-count example.

![Native showcase text page with an English paragraph, clipping and ellipsis examples.](/media/text-en-initial.png)

English text fixture, initial state at the pinned revision.

![Native showcase text page with the shorter English paragraph selected.](/media/text-en-alternate.png)

The same fixture after selecting the short text key.

## Boundaries and packages {#boundaries}

Text is experimental and bounded to 65,536 bytes and 4,096 lines. It does not
provide shaping or bidirectional layout. The showcase's limit report counts
Unicode 15.1 extended grapheme clusters; it is a consumer example, not a text
editor. The fixture uses `translations`, `ui_text`, `ui_layout`, `ui_base` and
`unicode_graphemes`, together with the showcase's SDL rendering and fonts.
Select only the packages and resources needed by your own consumer.

## Source and native example {#source}

The [localized fixture](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/sections/content.odin),
[catalogue](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/model/catalogue.odin),
and [resource requirements](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md) are pinned to the capture source revision.
From a prepared native checkout/export with Odin, SDL3, SDL3_ttf, libpng and zlib:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section text --locale en --size 1280x960 --scale 1
```

This opens a native window. Agents use the [isolated display wrapper](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/isd.md), not a desktop fallback.
