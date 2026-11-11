# Common inspector — experimental, opt-in

Кандидат `slyx-iv1.1.6`, до ревью/интеграции. Полные imports, ownership, closures,
ограничения, old-wire mapping и команды: [UI_TOOLS](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/libs/UI_TOOLS.md).

```odin
import inspect "ui:ui_inspect"
// geometry и targets принадлежат одному frozen published bundle.
i, error := inspect.capture({
    frame=&geometry, interaction=&targets,
    ready=current_ready, model_revision=model_revision,
    published_revision=geometry.stamp.model_revision,
    focus_id=published_focus, hover_id=published_hover, pressed_id=published_press,
    semantics=semantics, diagnostics=normalized_diagnostics, capabilities=capabilities,
}, allocator)
if error == .None {
    defer inspect.destroy_inspection(&i)
    view, query_error := inspect.inspect(&i, "button")
    // view/children/strings borrow i, not the source Context.
}
```

`find` поддерживает ID/Role/Name exact queries; возвращённый outer slice освобождает
caller своим allocator. `Node_View` содержит только common geometry/target/state
и semantic metadata. `action_status` — наблюдение, не dispatch или app outcome.
Family-specific assertions/statuses и typed views подключаются отдельными imports:
`ui_hold/inspect`, `ui_rich/inspect` и т. п. Они не являются полями common reader.

Все retained bytes копируются checked allocations; отказ даёт Allocation без
частичного reader. Stamp/revision/semantic mismatch даёт Metadata_Mismatch.
`strict_result` не считает historical/not-ready observation успешной.
Family diagnostic normalizers имеют собственный cleanup; common capture копирует
их строки. Исходные extended-family tests в `unported/` — historical API oracles.
