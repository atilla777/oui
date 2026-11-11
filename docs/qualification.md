# Qualification boundaries

Experimental v0.1.0 local candidate. Relocated author correctness/display and
performance checks below are complete on the identified supplied input set.
This is not independent approval, a remotely available qualified revision, or
completion of the cross-repository migration. Candidate commit/clean-clone and
public acquisition checks remain separate gates. No public repository/tag/release
or Slyx pin has been published by this tree.

The historical integrated Slyx kit source was
`833d6ecead540fcd1dbd1d2da88985cff0552387` (2026-11-10).
Its four workloads were minimal menu, frequently updated HUD, large collection,
and screen/resource switches, on/off instrumentation, three fresh processes per
variant, warmup10/samples30. Required cycle/memory/handle comparisons under the
separately accepted B1-A1 scope were 132/132 PASS. Cold/teardown timing remained
diagnostic: 72 observations, 11 exceeding the old reference. Original B1 remains
193/204 PASS, 11 FAIL, **not** a successful latency guarantee. Cleanup/no-replay
correctness remains blocking, independent of diagnostic timing.

These historical results do not qualify the relocated tree or its updated codecs.
The separate author repeat below must not rewrite that history. Agent display runs require an
explicitly selected whole verified ISD with linux-abstract-v1, own run/input/PNG,
explicit focus and stop in finally. No desktop fallback.

F8 retains app-owned model, explicit ownership/lifetime, fallible prepare before
commit, historical-reader nonauthority, fail-closed action/snapshot and explicit
recovery without replay. Partial/excluded APIs remain experimental. No physical
gamepad, WCAG, IME/bidi/shaping, other-platform or native/GPU heap guarantee.

Historical public source report (not a prerequisite for building):
https://github.com/atilla777/slyx/blob/833d6ecead540fcd1dbd1d2da88985cff0552387/docs/ui-kit/qualification.md
Private raw logs/screenshots/session data are not included here.

## Relocated author checks (2026-11-11)

Input basis: initial independent root `382a793b99bd2877edc550f81fa4eab6c9a54a2f`
plus the maintained candidate overlay, including the UI-only wrapper, portable
preparation and complete source map. The supplied check set before this
documentation-only summary had inventory SHA-256
`e09bc37c3041bf80ae6e09397f027257aa44b99e70485ee553bcbae197f59d13`.
It maps630 supplied files, including the native-codec check helper (root paths
already adapted in the initial tree, rechecked separately after the summary).
Executable/resource bytes and modes are unchanged by this summary;
the updated inventory records only the new documentation hashes.
This is an input identity, **not** a fabricated final commit or tree hash.

- All55 discovered package/model/consumer/helper suites: **558 tests PASS**,
  including full tools-enabled app138/138 with test-time branches enabled.
  Full ordinary app:138/138 PASS. The earlier interim count548 omitted ten
  singular `Finished 1 test` lines; no failed test was removed or relabeled.
  Both exhaustive walks include actual owning-allocation failure sequences,
  historical/current reader barriers, native-synthetic events, partial-init,
  copy/prepare/render/snapshot/IO/refusal/recovery and no-replay guards.
- Loader production11/11 and native-fault12/12, including four corrupt compressed
  PNG-stream cases with repeated cleanup/recovery. Qualification phase history/off
  probes additionally2/2 in each ordinary/tools qualification variant.
- Unicode generated data check, primary/fallback font rebuild/hash checks,
  wrapper10/10, distribution5/5, CLI8/8, external own-model/own-font-binding
  consumer, foundation and six physical restricted recipes: PASS.
- Separate restricted native HUD/Settings/Inventory: six ru/en runs, invalid
  font refusal, public adapters, outcomes and zero tracked/retained cleanup.
  This is not a substitute for union Lab flows or hardware-gamepad evidence.
- Full original F2 scale/mode/size matrix and gallery G01–G21/C01–C08,
  Lab flows86 captures, interaction38, tools49 frozen BMP plus49 native PNG,
  five endpoint gates, native recipes12, minimal menu60, G21 original pair6
  and four-workload24 captures: checked and visually inspected separately from
  behavioral assertions. F2/gallery contains298 captures. The extra original
  G21 pair960→800→960 is distinct from the readable large viewport pair.
- Local pinned vendor and submodule acquisition fixture built menu/showcase
  from each copy with matching file hashes/gitlink. It is **not** public
  acquisition from a published oui revision.

Actual real-display evidence is X11/software through verified private ISD,
not the user's desktop. All own runs were stopped. Some inspections used
lossless labeled viewing pages: no scaling, no removal of any non-background
pixel, only a proved-uniform bottom tail omitted; original PNG/BMP and per-image
hashes remain available to the reviewer locally. This is visual inspection,
not an automated image pass or independent review. No physical gamepad, IME,
bidi/shaping, native/GPU heap or other-platform qualification is implied.

### Performance applicability and observed comparison

Same CPU (Intel Core Ultra X7 358H/16 CPUs), Odin84bc3fc, SDL3.4.16/TTF3.2.2,
font/atlas bytes, software renderer, X11/vsync0, sizes/locale/scales, default
optimization and existing native fixture operations/clock boundaries. The path
move does not change the workload or its owners. Decoder pins intentionally
changed to verified libpng1.6.59/zlib1.4; actual loaded libraries were checked
per run. The updated native-input ISD is recorded in evidence; orchestration,
focus/F9 delivery, polling, screenshots and log IO are outside measured cycles.
There is no detected change of metric meaning or applicable ceiling that needs
a new human budget. Updated codec work inside a timed cycle remains measured,
not excluded. This conclusion uses current fixture/source/resource comparison
and raw observations, not an automatic carry-forward of historical PASS.

Four workloads × on/off × three fresh sequential processes; each10 warmup and
30 measured cycles. Order was workload→variant→three repetitions (historically
the two variants were interleaved); no affinity/frequency/foreign-load control
was added and no outliers were removed. Elapsed time is monotonic raw ns,
not thread CPU time. Per-process nearest-rank p95 and every-sample max are
compared independently. Global owner/observer peaks include final cleanup
observations; off internal memory counters remain unavailable, not zero/pass.

| Workload | on p95/max ms (worst process/sample) | off p95/max ms | on limits p95/max ms | off limits p95/max ms |
|---|---:|---:|---:|---:|
| Menu |5.154487 /5.189034|4.691847 /4.721381|9.6 /12.4|9.0 /13.3|
| HUD |4.373375 /4.439608|4.784979 /5.097580|9.5 /13.0|8.9 /17.9|
| Collection |94.063703 /94.567391|51.837783 /56.792508|164.7 /198.9|105.7 /127.3|
| Switches |21.237914 /22.655467|14.995832 /16.884831|49.0 /62.1|42.2 /53.3|

All132 required comparisons passed (cycle time and on allocation/bytes/owner
live/peak/observer live/peak/retained handles); all24 functional outcomes matched
within each workload across variants/repetitions. Cleanup/no-replay invariants
passed independently of timing. All72 cold/owner/native-teardown diagnostics
were below their old reference values in this repeat; they are still diagnostics,
not newly accepted latency guarantees. Historical B1 FAIL remains unchanged.

On-only ceilings, unchanged from B1-A1 (KiB =1024 bytes; all counts integral):

| Workload | allocs/cycle | bytes/cycle KiB | live KiB | global peak KiB | observer live/peak KiB | retained native peak |
|---|---:|---:|---:|---:|---:|---:|
| Menu |1120|279|88|145|73/109|1|
| HUD |956|132|38|67|37/55|1|
| Collection |120228|14273|2269|3941|9217/13825|1|
| Switches |15689|6075|161|504|289/433|3|

These are per-process worst observations, not pooled averages. Final zero live,
zero bad-frees and zero retained ledger handles are separate correctness guards.

## Repeating the checks

Use [quickstart](quickstart.md), [recipes](recipes.md) and
[resources](resources.md) for exact native pins, explicit resources, build
flags and physically restricted closures. Supply a verified ISD explicitly;
it is an optional agent-test dependency, not a production runner.

```sh
UI_KIT_ROOT="$PWD" python3 -B scripts/test-ui-kit.py -v
python3 -B scripts/test-ui-isd.py -v
python3 -B scripts/test-ui-showcase-cli.py -v
bash scripts/test-ui-foundation
bash scripts/test-ui-showcase --portable-check  # bounded, not full qualification
TMPDIR=/tmp/opencode bash scripts/test-ui-showcase --portable-acquisition
python3 -B scripts/test-external-consumer.py
```

For the full package walk, discover **every** directory containing `@(test)` in
`kit/`, `consumer/`, `tests/` and run `odin test <directory> -collection:ui=kit`
with `-vet -vet-style -vet-tabs -vet-semicolon`, `ODIN_TEST_THREADS=1`,
`UI_DEMO_TEST=true`, `UI_SHOWCASE_TEST=true`, `STANDALONE_MENU_TEST=true`,
`UI_SHOWCASE_TOOLS=true`. Do not assume `odin test` recurses. Use dummy for
headless/native-software test suites. Run the full app again with
`UI_SHOWCASE_TOOLS=false`. For the separate loader native-fault check, supply
the official pristine local libpng source and verified archive (no download or
installation by the helper):
`python3 -B scripts/test-atlas-native.py --source "$LIBPNG_SOURCE" --archive "$LIBPNG_ARCHIVE"`.
Use the pinned libpng/zlib pkg-config and runtime paths described in resources.
The helper checks archive/header identity, actual ABI/loader linkage and executes
both production11 and C fault-shim12 tests; it refuses mixed libraries.
For qualification phase-history tests explicitly define
`UI_QUALIFICATION=true` and select both `qualification_*` tests.

```sh
python3 -B scripts/test-ui-showcase-live.py --proof "$PROOF" --isd "$ISD" --full-gallery
python3 -B scripts/test-ui-showcase-live.py --proof "$PROOF" --isd "$ISD" --lab-only
python3 -B scripts/test-ui-showcase-interaction-live.py --isd "$ISD"
python3 -B scripts/test-ui-showcase-tools-live.py --isd "$ISD" --only all
python3 -B scripts/test-ui-showcase-tools-gates.py --proof "$PROOF" --isd "$ISD"
```

`PROOF` is a freshly exported complete root from `scripts/export-ui-kit.py`,
with its supplied inventory; bounded check builds the binaries used by gates.
Extra native fixtures use `tests/ui_recipes/{hud,settings,inventory}/native`
from physical selected closures: explicit focus, F11, readiness/after PNG,
F12, verify app exit0 and always stop. For performance use existing
`consumer/standalone_menu/qualification`, `tests/ui_recipes/hud/native`, and
`consumer/ui_showcase/qualification` (sections collections/catalogue).
On adds `UI_QUALIFICATION=true` plus `--instrument`; off does not. Keep
test-controls, supplied font(s)/atlas, original sizes and Normal1; F9 once
per fresh process, wait for `Q complete`, F12, verify cleanup and stop.
Keep every `Q scope`, `Q outcome`, cleanup and teardown line; compare each
process separately against the unchanged tables above and the historical
allocation ceilings. Capture/inspect PNG outside the measured interval.
