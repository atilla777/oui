# Showcase tools — showcase-v19

Portable entry and checked command layout:
[Odin UI kit](../../README.md). The standalone skill now names this
entrypoint/profile rather than historical umbrella hosts. MIT applies only to
selected own source/docs/skill, not external dependencies. Source distribution
check: `bash scripts/test-ui-showcase --portable`; ordinary/minimal import graphs
are checked separately from this opt-in transport.

Implementation candidate for `slyx-iv1.5`, pending integration and independent
review. This entrypoint shares `../ui_showcase/app` with ordinary showcase; it
does not replace `ui-demo-cli.py` or extend legacy wire 10–18.

## Build and launch

From the project root, with the pinned Odin/SDL3/SDL3_ttf/libpng/zlib environment:

```sh
odin build consumer/ui_showcase_tools -collection:ui=kit \
  -define:UI_SHOWCASE_TOOLS=true -define:UI_DEMO_TEST=true \
  -extra-linker-flags:"$(pkg-config --libs libpng zlib)" \
  -out:/tmp/opencode/ui-showcase-tools
python3 scripts/ui_isd.py start --isd /path/to/verified/isd \
  --profile ui-showcase-tools --ui-debug --ui-profile showcase-v19 --test-time \
  --font "$PWD/resources/font.ttf" \
  --fallback-font "$PWD/resources/fallback.ttf" \
  --assets "$PWD/resources/atlas/a/manifest.json" \
  --alternate-assets "$PWD/resources/atlas/b/manifest.json" \
  --section controls --locale ru --size 960x720
```

Verify the selected complete ISD copy according to [ISD policy](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/docs/isd.md)
before `start`. Address input and screenshots to the returned `run`, explicitly
`focus` before native input, and always `stop RUN` in `finally`, including after
failures. Never fall back to the main display. The wrapper builds a fresh binary.
Its returned `ui_socket` comes only from this run's single JSON endpoint record.

`UI_SHOWCASE_TOOLS=true` selects fields/composition, not permission. The endpoint
requires both runtime flags and either a debug build or `UI_DEMO_TEST=true`.
Release without that test gate refuses opt-in. Off mode runs the ordinary loop,
without a server or retained debug capture. `--test-time` additionally requires
the compile test gate and runtime opt-in; RPC cannot enable it. Ordinary showcase
rejects these options and has no debug transport import.

## Client and wire

```sh
python3 scripts/ui-showcase-cli.py --socket /exact/own/run/ui.sock \
  --profile showcase-v19 list-sections
python3 scripts/ui-showcase-cli.py --socket /exact/own/run/ui.sock \
  --profile showcase-v19 find --id controls/checkbox
python3 scripts/ui-showcase-cli.py --socket /exact/own/run/ui.sock \
  --profile showcase-v19 activate controls/checkbox
python3 scripts/ui-showcase-cli.py --socket /exact/own/run/ui.sock \
  --profile showcase-v19 snapshot
```

The complete accepted [R1/D1 schema](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/docs/specs/slyx-iv1.5/spec.md#wire-v19-один-запрос-один-ответ)
defines fields and error codes. Each request is one UTF-8 JSON line with
`protocol:19`, nonempty `request_id`, `op`, and only that operation's exact fields.
Duplicates, NUL, trailing data, invalid UTF-8/types/ranges and unknown fields are
refused. Request and reply including newline are bounded to 1 MiB; u64 counters
are JSON integers. A private Linux Unix socket retains the existing 0700 directory,
0600 socket, eight-client and two-second deadline limits; there is no discovery,
TCP, arbitrary memory access or batch mutation.

Operations: capabilities/list-sections/select-section; tree/find/inspect/geometry;
diagnostics/assert-no-errors; focus/navigate/activate/cancel; scroll;
begin-hold/advance-hold/release-hold/cancel-hold; snapshot. Use `--help` on the
client/subcommand for fields. Find uses exactly one of `--id`, `--role`, `--name`;
all matches are exact and frame ordered. Scroll uses `--delta-y`; deterministic
hold uses `--duration-ms`. Unsupported setters, drag, editor/gesture RPC,
overlays/crop and transition finishing are not silently emulated. Collections
expose materialized nodes, not all logical records. Common strict diagnostics
do not certify accessibility or full family qualification.

Actions use the shared app/family dispatch and reducers. Check `dispatch` and
`application.status` plus observation/effect counters, not just `ok`. Selection
can be unchanged/pending/applied/rejected; dirty Stay/Discard and upper modals are
not bypassed. Activate never completes a hold. Test-time disables automatic clock
stepping: 999ms + release yields no effect, a new 1000ms cycle yields one effect.

Exit 0 is structured success, 1 is structured refusal, 2 is an unknown outcome
(transport/correlation/schema failure). No operation retries, rediscovers an
endpoint or recovers automatically. `request_id` is correlation, **not**
deduplication. After a lost reply observe current state before a new intention;
never blindly resend a mutation. Only one bounded last action is retained.

## Ownership, failure and snapshots

The UI thread synchronously services transport between completed app ticks.
App owns model/input and captures copied semantics/observations at publication;
the tools host owns transport and operation scratch. Retained readers hold typed
family/font/image/painter generations. Borrowed data does not outlive an
operation; owning copies are explicitly destroyed. The ordinary app has no
server service hook or new debug-retained payload.

After a failed rebuild/capture/render/readback/present, queries can expose only
the last owning frame as `historical`, with separate current model and published
revisions. Actions/current snapshots are blocked. Query, resize and ordinary input
do not repair failure. Explicit native host **R** rebuilds accepted model without
replaying the action. Pending release/loss cleanup remains available.

Snapshot renders a frozen owning reader, reads actual full drawable pixels,
presents, restores renderer state and checks association/output before encoding.
Its manifest includes frame/epoch/model/resource/build/locale/scale/clock metadata,
nodes, diagnostics and observation. JSON and `screenshot.bmp` are written in a
private `.incomplete-*` staging directory; `renameat2(NOREPLACE)` publishes one
`snapshot-*` directory without overwrite. Failures return no final package;
incomplete directories are diagnostic artifacts, not successful snapshots.
Successful packages survive server shutdown. Snapshot does not dispatch, advance
clocks, change model/focus or include overlays/crop. IO duration is excluded from
subsequent interactive clock accumulation. SDL readback surfaces have a separate
native resource ledger.

## Checks

```sh
python3 -B scripts/test-ui-showcase-cli.py
python3 -B scripts/test-slyx-isd.py
odin test consumer/ui_showcase_tools -collection:ui=kit \
  -define:UI_SHOWCASE_TOOLS=true -define:UI_DEMO_TEST=true \
  -define:UI_SHOWCASE_TEST=true -define:ODIN_TEST_THREADS=1 \
  -extra-linker-flags:"$(pkg-config --libs libpng zlib)"
python3 -B scripts/test-ui-showcase-tools-live.py --isd /path/to/verified/isd --only all
```

The last command saves addressed logs, manifests, original BMPs and display PNGs,
compares BMP/display pixels, and stops every run in `finally`. It covers all 24
selectors plus Controls/native+CLI outcome, settings Confirm/dirty Stay/Discard,
table scroll and partial/full HUD hold in ru/en at the D1 size/scale matrix.
Every saved image still requires visual inspection; a successful script exit
does not claim that inspection or independent approval. Software tests are
separate from display evidence. Full F2/F3/F4 qualification is not replaced by
selector smoke tests. Long allocation tests run serially by exact test ID, with
all groups retained rather than excluded from a claimed full suite.
