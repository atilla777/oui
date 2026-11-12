# Text input {#text-input}

The native showcase's name editor demonstrates a focused single-line draft,
with Apply and Cancel and a separately displayed applied value. The application
owns the value; the editor manages interaction such as caret and selection.

![Focused name editor with an edited draft, Apply and Cancel buttons, and the unchanged applied value.](/media/text-input-en.png)

Native showcase text input, EN UI; focused draft after inserting a character; applied value unchanged.

## Boundaries and packages {#boundaries}

This is experimental and single-line. Editing uses Unicode 15.1 extended
grapheme clusters (EGCs), not byte or glyph counts. The showcase accepts 1–64
EGCs on apply and permits an empty draft. It does not claim IME, undo or Unicode
normalization support. EGC segmentation is not shaping or bidirectional layout.
`ui_editor` uses `ui_text` and `unicode_graphemes` alongside its other kit
dependencies; the showcase also needs SDL, fonts and atlas resources.

## Source and native example {#source}

Sources pinned to `4da8d7a57bd2453227a4c37df6b0b4d171401681`:
[name fixture](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/sections/name.odin),
[editor](https://github.com/atilla777/oui/tree/4da8d7a57bd2453227a4c37df6b0b4d171401681/kit/ui_editor),
[Unicode tables](https://github.com/atilla777/oui/tree/4da8d7a57bd2453227a4c37df6b0b4d171401681/kit/unicode_graphemes), and
[resource requirements](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md).

In a prepared native checkout with the documented dependencies:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section text-input --locale en --size 1280x960 --scale 1
```

This opens a native window, not a website. Agents must use the
[isolated display wrapper](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/isd.md).
