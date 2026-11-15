# Diagnostics and performance {#diagnostics-performance}

The native G20–G21 page combines an explicit editor and collection fixture with
consumer-side instrumentation. It shows CPU phase samples for prepare, copy,
commit, draw, readback and present (p/c/k/d/r/p), text metric callbacks and
operation counters. Metrics on/off hides every phase and counter. Five probes —
Duplicate, Invalid, Resource, Ownership and Unsupported — produce their own
family, stage, code and id observations instead of changing the ordinary page
state.

The status line starts with CPU phase samples after the first complete frame.
The single-line editor keeps one focused line, and the collection list above it
stays editable.

![Native G20-G21 page with five diagnostic probes, a metrics toggle, CPU phase counters and the editor and collection panels.](/media/diagnostics-performance-en-initial.png)

Native diagnostics and performance page, EN UI; CPU phase samples after the first complete frame.

![Native G20-G21 page after the Duplicate probe: the status line reports an expected Layout Prepare observation with code 2 and id fixture.](/media/diagnostics-performance-en-diagnostic.png)

Native diagnostics and performance page, EN UI; Duplicate probe observation.

## Boundaries and packages {#boundaries}

Experimental and explicitly opt-in consumer-side tooling: the page observes its
own CPU submission samples. There is no debugger transport, no GPU timing, no
SDL heap accounting and no numerical SLA. A diagnostic observation describes
one expected failing probe, and ordinary actions require the current bundle.
The page path uses `ui_base`, `ui_layout`, `ui_interaction`, `ui_text`,
`ui_editor`, `ui_editor/sdl`, `ui_collections`, `ui_sdl_text` and `ui_sdl`, plus
the shared `ui_style` shell paint and transitive Unicode. The full showcase
links more packages and resources.

## Source and native example {#source}

Pinned to `4da8d7a57bd2453227a4c37df6b0b4d171401681`: [showcase page](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/sections/performance.odin), [probe runtime](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/app/diagnostic_runtime.odin), [catalogue](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/model/catalogue.odin), and [resources](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md).

From a prepared native checkout/export with the documented Odin, SDL3, SDL3_ttf, libpng and zlib dependencies:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section diagnostics-performance --locale en --size 1280x960 --scale 1
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section diagnostics-performance --locale ru --size 1280x960 --scale 1
```

Tab moves focus to Duplicate and Return runs that probe; the same section and
resources serve both locales. This opens a native window, not a browser control.
Agents use the [isolated wrapper](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/isd.md).