# UI Showcase: standalone production proof

For the complete portable distribution use `docs/ui-kit/README.md` in the source
tree, or `docs/README.md` in an exported kit. Source command:
`bash scripts/test-ui-showcase --portable`. It adds the real standalone menu,
six restricted recipe fixtures, documentation, notices/inventory and source skill.
The earlier production-only proof documented below is retained, not a second
maintained implementation. Selected own code/docs/skill now have an explicit MIT
grant; Unicode/fonts/atlas/codecs retain their own notices.

Experimental gallery candidate, Linux x86_64: physical production sources,
selected kit, consumer loader/pure models, explicit fonts/atlas and notices.
This is a build proof, not a distribution license, cross-platform qualification
or independent approval.

The source branch also contains the F4 Integration Lab candidate on top of
`953cd154bb01e3e0a6ab7bf201e34b87a1654458`, pending independent review/integration
and the complete required display/native matrix. It does not expand the frozen
19-ID gallery manifest or claim completed feature acceptance.

Required: Odin `dev-2026-10-nightly:84bc3fc`, SDL3 `3.4.16`, SDL3_ttf `3.2.2`,
libpng `1.6.59`, zlib `1.4` and their shared libraries (F8 candidate,
pending integrated qualification). No checkout symlinks,
game assets, Python, test-main, RIS, debugger or network are needed to build/run.

From `consumer/ui_showcase/`:

```sh
odin build . -collection:ui=../../kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:../../showcase
../../showcase --font ../../resources/font.ttf --fallback-font ../../resources/fallback.ttf \
  --assets ../../resources/atlas/a/manifest.json --alternate-assets ../../resources/atlas/b/manifest.json \
  --section diagnostics-performance --locale ru --size 1280x960 --scale 1
```

`--section` defaults to `catalogue`; the 19 experimental section IDs are layout,
controls, profiles, styling, atlas, text, rich-text, text-input, scroll-table,
collections, layers, hud, gestures, composition, custom, transitions,
accessibility, world, diagnostics-performance. Tab/Shift-Tab navigate;
Return/Space/mouse activate. Editor supports committed single-line text, EGC
selection and Ctrl+A/C/X/V, not IME/undo/bidi/shaping. R retries the accepted model
after failure without replay (physical R also works with the ru keyboard layout).
Values/settings are process-local, not disk state.

The separate catalogue group has four additional selectors: `lab-menu`,
`lab-settings`, `lab-hud`, `lab-inventory`. They run in this same binary, not in
legacy hosts; the original `hud`, `profiles`, `collections`, `gestures` remain
unchanged selectors. For example:

```sh
../../showcase --font ../../resources/font.ttf --section lab-settings \
  --locale en --size 1280x960 --scale 1
```

The catalogue's Lab button opens four recipe buttons in place of the gallery
rows; Gallery returns to the preserved gallery offset. This keeps the original
small viewport matrix without shrinking text or extending the frozen manifest.

Menu/settings compose one runtime: main menu → submenu → settings → Apply
confirmation. Name/Bool/Integer draft is separate from applied; only Confirm
commits it once. Decline keeps editing. Dirty departure, including a shell
departure intention, asks Discard/Stay; background activation never bypasses the
upper modal. `lab-settings` starts directly in settings and returns to submenu.
HUD composes mock HP ±10/progress, popup/tooltip and hold1000ms with one completion
count; early release/loss cancels. Inventory composes two independent scrolling
uniform lists, 12 named stable cards, selection/source and a separate drag handle.
Drag to the other header opens a decision; Cancel moves nothing, Confirm appends
the existing card once. Reverse display order preserves selection identity.

App values survive page switches; pending decisions/capture/popup/tooltip/clock
do not survive runtime destruction. Recovery of the same runtime keeps surviving
decisions and accepted data without replay. Failed owning copies/publication or
render/readback/present block actions; only explicit R retries. Editor cleanup
failure retains its native owner until cleanup retry. There is one physical input
owner and one final publication per active recipe, no new public framework/API.
Lab production sources are ordinary `ui_showcase/*.odin` plus its `model/*.odin`;
the already selected `gestures_demo/model` supplies the pure membership reducer.
No additional runtime/resource dependency is required for Lab itself.

Only the documented combinations are supported: layers+editor+controls,
layers+hold, or two collections+Drag/Drop+layers. No nested scroll, row+drag shared
activation owner, inventory gameplay, arbitrary family powerset, multiline editor
or IME/preedit/bidi/shaping is introduced. ru/en 1280×960 Normal1, applicable
Normal1.5/2 and Pixel_Perfect1/2 plus native resize round trips remain required
display fixtures, separately inspected from software/native-synthetic evidence.
F2 pages retain their original size/mode matrix; the full gallery's readable
baseline is 1280×960 Normal1, ru/en. Tight viewports may clip/refuse, never silently
reduce font/scale. Fractional Pixel_Perfect is refused.

Diagnostics distinguishes expected validator refusals and historical failures.
Performance uses an independent name editor and 10,000 items. Metrics on/off
preserves behavior; CPU phases/callback counters have explicit availability.
CPU submission is not GPU time; tracking is not SDL/TTF/driver heap or VRAM.
Accessibility is an assessment demo, not a conformance claim; C08 editor/gesture
projection samples are assessment-only (interactive flows G09/G14).
Rich+custom+transition is not a rich editor or arbitrary family powerset.

Font notices: `resources/`; atlas/codec notices: `resources/notices/`;
Unicode License v3: `kit/unicode_graphemes/data/LICENSE.txt`.
Atlas CC0 does not relicense fonts, codecs or UI code. Source/resource fingerprints
and compiler import graph accompany the proof root. No Game Bridge or debugger
transport is included. Agent display checks must use the project's isolated ISD
wrapper, never the main display as fallback.
