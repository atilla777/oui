# Accessibility assessment {#accessibility}

The native accessibility section assesses published frames for contrast, minimum
target size and reduced motion, and reports Pass, Warning, Unassessed or Not
Applicable per record. The assessment is advisory: a warning never disables an
ordinary action, and the application owns every effect. The Confirm action uses
the selected confirmation mode — a 1000 ms hold in Hold mode, or a modal
`Confirm?` dialog with Confirm and Cancel in Dialog mode. The dialog opens only
while a request is pending.

![Accessibility showcase: Good, Bad and Unassessed assessment samples, a 24x24 target and a clipped 40x40 target, the C08 assessment-only panel, the reduced-motion sample and a status line with zero counter and requests.](/media/accessibility-initial-en.png)

Native accessibility: initial assessment samples and idle status, EN UI.

![Accessibility showcase in Dialog mode: the confirmation dialog with Confirm and Cancel is open over the samples, and the status line still reports zero counter and requests while confirmation is pending.](/media/accessibility-dialog-en.png)

Native accessibility: Dialog mode with the pending confirmation dialog open, EN UI.

The settings row exposes Hold / Dialog, the default `4.5:1,24` and strict
`7:1,32` thresholds, Normal / Strict reporting, a reduced-motion sample, and the
Confirm action. A / B and Show / Hide switch explicit target and presence
samples. Three fixed samples stay visible: a black-on-white pass sample, a
warning sample whose white-on-white text is deliberately invisible, and an
unassessed sample over a custom circle backdrop. The line below them states that
warnings do not disable ordinary actions.

The C08 panel is an assessment-only projection: it contributes a rich block, a
disabled editor holding `Имя`, four scroll rows and a disabled gesture target to
the captured frame. Editing is demonstrated by text input (G09) and gestures by
G14, not here. The target rows assess a 24x24 button and a 40x40 button clipped
to a visible 20x40. The status line reports the selected policy, the
Pass/Warning/Unassessed counts, the application counter and the number of
confirmed requests; coverage remains incomplete in this fixture.

## Boundaries and packages {#boundaries}

Experimental and advisory. The kit provides no screen-reader output, platform
accessibility API bridge, WCAG certification or full conformance statement.
Warning and Unassessed are not conformance, the reported coverage can stay
incomplete, and a failing assessment does not block ordinary actions. The
selected assessment consumer imports `ui_accessibility/inspect` and
`ui_accessibility/projection` and assesses frames produced by `ui_base`,
`ui_layout`, `ui_interaction`, `ui_style` and `ui_text`; the projection also
references `ui_custom`, `ui_editor`, `ui_gestures`, `ui_hold`, `ui_layers`,
`ui_rich`, `ui_scroll`, `ui_transitions` and `ui_wire` transitively. The full
showcase uses more packages and resources.

## Source and native example {#source}

Pinned to `8bc09cff358aa629410437996520283ff98d77d9`: [showcase fixture](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/sections/accessibility.odin), [catalogue](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/catalogue.odin), [page runtime](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/accessibility_runtime.odin), [accessibility kit](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/kit/ui_accessibility), and [resources](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md).

From a prepared native checkout/export with the documented Odin, SDL3, SDL3_ttf, libpng and zlib dependencies:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section accessibility --locale en --size 1280x960 --scale 1
```

Initial focus is Confirm action. In Hold mode, hold Space for 1000 ms on it. To
try Dialog mode, press Shift+Tab four times to Hold / Dialog, press Return, then
Tab four times back to Confirm action and press Return: the pending `Confirm?`
dialog opens with Cancel focused. Use Tab or the arrow keys to choose Confirm or
Cancel; Return applies or cancels the pending request exactly once.