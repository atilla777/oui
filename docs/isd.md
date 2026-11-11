# Optional agent display verification

Ordinary production build/run does not require Python, Pillow, ISD or this wrapper.
Agent graphics use `scripts/ui_isd.py`, never an unisolated desktop fallback.
Select the executable explicitly with `--isd` or `ISD_BIN`; no sibling checkout
discovery. The wrapper checks the complete entry point and every selected
`isdlib/*.py` against inspected source fingerprints **before create**, not merely
the protocol/version/policy marker. It neither installs nor updates ISD.

The inspected existing snapshots are allocation-safe
`d67f4e5cd81f6253a83a0be0810c66e843748fe9`, and native-input
`f8204c61615406ce5628b15692628e146476a008` with layout/keycode. Fingerprints in the
wrapper bind actual bytes, not just Git HEAD. Unknown/modified/partial source is
refused. Native Russian-input verification must select the native-input snapshot;
the wrapper never silently switches to another tool or substitutes keysyms for
physical keycodes. New source versions need their own inspection/acceptance.

Both create and every fresh status preceding launch/graphics/input must report
`display_allocation: linux-abstract-v1`, a live supervisor and a live Xvfb.
The selected implementation disables filesystem X11 transport before spawn,
uses atomic abstract binding, bounded retries and exact readiness validation.
Protocol1 by itself proves none of this. Source changes after create block
graphics/input; status and stop remain available for recovery.

Example from the oui root, with prepared native dependencies:

```sh
python3 -B scripts/ui_isd.py check --isd /chosen/verified/isd \
  --profile ui-showcase --locale ru --section atlas --size 1280x960 \
  --font "$PWD/resources/font.ttf" --fallback-font "$PWD/resources/fallback.ttf" \
  --assets "$PWD/resources/atlas/a/manifest.json" \
  --alternate-assets "$PWD/resources/atlas/b/manifest.json"
```

Profiles are standalone-menu, ui-showcase and opt-in ui-showcase-tools; explicit
consumer/kit roots also support the existing qualification fixtures. Tools require
both `--ui-debug --ui-profile showcase-v19`; test-time/instrumentation retain their
separate gates. No game, bridge, old demo profiles or extra runtime runner.

For ordinary `start`, retain the returned run, use explicit `focus`, address all
input/PNG to that run, and always `stop` in finally (including test failure).
`check` performs its explicit check sequence and stops itself; failed readiness
also attempts stop and records cleanup errors. Stop verifies the stopped phase
and all owned process liveness fields. Never delete incomplete artifacts to make
a run look successful. A palette/readiness smoke is not visual approval: inspect
each required PNG and verify model/effect/failure/no-replay outcomes separately.

Each run retains full selected ISD fingerprints, actual UI source revision/dirty
identity, build flags/source/binary hashes, explicit font/atlas resource hashes,
private child environment, create response, PNG and logs. Metadata comes from
the actual oui kit root, not an invoking consumer's parent Git repository. A
proof without `.git` uses its inventory only after checking copied hashes;
missing/mismatched identity is unavailable/dirty, never guessed from an ancestor.
These local artifacts are not public package contents or full qualification.
