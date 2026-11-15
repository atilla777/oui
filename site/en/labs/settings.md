# Lab settings {#lab-settings}

Lab settings is one of the four Integration Lab screens of the native showcase.
The consumer opens its settings dialog as soon as the section is selected; there
is no separate launch button inside the window. The dialog combines one
single-line name editor with application-owned checkbox and amount values. The
images below are captures of the native application, not a browser
implementation. The [Settings recipe](../recipes/settings) page shows the
restricted fixture and the commands behind it.

![Settings dialog with a focused name editor showing Алексей, Apply and Cancel, applied Алексей, an unchecked Enabled checkbox, Amount 50 and Back to catalogue.](/media/lab-settings-en-initial.png)

Native Lab settings dialog, EN UI; initial state with the default draft and applied values.

The focused `name/field` holds the default draft, the Applied line repeats the
applied name, Enabled is unchecked and Amount is 50.

![Confirmation dialog titled Apply this draft? showing Алексей test, Enabled: true, Amount: 55, Keep editing and Confirm.](/media/lab-settings-en-apply.png)

Native Lab settings dialog, EN UI; Apply opened the confirmation for the edited draft.

After inserting " test", enabling the checkbox and raising Amount to 55, the
confirmation shows the name and the `Enabled: true | Amount: 55` summary that
would be applied.

![Settings dialog after Confirm: the Applied line reads Алексей test, Enabled is checked, Amount is 55 and the confirmation is closed.](/media/lab-settings-en-applied.png)

Native Lab settings dialog, EN UI; Confirm applied the shown draft once.

The Applied line and the controls both show the new values, and the confirmation
is gone.

![Confirmation dialog titled Discard changes? showing Алексей test, Enabled: false, Amount: 55, Stay and Discard changes.](/media/lab-settings-en-discard.png)

Native Lab settings dialog, EN UI; Cancel with pending edits asks before discarding them.

Unchecking Enabled after that left the draft dirty, so Cancel asked and offered
Stay or Discard changes.

## Draft, Apply and Cancel {#states}

The draft and the applied values are separate. The editor owns the name draft,
the Applied line shows the applied name, and Enabled and Amount are draft values
of the consumer; the dialog never displays an applied checkbox or amount. Apply
checks the draft first: a name beyond the editor bound, an empty name or a
missing glyph is refused without a confirmation. The confirmation then repeats
the draft name and the `Enabled: … | Amount: …` summary exactly as they would be
applied, with Keep editing focused first. Keep editing returns to the dialog
without applying anything. Confirm copies that shown revision into the applied
values once; a confirmation that is stale or already consumed applies nothing.

Cancel has one policy for a clean and a dirty draft. When nothing differs from
the applied values it closes the dialog. Otherwise it asks "Discard changes?"
and offers Stay to continue editing or Discard changes to restore the applied
values. Back to catalogue uses the same guard: without pending edits it goes
straight to the catalogue, and with pending edits it asks first. Escape depends
on the open state: it declines the apply confirmation; in the discard question
it chooses Stay, closing the question and returning to the dialog; otherwise it
performs Cancel. Tab and Shift+Tab move focus, Enter or Space activates the
focused target, and the amount responds to Left and Right while focused.

## Editor limits {#editor-limits}

The field is a single line. The consumer accepts 1–64 Unicode 15.1 extended
grapheme clusters when applying and allows an empty draft while typing, but the
status line reports that an empty name cannot be applied. The 64-cluster bound
is this consumer's choice; `ui_editor` itself does not impose it. There is no
IME or preedit support, no undo and no Unicode normalization. Line separators,
C0/C1 control characters and bidi directional controls are rejected, glyph
support is validated separately, and a missing glyph refuses the value.

## Dependencies and ownership {#boundaries}

The screen composes `ui_layers` (the modal and confirmation scopes, including
owner and return-focus rules), `ui_controls` (checkbox and amount with the
`+`/`-` targets and slider capture) and `ui_editor` (the single-line field),
with `ui_base`, `ui_layout`, `ui_interaction` and `ui_text` underneath and
`unicode_graphemes` for the text bound. The showcase adds the SDL and text
adapters, fonts and atlases; the [Settings recipe](../recipes/settings) lists the
narrow compile closure of the restricted fixture. The consumer owns the model:
the draft and applied name, the Enabled and Amount drafts, and the decisions that
confirm or discard them. The kit owns bindings, capture, caret and modal scope
ownership, not the application state or any persistence.

## Source and native example {#source}

Sources at `8bc09cff358aa629410437996520283ff98d77d9`:
[dialog composition](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/lab_menu.odin),
[localized words](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/lab_strings.odin),
[name section](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/sections/name.odin),
[applied settings](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/lab.odin),
[catalogue IDs](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/catalogue.odin),
and [the recipe contract](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md).

From a prepared checkout or export with Odin, SDL3, SDL3_ttf, libpng and zlib:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section lab-settings --locale en --size 1280x960 --scale 1
```

This opens a native window. Agents must use the [isolated display wrapper](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/isd.md), never the main desktop.
