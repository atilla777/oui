# SDL3_ttf backend — experimental

Реализация `slyx-iv1.1.5`. Прямые зависимости:
`ui_sdl`, `ui_text`, `ui_style`, `ui_base`, SDL3/SDL3_ttf.
Они следуют выбранному text closure; optional UI families и tools отсутствуют.

`create_generation(renderer,revision,[]Font_Source,scale,allocator,ledger=nil)`
создаёт owning immutable font generation. Source содержит собственные
`id,size,data`; bytes заимствуются только на вызов и клонируются. Generation
владеет bytes, font handles, ID и revision strings. Отказ любого clone/open
закрывает частично открытые fonts/streams. Ошибки — `ui_sdl.Error`, ID заимствует
входной source. Font bytes не загружаются библиотекой из Slyx или системного пути.
SDL/TTF init, renderer и allocator — зависимости caller, живут дольше всех readers.

`retain_generation`/`release_generation` имеют checked refcount и move-only
ownership convention, как image backend. Если включён borrowed Resource_Ledger,
он также живёт дольше всех readers и считает только retained fonts. Размер его
pointer — цена выбранного backend, внешний ledger — observer bookkeeping.

`metrics(g)` даёт borrowed синхронные `ui_text.Text_Layout_Metrics`:
glyph validation ru/en, font metrics/native revision и line measurement.
Пустой substring не передаётся в TTF как NUL-terminated string. Неподдержанный
font ID/size или изменённый native font generation отклоняется. Это не shaping,
bidi или новый Unicode scanner; подготовкой owning текста владеет `ui_text`.

`matches(g,&text_frame,&style_frame)` проверяет stamps, drawable/scale,
font bindings/revisions, ascent/line advance и реальные measured line extents.
`render` сначала делает этот preflight, затем рисует только frozen displayed
lines в их clips, проверяет surface dimensions и восстанавливает renderer state.
Он не очищает primitives, не делает readback/present и не разрешает current UI
действие. Временные SDL surface/texture для каждой строки освобождаются на любом
исходе; persistent glyph cache и накопление locale history не добавлены.

Сначала `ui_sdl.render` для primitives/images, затем этот `render`, readback,
present. Полный checked publisher/owning reader и host recovery находятся в
[`standalone_menu`](../../consumer/standalone_menu/README.md).

Кандидат `slyx-iv1.1.2`: `render_node(g,&text_frame,&style_frame,id,transform)` использует
тот же preflight и painter только для text block выбранного node. Не очищает
target, сохраняет renderer state; неизвестный/пустой ID отклоняется. Это шов для
явного layer order, не автоматический layer runtime или transition renderer.
Optional transform по умолчанию `{scale=1,opacity=1}` — готовая численная
Frozen_Geometry: finite positive scale/finite offset масштабируют destination,
opacity [0,1] умножает text alpha. Measured metrics остаются logical, style clip
уже sampled. Reader не меняется; никакого clock/transition solver. Пример и
проверки — [selected composed render](../../tests/ui_navigation/selected_input/RENDER.md).

```sh
odin test kit/ui_sdl_text -define:ODIN_TEST_THREADS=1 -vet -vet-style -vet-tabs -vet-semicolon -out:<fresh-tests>
```

Тест использует отдельно разрешённый repository font fixture по явному test path;
это не build/runtime dependency обычного consumer. Версии: Odin
`dev-2026-10-nightly:84bc3fc`, SDL3 `3.4.16`, SDL3_ttf `3.2.2`, Linux x86_64.
