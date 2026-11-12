# Profiles {#profiles}

The native showcase combines controls into a profile-settings example. Select one
of three fixtures, edit the draft and compare its status with the applied values.
The controls and state belong to the native consumer, not a browser implementation.

![Profiles controls and applied Aurora settings.](/media/profiles-en-initial.png)

Initial Aurora profile, EN UI. The status reads Applied.

![Confirmation dialog offering apply, discard or stay over an edited Aurora profile.](/media/profiles-en-dialog.png)

After changing Show help and selecting Borealis, the native confirmation offers
Apply and go, Discard and go, or Stay; the draft is not yet applied.

![Aurora profile with Show help unchecked and status Applied.](/media/profiles-en-applied.png)

In a separate run, Show help was unchecked and Apply clicked. Aurora remains
selected, the checkbox stays unchecked, and the status now reads Applied.

## Workflow {#workflow}

Change Show help, Enabled, Intensity (0–100) or the Mode on the Appearance tab.
Apply copies the draft into the selected profile's applied values; Cancel restores
the draft from those values. Switching profiles with unapplied edits asks whether
to apply, discard or stay. Reset asks for confirmation and restores the draft to
the selected fixture's defaults; apply it separately to change applied values.

## Boundaries and packages {#boundaries}

This is an experimental example with three fixed fixtures. Applied values live
only in memory: there is no disk persistence. The disabled control is intentional.
The composition uses `ui_controls`, with layout and interaction support from
`ui_layout` and `ui_interaction`; the complete showcase uses additional packages,
SDL and resources. The profile state and decisions are consumer-owned.

## Source and native example {#source}

Sources at `4da8d7a57bd2453227a4c37df6b0b4d171401681`:
[controls composition](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/sections/profiles.odin),
[profile model](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/controls_demo/model/model.odin),
[showcase](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/README.md),
and [resources](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md).

From a prepared checkout or export with Odin, SDL3, SDL3_ttf, libpng and zlib:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section profiles --locale en --size 1280x960 --scale 1
```

This opens a native window. Agents must use the [isolated display wrapper](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/isd.md), never the main desktop.
