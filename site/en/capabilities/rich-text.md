# Rich text {#rich-text}

The native showcase renders a localized card with nested emphasis and color,
size, italic and underline, an inline image and a fallback-font specimen. The
following element stays after the paragraph. A control switches the card to one
line with ellipsis; another example already shows one-line ellipsis.

![Native showcase rich text card in English with styled text and inline image.](/media/rich-text-en-initial.png)

English rich card, initial state at the pinned revision.

![Native showcase English rich card after selecting one-line ellipsis.](/media/rich-text-en-alternate.png)

The same card after selecting the one-line limit.

## Boundaries and packages {#boundaries}

Rich text is experimental. Its bounded grammar includes the fixture's `[b]`,
`[i]`, `[u]`, `[color]`, `[size]` and `[img]` forms; it is not HTML or an editable
rich-text editor. It inherits text's limits of 65,536 bytes and 4,096 lines and
does not promise shaping or bidi. The fixture uses `ui_rich`, `ui_text`,
`ui_style`, `ui_layout`, `ui_base` and `unicode_graphemes`, with the SDL adapter,
primary and fallback fonts and atlas resources for the showcase. Resource
coverage is font-dependent; a bundled fallback does not cover every character.

## Source and native example {#source}

The [localized fixture](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/sections/content.odin),
[rich package](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/kit/ui_rich/README.md)
and [resource requirements](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md) are pinned to the capture source revision.
From a prepared native checkout/export with Odin, SDL3, SDL3_ttf, libpng and zlib:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section rich-text --locale en --size 1280x960 --scale 1
```

This opens a native window. Agents use the [isolated display wrapper](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/isd.md), not a desktop fallback.
