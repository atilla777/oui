# Styling {#styling}

The native showcase presents existing shapes, an image and a role panel with a
theme token and visual states. Theme switches the accent from blue to purple;
Selected and Disabled change fixture state, and Disabled also disables Count.
Missing image exercises the fallback. These are showcase actions, not a theme editor.

![Native styling palette with blue accent and state controls.](/media/styling-en-initial.png)

Native styling, EN UI; initial blue theme.

![Native styling palette with purple accent after activating Theme.](/media/styling-en-changed.png)

Native styling, EN UI; Theme activated.

## Boundaries and packages {#boundaries}

The sample combines role declarations, named style and local overrides. The
accent token supplies the normal role background; the named style supplies border
and focus properties; local declarations include radius and, for the first shape,
a background. Selected, hovered, pressed, focused and disabled have role state
colors. Only existing primitives and theme cascade are demonstrated; this is
experimental. Select `ui_style` with `ui_base` and `ui_layout`; interactive text
and rendering in the showcase use additional packages and native dependencies.

The resolver starts with defaults, then applies role, named style and local
declarations in that order; later declarations override earlier ones per property.
Within each level it applies Normal, Selected, Hovered, Pressed, Focused, then
Disabled when active. Disabled suppresses Hovered and Pressed. A missing named
style or token is marked as fallback rather than providing a new value.

## Source and native example {#source}

At revision `4da8d7a57bd2453227a4c37df6b0b4d171401681`, see the
[fixture](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/sections/content.odin#L319),
[model](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/model/model.odin),
[style source](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/kit/ui_style/style.odin) and
[resources](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md).
From a prepared native checkout or export with documented Odin, SDL3, SDL3_ttf,
libpng and zlib:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section styling --locale en --size 1280x960 --scale 1
```

This opens a native window. Agents use the [isolated wrapper](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/isd.md).
