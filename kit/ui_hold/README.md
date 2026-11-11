# Progress / Hold — experimental headless API

`import hold "ui:ui_hold"`, `-collection:ui=<kit-root>`; в репозитории — `kit/`.
Физический минимальный closure: `ui_base`, `ui_layout`, `ui_interaction`, `ui_hold`.
Только Odin core; без SDL, text/fonts/style resources, layers/scroll/controls,
редактора/gestures/tools, переводов или настроек Slyx. Host может отдельно добавить
style/render projection; progress fill сам не является renderer.

Кандидат `slyx-iv1.1.2`, R1/D1 + R1-A1/D1-A1
([источник решений](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/docs/specs/slyx-iv1.1/spec.md)). Это законченный
headless hold-вклад **до независимого ревью/интеграции**, не завершение всей задачи
и не доказательство полной SDL composition. Headless `ui_layers` audit описан
в [отдельном вкладе](../ui_layers/README.md). Прежний монолитный `kit/ui/hold.odin` удалён без facade;
его historical tests сохраняются как oracles, не как текущий build target.

## Подготовка и владение

`create(allocator)` / `destroy(&state)` владеют live cycle, последним результатом
и published Frame; общего focus manager, clocks и application model здесь нет.
`Description{id,threshold_ms}` привязывает hold к ordinary button target.
Threshold — положительный i64. `Progress_Description{id,value,maximum}` требует
finite 0 ≤ value ≤ maximum и maximum > 0; fill — snapped доля content rect.
Это metadata, а не новый structural layout kind или второй layout solver.

`prepare(&state,&interaction_context,&geometry,&targets,progress,holds,allocator)`
возвращает `(Candidate,Error)`. Geometry/targets должны иметь одинаковый stamp.
Inputs заимствуются на вызов. Candidate владеет descriptions/IDs/progress/live
projection/result и отдельным future live ID; result IDs привязаны к его storage.
Prepare не меняет live cycle/focus/регистрации/application model. На **успехе**
он связывает selected candidate interaction targets с exclusive activation owner
`"hold"`; это candidate-only операция, никогда не применяйте её к published frame.
Все новые binding strings staged до первого transfer: allocation/validation
failure оставляет targets неизменными, partial owners освобождаются.

Typed host объединяет `Capture_Claim{target_id,"hold"}` с claims остальных
выбранных семейств перед `interaction.prepare`. Несовместимые владельцы одного
target явно отклоняются; hold не создаёт параллельного capture arbitration.
Уже иной activation owner отвергается. Для modal/overlay/transition hit availability
передавайте итоговую frozen interaction projection, не необработанный второй layout.

`validate_candidate(&publication,&candidate)` проверяет актуальность association.
Единый typed publisher делает begin_attempt → selected prepares → owning copies/
precommit → validate → enter_commit → interaction/hold swaps → finish_commit →
registration reconciliation. `commit` move-only, освобождает прежний Frame и live
ID их аллокаторами, candidate обнуляется. Во время infallible swap нет callbacks.
Не публикуйте новую interaction рядом со старым hold frame.

`try_copy_frame(&frame,allocator) -> (Frame,bool)` клонирует holds/progress/IDs,
cycle/result и удерживает stamp. Signals и dispatch IDs rebased к owning hold ID.
Reader переживает source Frame/State/Context/Publication; allocator живёт дольше
reader. Уничтожение — `destroy_frame`. Historical reader не разрешает dispatch.
Geometry/style reader при необходимости копируется отдельно выбранным bundle.

## Детерминированный цикл и отказ

`dispatch(&state,&interaction_context,Action) -> Result` использует общий readiness/
source gate и **тот же frame stamp**; нет второго sequence owner. Action duration
передаёт host, скрытого wall clock нет. После фактического изменения нужен rebuild.

- Begin проверяет target availability и exclusive hold binding, положительный
  threshold, cycle exhaustion и allocation до изменения live ID/cycle/focus.
  Repeated Begin не перезапускает активный или completed latch.
- Advance принимает неотрицательный i64 interval, проверяет overflow и перед
  продвижением availability/exclusive binding. На completion sequence exhaustion
  отказывает без изменения elapsed/phase/ready. Zero/idle intervals — no-op.
- На threshold: Progress, затем Completed; live phase и observable signals
  устанавливаются **до** одного `interaction.dispatch_owned` с исходным source.
  Plain/routed/pointer activation не может обойти `Activation_Required`.
  Routed handlers используют общий target→ancestor route; reentry заблокирована.
- Completed_Waiting_Release не завершается ещё раз и не снимается Cancel.
  Только корректный Release возвращает Idle; повторный Begin не создаёт цикл.
- Ранний Release даёт Cancelled/Early_Release. Explicit Cancel принимает
  положительную известную reason; source/ID Release должны соответствовать cycle.
  Window/device/pointer loss host передаёт явно, а не переводит в completion.

При rebuild Holding проецируется в Cancelled по приоритету Removed → Unavailable
→ Mode_Changed → Threshold_Changed → UI_Focus_Lost. Проекция не меняет live State
до commit. Physical pointer-inside/loss требует выбранного native adapter и его
итоговой geometry; headless package не читает ОС/SDL или cursor самовольно.

`Result.signals`/`dispatch.event.id` заимствуют live State storage до следующего
изменения/commit/destroy. Для долговечного результата сначала rebuild и owning
Frame copy либо собственная application copy. Signals и dispatched activation —
один cycle outcome, не два application effects. Callback лишь записывает намерение;
не вызывает prepare/commit/reducer/register. После application effect failure
host восстанавливает принятую model, не повторяет completion/reducer.

Not_Ready (включая busy/reentry) не освобождает release latch и не начисляет время.
Failed publication блокирует ready; физические loss/release edges должны быть
сохранены native adapter до успешного rebuild, clock baseline сброшен. Эта
integration policy проверяется отдельно от headless explicit intervals.

Ошибки prepare: Invalid_Hold/Invalid_Progress с borrowed input ID, Allocation,
Stale. `describe_error(error,stage=.Prepare)` даёт общий `Family.Hold` view;
`base.try_copy_error` / `base.destroy_error` сохраняют ID независимо от входов.
Dispatch использует interaction.Code; invalid time/cycle/sequence limits имеют
`Invalid_Action` без silent saturation счётчиков (elapsed лишь clamp до threshold).
Allocation/refusal не означает fallback или частично применённый success.

## Проверки и migration

```sh
odin test kit/ui_hold -vet -vet-style -vet-tabs -vet-semicolon -out:<fresh-tests>
odin build tests/ui_navigation/hold_only -collection:ui=kit -show-import-graph -out:<fresh-fixture>
```

[`hold_only`](../../tests/ui_navigation/hold_only/main.odin) — реальный typed
publisher: explicit 499+1ms → one routed completion → 64 rebuild → independent
reader после destroy. Own fixture claim/handler; нет конфигурации приложения.
Физический внешний kit содержит только четыре каталога closure без symlinks.

20 headless tests: все sources и cancellation reasons, Begin/Advance refusal,
readiness/stale/sequence/cycle exhaustion, no bypass/reentry, declared threshold,
неизменность модели/registration при failure, removal/disposal после согласованного
swap, projection priorities, owning progress/result after destroy, seven prepare
и five copy backing allocation refusals, two staged binding allocation refusals,
Begin allocation failure, cross-family claim conflict, 64 rebuild без live growth.
Ни passing exit с bad-free warning, ни source-only imports не считаются proof.

Linux x86_64 / Odin `dev-2026-10-nightly:84bc3fc`, scale=1, explicit Agent clock,
fixture cumulative allocations=2252 / bytes=209416 / live=1341 / peak=3674 после
64 rebuild с reader+handler; destroy live=0, bad-frees=0. State=672, Frame=368
bytes. Цифры включают common/layout/interaction, fixture и owning reader, не
только hold. Exhaustive refusal fixture peak=128 bytes; собственных backend
resources=0. Нет SLA или GPU/driver memory claim.

Четыре `ui_hold/sdl` regression tests проверяют normalized mouse/gamepad
edges, pending release/loss и clock rebase после failure; они не доказывают pixels,
реальную графику, полную layered/transition/control/gesture SDL composition или
весь набор baseline consumers. Старый umbrella API и его wire enum ordinals не
восстанавливаются. Native combination consumers и
общая интеграционная/графическая проверка остаются за пределами этого headless вклада.
Последующий [selected composed-input вклад](../../tests/ui_navigation/selected_input/README.md)
связывает эти native paths и owning typed publisher отдельно от render.
