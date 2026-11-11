# ui_custom — experimental

Предынтеграционный API в `task/slyx-iv1.1.4`.
[API, SDL painter/input, shared hit seam и migration](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/libs/UI_CONTENT.md).
SDL painter generation, opaque Canvas, preflight/render и normalized input находятся
в отдельном `ui_custom/sdl`; headless import их не включает. Результат ещё не
имеет независимого одобрения или whole-feature qualification.

Прямые зависимости: ui_base/ui_layout/ui_interaction. `Description` содержит
immutable pointer-free payload bytes и trusted process-lifetime native callbacks:
pure validate/measure/hit, без live model, clock, renderer, reentry или удержания
заимствованных views. Hit не выделяет память. Это не sandbox/plugin ABI.

`Metrics` передаётся синхронно как userdata для `layout.Layout_Metrics` с
`intrinsic = custom.measure`. Неизвестный ID/невалидный payload/нефинитный размер
отвергается. До prepare final layout уже должен быть решён. `prepare` проверяет
совпадение layout/interaction stamps, structural binding, callbacks и target
ownership (`activation_owner = "custom"` для интерактивного custom узла).
Layout solver и общий interaction owner не создаются вторично.

Candidate владеет копиями payload и строк. `sample_candidate` атомарно проверяет
stamps, полноту/уникальность ID и finite geometry, затем материализует selected
frozen geometry/input gate. `hit` применяет один inverse transform, clip,
availability и pure local predicate. Семантическая activation не вызывает hit.
Нулевые scale/opacity либо закрытый input gate не активируют узел.

`validate_candidate` используется конкретным typed publisher до commit.
`commit` — ownership swap внутри общего validated commit section, не публикация
сама по себе. `State` хранит только selected immutable custom frame.
`try_copy_frame` создаёт owning historical reader; он переживает уничтожение
источника/Publication, но не разрешает dispatch/current snapshot. Каждый frame
и State требуется явно уничтожить (`destroy_frame`/`destroy`), owning assignment
не является копией. Все backing allocations checked; отказ не заменяет state,
не оставляет частичного результата и не включает fallback allocator.

`odin test kit/ui_custom` проверяет payload ownership, local disk hit и transform,
copied reader, чужие ownership claims, stamps/duplicate geometry bindings,
availability и все backing allocation позиции prepare/copy. Эти headless checks
не подтверждают render pixels. `odin test kit/ui_custom/sdl` отдельно проверяет
software circle pixels, renderer state/retained generation/refusals и custom/layered
shields. Реальный display consumer: [content_display](../../tests/ui_content/content_display/README.md).
