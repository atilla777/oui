# Profile catalog reducer (headless candidate)

Consumer `slyx-frx.1.3`, integrated and Git-published to `origin/main` in
`6654f81cdf7250bb4e96722a465c830872f256f1`, composes this unchanged pure
model in [the executable catalogue](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/examples/controls_demo/README.md). The host consumes each intent
once and recovers failed UI publication without another reduce. The historical
`.1.1` scope below remains model-only; this source description does not itself
imply feature acceptance, task closure or Beads/Dolt publication.

Pending integration, `slyx-frx.1.1`, implementing the model section of
[D1](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/docs/specs/slyx-frx.1/design.md) on base
`07ce4469cd164c6606ba45c105988a9af611f5b7`.
This is a pure Odin package, not an executable window/demo host. It imports no
SDL, UI, files or clock. The complete rendered catalog remains separate work.

`create()` returns an independent State: fixed `aurora/borealis/cirrus` fixtures,
their applied values, first profile selected, clean draft and `general` tab.
`fixture(index)` returns immutable initial data (invalid index returns empty).
Fixture order is fixed; no create/remove/rename or persistent storage exists.

`reduce(state, Action) -> Result{error,changed}` owns complete atomic transitions:

- Show_Help/Enabled/Intensity/Mode edit only draft (0..100/1; modes
  `calm/normal/vivid`). Tab accepts `general/appearance` without resetting draft.
- Apply writes selected applied values. Cancel reloads applied into draft.
  `dirty(state)` compares values, so editing back to applied clears dirty.
- Select_Profile accepts stable fixture IDs; current-profile selection is a no-op.
  A clean transition loads destination applied values; a dirty transition retains
  current profile/draft, records pending_id and opens Dirty_Departure.
- Dialog_Result in Dirty_Departure accepts `apply-and-go`, `discard-and-go`,
  `stay`; Escape is Stay. The first writes old applied before switching, the
  second does not; both load destination applied. Stay/Escape clear pending only.
- Request_Reset opens Reset. Its result `reset` copies the current profile's
  fixture only into draft; `cancel`/Escape preserve data. Apply is still separate.
- While a Dialog is open, all background reducer actions are refused. Unknown
  profile/mode/tab/result, invalid range/state and Unavailable are refused without
  changing **any** State field, including revision/trace/applied/pending.

State contains fixed-size value arrays and a 32-entry ring trace, with no owned
heap memory or destroy operation. Retained IDs/modes are canonical static strings,
never incoming temporary strings. Accepted changes advance revision and record
kind/source/profile/sequence/frame. Rejected actions return an Error; the future
host may separately report rejection without inserting it into this atomic State.
Nonzero action sequences must increase in a single UI context; repeated/older
intents are refused as Duplicate_Intent. Zero is for direct application actions.
This guard does not replace the consumer's obligation to consume an event once.

After a successful reducer transition, a failed UI rebuild does **not** call the
reducer again or roll back State. The future host must retain the historical UI,
block new actions/snapshots via readiness and retry the same current revision.
Locale/viewport are presentation inputs, not profile identity or settings here.

From the repository root:

```sh
odin test consumer/controls_demo/model
odin check consumer/controls_demo/model -no-entry-point -vet -vet-style -vet-tabs -vet-semicolon
```

Tests cover all departure outcomes, Escape, clean/dirty reset and cancellation,
Apply/Cancel, tab preservation, repeat/current selection, restart fixtures,
invalid IDs/values/pending state, bounded trace and duplicate intent refusal.
