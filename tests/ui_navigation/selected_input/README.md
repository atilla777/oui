# Selected navigation — complete composed-input fixture

Последующий bounded [composed-render вклад](RENDER.md) расширяет тот же publisher/
Reader opt-in render config. Ниже сохранены input-контракт и наблюдения первого
input-вклада; актуальные combined commands, costs и remaining inventory — там.

Ограниченный вклад `slyx-iv1.1.2`, до независимого ревью и интеграции. Завершён
**composed input**, не renderer. Основа — R1/D1 + R1-A1/D1-A1
([решения](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/docs/specs/slyx-iv1.1/spec.md)) и отдельно разрешённые shared
geometry/activation-owner/edge-owner/non-clearing painter repairs. Новых
transition/custom/editor/collection implementations здесь нет и они не являются
обязательствами этого вклада.

Это конкретный executable typed consumer четырёх выбранных семейств, не новый
umbrella runtime, registry, второй normalizer или compatibility facade. Input
использует настоящие SDL event values и установленные family adapters; fixture
не открывает окно, renderer, fonts или физический gamepad. На реальном SDL window
этот input composition ещё отдельно проверяется в render-вкладе.

## Один владелец события

`input(&runtime,event,window_extent)` нормализует событие **ровно один раз** через
`ui_sdl.normalize_event`. Общие keyboard/mouse/gamepad front/release/loss latches
обновляются даже при Not_Ready; Home/End включены в тот же key owner. Adapters
получают Normalized_Input, не открывают устройства и не нормализуют SDL повторно.

Явный порядок: physical bookkeeping/loss → selected layer hit → hold capture →
slider specialization → scroll wheel/List → controls semantic dispatch. Завершённый
path consumed, base activation после family intention повторно не выполняется.
Foreign window/device и repeated fronts не создают capture/action. Stale reader
отказывает новым actions, но не теряет необходимые release/loss cleanup edges.

- Mouse checkbox/Select/popup item/Dialog press/release использует общий press,
  затем `consume_press` и controls.dispatch; Bool/Item/Open/Close/Result остаются
  намерениями. Caller явно меняет model и rebuild, не callback/adapter.
- Layers hit/shield применяется **до** acquisition slider/hold. Tooltip не берёт
  ввод; popup body без доступной кнопки не пропускает click в нижний slider.
- Wheel использует owning *wheel hit projection* общих interaction targets:
  только selected scroll region IDs имеют input availability; bounds/clip равны
  viewport content clip. Затем тот же layers.hit_test определяет shield/scope,
  а единственный scroll dispatcher создаёт pending Scroll_By. Нет второго layer
  hit алгоритма или собственного scroll solver. Flipped wheel меняет знак.
- Vertical List navigation идёт через controls → scroll.Move_Item; pending focus
  применяется на следующем publisher commit. Selection не меняется. Horizontal
  List/grid actions явно отклоняются, future collections не включаются молча.
- Slider SDL adapter: keyboard Left/Right/Home/End, gamepad Left/Right, mouse rail
  rounding, continued drag/clamp; используется track, не label/root width.
  Scope/unavailable/removal/stale/projection-discontinuity/loss/failure отменяют
  capture. Reconcile вызывается после swaps до registration disposal.
- Hold native adapter владеет только отдельным clock/pending-release state.
  Completion использует exclusive activation owner и единственный routed sequence.
  Key/mouse/gamepad loss/release при Not_Ready сохраняется до rebuild; mouse-up
  не теряется даже без доступной coordinate projection. Failed publication вызывает
  block обоих adapters; wall interval failure/recovery не начисляется скрытно.

`hold_step` перед начислением времени revalidates запомненный pointer против
новой frozen input projection. Это synchronous projection check, не новый
physical edge и не повтор normalize. Deterministic headless Advance остаётся
отдельным API, не смешивается с wall-clock fixture.

## Typed publisher и reader

`publish` — одна fallible транзакция: begin_attempt → layout → layers → scroll →
final geometry/hit projection → controls/hold metadata → все owning readers →
validate всех selected candidates → enter_commit → infallible swaps → finish →
capture reconciliation → registration disposal. Структурный layout решается один
раз; scroll меняет его owning geometry через свой существующий translation stage.

`Reader` независимо владеет final geometry, полным frozen input frame, wheel
projection и frames layers/scroll/hold/controls. Source candidates не заимствуются
после commit. Reader переживает destroy Runtime; shared stamp удерживается каждой
owning projection. Простое присваивание допустимо только как move с обнулением
источника. Allocator живёт дольше reader и adapter IDs. Одно device Input закрывается
через backend.close_input при destroy. Никаких retained SDL textures/fonts здесь нет.

Fixture descriptor capacity ограничена и проверенно reserved до appends: 17 nodes,
9 targets, 5 controls максимум. Это локальный явный consumer, не универсальный
screen builder. Package errors проверяются до swap; bool publish сообщает отказ
fixture, нижележащие API сохраняют собственные addressed diagnostics.

Optional `samples: []base.Geometry_Entry` содержит **уже вычисленные** frozen
numerical input bounds/clip/content/content_clip. Caller отвечает за coherent
полный набор затронутых descendants; отсутствие entry означает static geometry.
Fixture не вычисляет transitions/gestures и не интерпретирует timeline/model.
Samples materialize в owning reader/interaction values с новым общим stamp;
unknown/duplicate ID и invalid sampled bounds/scale отказывают до любого swap.
Input-disabled/zero-opacity sample не становится доступной кнопкой. Совпадение
stamp не означает соответствия ещё не созданному renderer bundle.

## Проверки и границы

```sh
odin test tests/ui_navigation/selected_input -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon -define:ODIN_TEST_THREADS=1 -out:<fresh-tests>
odin build tests/ui_navigation/selected_input -collection:ui=kit -show-import-graph -out:<fresh-fixture>
<fresh-fixture>
```

19 integration tests: checkbox one-effect, popup shield/close/item, Dialog Cancel/
pointer result, native gamepad front, wheel/List pending/focus, hold capture/
completion/loss/release, foreign window, Not_Ready front without replay, stale
reader/track, sampled slider/hold/scroll content-clip, scope capture cancellation,
owning reader after destroy, 64 rebuild без history growth. **349** backing
allocation positions полного publisher/readers базового сценария (base + hidden
popup + tooltip, без modal/samples) проверены по одному: failure
сохраняет все прежние owners/readers/refcounts и блокирует readiness; zero live
и bad-frees после destroy. Reusable adapter tests отдельно проверяют keyboard/
gamepad slider edges и invalid-coordinate hold release.

Linux x86_64 / Odin `dev-2026-10-nightly:84bc3fc`, SDL3 `3.4.16`, scale=1, явный
clock 0→500ms: fixture effects=3 / sequence=3, Runtime=2752, Reader=1056 bytes;
allocations=25750 / cumulative bytes=4671406 / live=21296 / peak=74558 после
сценария и 64 rebuild. Destroy live=0/bad-frees=0; failure fixture peak=68604.
Учтены все выбранные common/layout/family/input/reader costs, не только adapters.
Backend resources=0 здесь означает **не создавались**, не proof renderer cleanup.

Исторический input-only kit включал base/layout/interaction/layers/scroll/hold/
controls/style/text/unicode_graphemes/ui_sdl и hold/sdl, controls/sdl. Текущий
combined fixture дополнительно явно выбирает ui_sdl_text/TTF; независимые
headless closures не изменились. Unported/tools/других optional families нет.

Selected renderer проверен в software scope [render-вкладом](RENDER.md).
[Final task inventory/coverage](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/libs/UI_NAVIGATION.md) завершает
implementation candidate exact `.2`; real menu AC-011 относится к prerequisite
`.5`, не к новой window-migration стадии здесь. Полный build старых consumers не
требуется R1-A1/D1-A1. Independent review, Git/Dolt publication и completion
не подменяются авторскими implementation checks.
