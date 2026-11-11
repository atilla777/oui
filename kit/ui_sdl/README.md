# SDL3 backend — experimental

Content/visual candidate `.4`: [family SDL adapters и migration](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/libs/UI_CONTENT.md).
Rich fonts/render и custom Canvas больше не реализуются в `unported/`; используйте
`ui_rich/sdl` и `ui_custom/sdl`. Core backend не импортирует эти optional families.

Реализация `slyx-iv1.1.5`. Основание: R1/D1 и принятые
R1-A1/D1-A1 [F1](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/docs/specs/slyx-iv1.1/spec.md).

`import backend "ui:ui_sdl"`, `-collection:ui=<kit-root>`. Прямые зависимости:
`ui_base`, `ui_interaction`, `ui_style`, SDL3; layout приходит через foundation.
В этом пакете **нет** TTF, Unicode, text, controls, layers, editor, rich, custom,
gestures, transitions или инструментов. Шрифты — отдельный
[`ui_sdl_text`](../ui_sdl_text/README.md). Нет umbrella import.

## Ввод

Приложение хранит один `Input`, задаёт `window_id`, вызывает
`input_event(&input,&interaction,event,window_extent)` ровно один раз на SDL event.
Результат содержит `dispatch` (общее UI-намерение, не application outcome) и
`consumed`. SDL window coordinates переводятся в drawable pixels;
`interaction.hit_test` выполняет единственный переход в logical coordinates.

Tab/Shift-Tab — navigation, Return/Space — activation, Escape — common Cancel
(без выбранного семейства он отклоняется). Gamepad South/DPAD/East/Back используют
те же guards; South/East/Back учитывают down/up edges, keyboard repeat игнорируется.
Pointer down атомарно запрашивает focus+press через
`interaction.begin_pointer_press`; release потребляет capture один раз.
На применимых window/device loss capture отменяется даже при `ready=false`.
`close_input` закрывает только собственный gamepad; window/renderer принадлежат host.

После технической мутации либо application outcome нужен rebuild до следующего
действия. Ошибка не разрешает input против historical frame. Сам normalizer не
перестраивает модель и не вызывает reducer. Полная композиция показана в
[`standalone_menu`](../../consumer/standalone_menu/README.md).

### Разделённый ввод — кандидат `slyx-iv1.1.2` до интеграции

Дополнение candidate `slyx-iv1.1.3`: matching-window `TEXT_INPUT`/`TEXT_EDITING`
передаются выбранному [editor adapter](../ui_editor/sdl/README.md); shared latches
включают Backspace/Delete, A/C/V/X и keypad Enter. Это не обязательный editor
import/init в backend. [Gesture adapter](../ui_gestures/sdl/README.md) заимствует
тот же normalizer; [combined consumer](../../tests/ui_editing/selected_input/README.md)
показывает specialized path без второго device owner.

`input_event` сохраняется как обычный single-call путь меню. Он вызывает:

1. `normalize_event(&input,&interaction,event,window_extent)` ровно один раз;
2. `dispatch_input(&interaction,normalized)` для обычной обработки.

В явно собранном family bundle между этими стадиями выполняется выбранная
специализация. Если она потребила событие, `dispatch_input` не вызывается.
Нельзя дополнительно вызвать `input_event` для уже нормализованного события.
Семейства заимствуют тот же `Input`, не открывают gamepad повторно и не хранят
второй набор общих физических edges. Их собственные clocks/captures — отдельное
техническое состояние, не второй SDL owner.

`Normalized_Input` — синхронное значение с исходным SDL event, признаками
`accepted`, `down`, `front`, `suspended`, `loss`, drawable `x/y` и
`pointer_valid`. Координаты motion/button/wheel переводятся один раз;
`pointer_valid=false` запрещает использовать `x/y` для hit-testing. `accepted`
означает подходящее окно/устройство, а не разрешение UI-действия. Проверки ready
и доступности остаются обязательными. Action ID заимствует current interaction
frame: значение не сохраняют через rebuild/destroy, не проигрывают повторно.

Общие physical/loss cleanup выполняются при нормализации. Hover/hit observation,
активация, navigation и приобретение pointer press — после выбранной
специализации, не раньше её layer shields. Обычный `dispatch_input` выполняет
pointer observation для не потреблённого motion.
Loss обслуживается и при `ready=false`, поэтому семейство не должно пропускать
нормализацию во время неготовности. `front` различает новый keyboard/pointer
down и повтор удерживаемой кнопки; Return/Space/Escape/Tab/стрелки учитываются
одним общим bit set. DPAD также имеет один shared front/release учёт.
Window loss не переоружает ещё удерживаемое подтверждение; matching release
обслуживается и при suspension. Hidden и unfocused не отменяют друг друга:
focus gain не разрешает ввод в ещё скрытом окне. Обычный menu wrapper остаётся
single-call; это не заявление о готовности всех family adapters.


Проверки нового шва находятся в `input_composition_test.odin`; применяются
также прежние backend и standalone-menu tests. Перенос navigation/control
семейств этим разделом не объявляется завершённым.

## Ресурсы и рисование

### Atlas port D1-A1 — кандидат slyx-iv1.3.1 до интеграции

Ограниченная [поправка дизайна](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/docs/specs/slyx-iv1.3/spec.md#ограниченная-поправка-дизайна-d1-a1-перенос-atlas-backend)
разрешает перенести существующий page/region binding и painter без новых возможностей:

`create_atlas_generation(renderer, ui_style.Atlas_Catalog, []Decoded_Atlas_Page,
allocator, ledger=nil) -> (^Generation, Error)`. `Decoded_Atlas_Page` содержит
`page_id`, `width/height:i32`, tightly packed `pixels:[]u8`, borrowed на вызов.
Число/IDs/размеры страниц должны совпадать с metadata; дубликаты/invalid atlas
отвергаются. Generation клонирует revision/region IDs/page IDs/rect/pivot/nine-slice,
удерживает одну SDL texture на страницу, не разрезает region в отдельные textures.
Font/TTF, files/PNG и consumer reducer в backend не добавляются.

`generation_matches` разрешает image по region ID и проверяет metadata; painter
смещает прежние region-local source patches на начало rect в page. Прежние
Stretch/Repeat/remainder/omit-center/no-neighbor-bleed oracles сохранены в
`atlas_test.odin`. Повторное retention/release и частичный allocation refusal
освобождают native page textures ровно один раз; `ledger` учитывает реальные
page acquisitions/releases. Input pixels/metadata можно освободить после factory.
Renderer/allocator/ledger должны пережить всех readers. Поля `atlas_pages`/
`atlas_regions` — owning storage backend, не разрешение caller менять handles.
Старые combined Asset_Generation/font/publication facades не восстанавливаются.

`create_generation(renderer,revision,images,allocator,ledger=nil)` возвращает
`(^Generation, Error)`. `RGBA_Image` заимствует плотно упакованные RGBA bytes
только на вызов. Generation владеет клонированными ID/revision и SDL textures;
исходные pixels можно изменить/освободить после создания. Image metadata и
9-slice patches принадлежат `ui_style`; PNG decoder здесь отсутствует.

При отказе allocator возвращается `Allocation`, при отказе SDL — `Resource`,
некорректные/повторные ID или dimensions — `Invalid`. `Error.id` заимствует
**входной** ID, не освобождённый generation. Для длительного сохранения ошибку/ID
копирует caller. Никакого fallback allocator или частичного success.

`retain_generation(g)->bool` проверяет переполнение; каждый успешный retain имеет
один `release_generation(&g)`, который обнуляет переменную. Простое присваивание
не создаёт ownership. Renderer и allocator живут дольше всех retained readers.
UI-thread only; поля generation не являются API для изменения handles/revision.

`render(g,&style_frame)->bool` проверяет revision, image metadata и drawable size;
рисует существующие primitives/images/focus projection без TTF. Оно не вызывает
present. Исторический owning frame может рисоваться, но не даёт current snapshot.
`readback(renderer,drawable)->(owning Surface,bool)` выполняется после render и
до `SDL_RenderPresent`; caller уничтожает Surface. Host связывает три стадии с
одним immutable reader/stamp, проверяет current publication и на любом отказе
вызывает `base.invalidate`/отменяет capture. Сам backend не владеет publication.

Кандидат `slyx-iv1.1.2`: `paint_node(g,&style_frame,id,focus=false,opacity=1)` использует
тот же painter и matching, но не очищает target и рисует только выбранный node.
При `focus=true` выполняется только его focus command. Вызов сохраняет renderer
state; он не делает readback/present. Порядок node/text/scrim/focus выбирает
явный family composition, не backend. Отсутствующий ID отклоняется.
Per-draw opacity finite в [0,1] умножает primitive/focus/fallback alpha и прежний
texture alpha; image modulation восстанавливается, reader не меняется. Выбранный
[composed renderer](../../tests/ui_navigation/selected_input/RENDER.md) исполняет
layer node/text/scrim/focus plan; это не новый backend registry.

Renderer clip/viewport/logical presentation/scale/color scale/blend/draw color
сохраняются и восстанавливаются, в том числе после ошибки. Render target не
переключается. `save_renderer_state`, `pixel_coordinates`,
`restore_renderer_state` — синхронные helpers для выбранного font/family backend;
каждый успешный save должен иметь restore, результат restore проверяется отдельно.

Необязательный `Resource_Ledger` считает created/destroyed/live/peak **textures**,
не driver memory. Он заимствован до последнего release; держите его вне runtime,
если readers переживают runtime. Не изменяйте ledger, пока он используется.
Один retained handle не создаёт новую texture. Шрифты ведут отдельный ledger.
Временные текстовые surfaces/textures освобождаются внутри font renderer, а не
входят в retained-image ledger. SDL/TTF heap и GPU bytes не измеряются Odin allocator.

## Миграция и проверки

Прежние общие SDL algorithms перенесены/адаптированы здесь и в `ui_sdl_text`;
старые `Adapter`/`Styled_Pair`/смешанный `Asset_Generation` удалены. Совместимого
facade нет. Неперенесённые optional-family исходники и их старые oracle сохранены
без переписывания в [`unported/`](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/libs/ui_sdl/unported/README.md), **вне активного пакета**.
Они уже зависели от удалённого API foundation; это не поддерживаемый второй
монолит. Старые consumers не восстанавливаются согласно принятой поправке.

```sh
odin test kit/ui_sdl -define:ODIN_TEST_THREADS=1 -vet -vet-style -vet-tabs -vet-semicolon -out:<fresh-tests>
odin build tests/ui_backend/primitive_only -collection:ui=kit -show-import-graph -out:<fresh-fixture>
```

Software fixture проверяет точные red/background pixels, readback/present,
allocation accounting и отсутствие TTF/text closure. Это не реальный дисплей.
Реальные ru/en/menu/resize проверки описаны в consumer README.
