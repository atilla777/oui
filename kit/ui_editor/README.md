# ui_editor — experimental single-line Unicode editing

Кандидат `slyx-iv1.1.3`, до интеграции и независимого ревью. Основа:
[R1/D1 и отдельно принятые R1-A1/D1-A1](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/docs/specs/slyx-iv1.1/spec.md).
Это единственная новая реализация editor; старого monolithic facade нет.

Прямые зависимости: `ui_base`, `ui_layout`, `ui_interaction`, `ui_text`,
`unicode_graphemes`, `core:*`. Транзитивно text использует `ui_style`.
SDL, controls/layers/scroll/collections/gestures/tools не обязательны.
Collection: `-collection:ui=kit`, import `editor "ui:ui_editor"`.

## Владение и publication

- `create(allocator) -> State` не выделяет память и не создаёт focus manager.
  State принадлежит приложению. Первый `prepare` checked-выделяет одну retained
  family lifetime identity (32 bytes в проверенной среде). Она остаётся до
  `destroy`, в том числе после отказа подготовки. Это выбранная family cost.
- `prepare(&state, &layout_frame, &interaction_candidate, &text_frame,
  descriptions, metrics, allocator, scope_id="") -> (Candidate, Error)`
  заимствует входы синхронно. Все projections должны иметь один stamp.
  Text frame содержит тот же controlled value и single-line NoWrap/Clip options.
  Layout содержит field и его непосредственный leaf text child. Role и focus
  принадлежат общему interaction target; editor не владеет layout solver.
- Prepare клонирует строки, Unicode boundaries, runs/stops и geometry; проверяет
  glyph/metrics, description bindings, revision/resolution. Он связывает
  activation owner **candidate** interaction field с `"editor"`. При отказе
  всей попытки caller уничтожает и этот interaction candidate, не публикует
  частично изменённые owners. `Error.id` заимствует исходную description,
  не уничтоженный candidate; для сохранения error caller копирует ID.
- До commit явно собрать claims всех выбранных families (включая editor field
  и text child), проверить несовместимое двойное владение через interaction.
  Layer/collection composition подаёт уже согласованные geometry/availability
  и active scope token; editor не импортирует этих owners.
- `validate_candidate(&publication,&state,&candidate)` проверяет точный State,
  его retained lifetime/version и текущий shared attempt/model/sequence.
  Destroy/recreate State на том же адресе не оживляет старый candidate.
- До `base.enter_commit` создать все fallible `try_copy_frame` readers и прочие
  selected candidates. После общей повторной проверки: infallible
  `interaction.commit`, `editor.commit`, остальные selected swaps,
  `base.finish_commit`. Commit не проверяет это повторно и не выполняет
  allocation/callback. Registration disposal/reconciliation — после barrier.
- `destroy_candidate`, `destroy_frame`, `destroy` освобождают собственные данные
  их исходными allocators. Owning objects move-only по соглашению; shallow copy
  не передаёт владение. `try_copy_frame` возвращает независимый owning frame;
  reader переживает source runtime, удерживая shared lifetime. Historical frame
  можно читать, но нельзя использовать как разрешение current dispatch.

## Editing и прежние ограничения

`Description{id,node_id,text_node_id,label,value,max_graphemes,revision,resolution}`.
Библиотека не вводит limit 64: это выбор демонстрационного consumer. Сохранён
source ceiling 65 536 bytes, Unicode 15.1 EGC scanner, отсутствие normalization,
запрет C0/C1, bidi directional controls, line separators и многострочности.
Glyph support проверяется отдельно. Emoji EGC tests не обещают emoji rendering.

`dispatch(&state,&interaction,Action,metrics) -> Result` сначала проверяет общий
current/source/availability/focus gate, затем family-specific value/range.
`Select`, `Move{Left,Right,Home,End,extend}`, `Insert`, `Backspace`, `Delete`
сохраняют byte offsets только на EGC boundaries. Вставка пересегментирует весь
результат (combining/RI/ZWJ), deletion удаляет целый EGC; Shift/collapse и
leftmost pointer tie сохранены. Caret reveal учитывает один physical pixel.

Изменение значения выдаёт **две независимые owning copies**: result.proposal и
private pending State. `destroy_result` обязателен. Proposal — не application
outcome. Caller применяет reducer ровно один раз и заново публикует:

- Accepted: точные proposed bytes, большая value revision, тот же sequence;
- Rejected: неизменные bytes/revision, тот же sequence и причина;
- External: большая value revision, новый controlled value;
- Unchanged допустим без unresolved pending. Stale resolution отвергается.

Submit/Cancel — отдельные intents, не скрытое изменение модели. Успешная
technical mutation/intention выключает readiness до rebuild; повтор против
historical frame — Not_Ready. Allocation refusal не публикует частичный proposal
и не продвигает sequence. Все owning Unicode boundaries используют
`try_boundaries`. Counters не переполняются молча.

`sample_candidate(&candidate, Geometry_View)` синхронно материализует complete
numeric projection и input gates выбранных fields; rejects stale/incomplete/
duplicate/nonfinite samples до mutation. Caller обязан подать ту же frozen
projection в common interaction hit bounds и renderer. Это не transition engine.
`editor_hit` и `editor_drag` работают в layout space; dt задаёт caller явно.

## SDL adapter и проверки

Отдельный [ui_editor/sdl](sdl/README.md), никакого обязательного backend в core.

```sh
odin test kit/ui_editor
odin test kit/ui_editor/sdl
odin test consumer/text_input_demo/model
odin run tests/ui_editing/editor_only -collection:ui=kit
```

Полный current consumer, costs и migration disposition:
[UI_EDITING](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/libs/UI_EDITING.md). Оригинальные monolithic tests сохранены как
исторические oracles; старые full-demo builds не названы работающими.
