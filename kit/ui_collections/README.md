# ui_collections — experimental

До интеграции `slyx-iv1.1.4`. [API, ownership, selected input и migration](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/libs/UI_CONTENT.md).
Headless closure: ui_base/ui_layout/ui_interaction/ui_scroll. Нет controls, editor,
Unicode, text или SDL. SDL input adapter выбирается отдельно как `ui_collections/sdl`.

`prepare → materialize → layout.prepare → project_layout → interaction.prepare →
bind_candidate → validate_candidate → общий commit` — один owning путь.
Не устанавливайте ordinary scroll State для virtual region. Для состава нескольких
regions вызовите `validate_regions`; nested/duplicate ownership отвергается.
Offscreen focus — pending logical action до нового bound frame, не focus несуществующего
target. Один logical Tab stop; App владеет selected item и data revision.
`try_copy_frame` удерживает immutable metadata и глубоко копирует owned nodes.
`destroy`/`destroy_frame`/`destroy_candidate` обязательны; errors/views borrowed.

Команды: `odin test kit/ui_collections` и
`odin test tests/ui_content/collection_input -collection:ui=kit`.
