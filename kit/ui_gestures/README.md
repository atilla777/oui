# ui_gestures — experimental drag/drop, repeat и pan

Кандидат `slyx-iv1.1.3` до интеграции. [Принятый basis](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/docs/specs/slyx-iv1.1/spec.md)
— R1/D1 с отдельными R1-A1/D1-A1; это не новое принятие поведения.
Прямые зависимости: base/layout/interaction/scroll, core. **Нет text, Unicode,
SDL, controls/hold, layers, editor, tools.** Import `g "ui:ui_gestures"`.

## Owners и типизированная композиция

`create(allocator)->State` — zero-allocation technical owner, не focus manager.
Первая подготовка checked-создаёт retained family lifetime identity; после
неудачной попытки она остаётся до `destroy`. `prepare(&state,&geometry,
&interaction_candidate,scroll_frame_or_nil,descriptions,model_revision,
allocator,scope_id="",geometry_view={}) -> (Candidate,Error)`:

- заимствует входы синхронно, клонирует description/payload/type lists/ancestry,
  frozen geometry и technical live state;
- требует matching stamps; scroll обязателен только для Repeat/Pan;
- проверяет IDs/kinds/bindings, finite step, positive repeat delay/interval,
  duplicate types/owners и выбранный scope gate; учитывает region availability;
- сохраняет layout traversal order, а не порядок descriptions, для hit/navigation;
- связывает activation ownership источников с `"gestures"` в interaction
  **candidate**. Abort уничтожает весь selected attempt, не публикует его часть.

Layer owner/composer подаёт проверенные scope membership, активный scope и frozen
availability/shields. Это не второй modal engine: передайте полный common claim
set всех selected family bindings и проверьте несовместимое двойное владение.
Optional numerical geometry view complete/stamp-matched, finite, owning после
prepare; interaction hit bounds и renderer используют эту же projection.
`Error.id` заимствует input description, не освобождённый candidate.

`validate_candidate(publication,state,candidate)` проверяет owner lifetime/version
и shared attempt/model/sequence, включая destroy/recreate на том же адресе.
До `base.enter_commit` сделать все fallible `try_copy_frame` readers и выполнить
общую проверку selected candidates. `commit` только swap/deallocation, без
allocation/callback; `base.finish_commit` открывает readiness после всех swaps.
Commit предполагает проверенный typed publisher. Dispose callbacks — после него.
`destroy_candidate`, `destroy_frame`, `destroy` симметричны исходным allocators;
owning structs нельзя shallow-copy. Reader переживает source runtime и хранит
собственные payload/signals; historical frame не авторизует current dispatch.

## Сохранённые state machines

`dispatch(state,interaction,scroll_state_or_nil,Action)->Result` проходит общие
guards до value validation/allocations; stale frame не исполняет действия.

- Begin создаёт новый cycle, Mouse drag и любой pan сначала Armed. Шесть logical
  screen units (включая диагональ) активируют движение; geometry inverse mapping
  используется для pan, не переписывает layout.
- Aim для Keyboard/Gamepad/Agent выбирает Drop_Target; scope/type и исключение
  ancestor/self drop сохраняются. End создаёт один versioned Drop_Proposal либо
  Cancelled{Below_Threshold/No_Target/Rejected_Target}. Proposal — не reducer.
- Repeat Begin даёт один шаг. Advance получает явные nonnegative milliseconds,
  сохраняет delay/interval, checked elapsed arithmetic и clamped scroll. End не
  добавляет trailing step. `activate_repeat` даёт один semantic scroll step **без**
  cycle, hold или application event, как прежний ordinary Activate.
- Pan сохраняет исходный offset, clamps; изменение viewport/scale/max-offset/clip
  rebases на последней pointer position, без jump и без изменения focus.
- Rebuild отменяет removed/unavailable/changed owner, не retargets cycle; исчезнувший
  target очищается. `block(state,publication,reason=Update_Failed)` — infallible
  allocation-free cleanup/loss boundary, выключает readiness и clock epoch, не
  активирует historical frame и не меняет его immutable projection. При exhaustion
  возвращает false; counters не wrap. Explicit Cancel остаётся current action.

Result strings **borrow State до следующей mutation/destroy**. Для сохранения
копируйте данные либо owning Frame. Наличие прежнего proposal в historical result
не является командой повторить application reducer. Успешная technical mutation
требует rebuild перед следующим действием. Allocation refusal не меняет live
state/sequence; scroll mutation происходит только после всех family allocations.

## Native и regressions

[Отдельный SDL adapter](sdl/README.md) и
[единый runnable consumer](../../tests/ui_editing/selected_input/README.md).

```sh
odin test kit/ui_gestures
odin test kit/ui_gestures/sdl
odin test consumer/gestures_demo/model
odin run tests/ui_editing/gestures_only -collection:ui=kit
```

[Costs, closures и migration inventory](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/libs/UI_EDITING.md).
