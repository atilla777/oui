# Vertical scrolling — experimental headless API

`import scroll "ui:ui_scroll"`, `-collection:ui=<kit-root>`; kit-root в этом
репозитории — `kit/`. Прямые UI-зависимости только `ui_base`, `ui_layout`,
`ui_interaction`. Нет text/Unicode/style/layers/controls/hold/SDL/tools imports,
device owner, clock, backend resources или собственных registrations.

Это headless-часть кандидата `slyx-iv1.1.2`, до интеграции и независимого ревью;
не завершение всей задачи/F1. Основа — исходные R1/D1 и R1-A1/D1-A1 по
[сохранённым решениям](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/docs/specs/slyx-iv1.1/spec.md).

## Описание, геометрия и единственный focus owner

`Description{id,content_id}` явно выбирает viewport. Его единственный прямой
ребёнок — natural-height Column content (`y=Content`, без grow/shrink).
Вертикальные Fill/Percent внутри content, вложенные scroll regions и повторные
bindings отклоняются `Invalid_Scroll`. Горизонтальная прокрутка не добавлена.
Layout сохраняет обычные structural kinds: нового обязательного Scroll kind
или состояния в `layout.Node` нет. В общий interaction как targets передаются
интерактивные items. Viewport может остаться structural/non-interactive:
его frozen enabled/visible/modal gate разрешает scrolling, но не добавляет
focus/activation target. Если приложение явно задаёт для него semantic target,
его обычная доступность также учитывается.

`prepare(&state,&layout_candidate,&interaction_candidate,descriptions,allocator,
focus_id="") -> (Candidate,Error)` заимствует входы только синхронно, проверяет
общий stamp и создаёт **две** owning проекции: `candidate.geometry` и
`candidate.frame`. Исходная geometry не меняется. Content переводится на offset;
clips пересчитываются от предков, не из уже обрезанных прямоугольников. Естественный
вертикальный overflow viewport/content не выдаётся за layout defect; независимый
горизонтальный overflow сохраняется. Нулевой viewport не принимает hit и сохраняет
диагностику переполнения; oversized item при reveal выравнивается по своему верху.

`Frame.regions` хранит viewport/extent/offset/max_offset, visible items и
anchor/intra_offset. При reorder сохраняется stable anchor плюс partial offset.
`find(&frame,id)` возвращает borrowed region; `item_index(region,id,available=false)`
возвращает индекс либо -1. Эти views не переживают соответствующий frame.
Если ID исчез, ищется successor, затем predecessor в **старом** порядке, а не
позиция в новом массиве. Focus fallback применяет тот же поиск только среди
доступных items. Нет wrap или скрытой памяти исчезнувших ID. Обычный rebuild не
прокручивает автоматически к уже имеющемуся focus: сохраняется anchor.

`candidate.has_focus/focus_id` — предложение технической reconciliation, не
второй focus manager; строка заимствует owning candidate.frame. Передайте текущий
focus из единственного `interaction.Context` в prepare. При композиции с layers
явный modal entry/return имеет приоритет над обычной scroll reconciliation.

## Действия, публикация и отказ

`create(allocator)` / `destroy(&state)` владеют live metadata и клонированным
pending action ID. `dispatch(&state,&interaction,Action)` использует общие
readiness/source/availability guards **до** проверки delta, не применяет модель
приложения и не создаёт activation sequence:

- `Scroll_By`: finite delta по viewport ID, clamp при prepare;
- `Move_Item`: из общего текущего focus к доступному соседу без wrap;
- `Focus`: item ID, focus и reveal только при следующем successful publication;
- `Reveal_Item`: item ID, reveal без присвоения focus.

Focus вне scroll и обычные Navigate/Activate принадлежат общему interaction
dispatcher; layer Cancel — выбранному layers dispatcher. Это не копии их
алгоритмов. За focus+reveal scroll item используйте этот `Focus`, а не попытку
второго dispatch после того, как readiness уже выключена.

Accepted action клонирует ID, увеличивает checked technical version и выключает
ready. Пока rebuild не завершён, следующий action получает `Not_Ready`.
Prepare/failure не потребляют pending action. Новая frozen недоступность
отклоняет старое pending изменение; successful commit очищает его один раз.
Отказ allocator оставляет live owners/version/pending неизменными; fallback нет.
Переполнение technical version даёт `Exhausted`, не wrap.

Typed publisher выполняет `base.begin_attempt`, один layout solver, scroll
prepare, затем final interaction.prepare по **candidate.geometry**. Перед commit
проверяет `validate_candidate(&publication,&state,&candidate)` и остальные выбранные
owners, создаёт fallible reader copies, повторно проверяет guards, входит в
`base.enter_commit`. Wrong publication/State/attempt/version отклоняются.
Candidate не переживает свой live State; после destroy/recreate runtime нужна
новая publication/attempt association, не повторное использование candidate.

В infallible секции publisher переносит final interaction, связывает выбранный
focus через `interaction.retained_id(&ctx.frame,candidate.focus_id)`, вызывает
`scroll.commit`, затем `base.finish_commit`. Registration reconciliation/dispose
вызывается **после** согласованной публикации, не в prepare. Порядок показан в
[`scroll_only`](../../tests/ui_navigation/scroll_only/main.odin) и
`reconciliation_test.odin`. `scroll.commit` потребляет candidate и освобождает
его geometry: если она нужна renderer/reader, до commit перенесите её в свой
owning bundle и обнулите источник. Одно владение нельзя присвоить двум owners.

При любой ошибке typed host уничтожает candidates и оставляет ready=false;
старый frame остаётся историческим. Он не повторяет application reducer/edge.
Scroll сам не управляет временем hold и не отменяет чужие clocks: это обязанности
явно выбранной композиции и соответствующего владельца.

## Readers, hit и ошибки

`try_copy_frame(&frame,allocator) -> (Frame,bool)` независимо клонирует все
region/item/anchor IDs и удерживает общий stamp. Reader переживает уничтожение
State, исходной geometry и publication; allocator должен жить дольше reader.
Для общей geometry копируйте `layout.Frame` отдельно. Historical reader не
разрешает dispatch/current snapshot. Освобождение — `destroy_frame`,
`destroy_candidate`; обычное присваивание не является copy/retain.

`hit_test(&frame,&geometry,&interaction,drawable_x,drawable_y,view={})` проверяет
stamps, общий effective gate и half-open viewport clip. Опциональный синхронный
`base.Geometry_View` заменяет identity clip выбранным frozen content_clip;
невидимый/non-invertible/input-disabled projection не принимает ввод.
View не сохраняется. Layer popup shields/order проверяются выбранной layers
композицией **до** scroll handling; scroll не импортирует layers и не обходит их
shield самостоятельно. Transitions solver здесь отсутствует.

`Error.id` заимствует input ID, никогда уничтоженный candidate. Для сохранения:
`base.try_copy_error(scroll.describe_error(error),allocator)` и
`base.destroy_error`. Family — Scroll, default stage — Prepare; code сохраняет
`Error_Code`. Copy отказ возвращает false, пустой output и нулевые partial owners.

## Проверки, границы и стоимость

```sh
odin test kit/ui_scroll -vet -vet-style -vet-tabs -vet-semicolon -out:<fresh-tests>
odin build tests/ui_navigation/scroll_only -collection:ui=kit -show-import-graph -out:<fresh-fixture>
```

Применимые прежние oracle из исторического `kit/ui/scroll_test.odin` перенесены
в package tests: anchor/focus old order, partial insertion, non-wrap, pending
retry once, stale/foreign candidate, common guard priority, unsupported modes,
clips/diagnostics, registration dispose после commit и owning readers. Физические
native/SDL pixel/layer-combination проверки остаются отдельным следующим вкладом,
не выдаются за headless результат. Прежняя headless реализация
`kit/ui/scroll.odin` удалена; старый несовместимый API не восстанавливается,
оставшиеся historical tests/consumers не являются второй рабочей библиотекой.

На Linux x86_64, Odin `dev-2026-10-nightly:84bc3fc`, Normal scale=1, 4 nodes,
locale=none, без backend: standalone fixture наблюдал cumulative allocations /
bytes / live / peak: init `1/32/32/32`, scroll published `61/7925/896/6677`,
rebuild+reader `128/16028/1105/7542`, destroy `128/16028/0/7542`.
Static sizes: State=144, Frame=64, Candidate=248 bytes; общий Publication=72,
interaction Context=216. Эти cumulative цифры включают layout/interaction,
copy/stamp/ID bookkeeping и fixture, не только scroll. Отдельный refusal fixture
перебирает 18 prepare и 7 copy backing allocation позиций; live после cleanup=0,
peak=3157 bytes. Проверены dispatch allocation rollback и 64 стабильных rebuild.
Handlers/backend resources scroll=0; SDL/driver/GPU memory не измерялись.
Отключённая семья отсутствует физически в foundation-only kit и не имеет полей
в общем Context. Это structural отсутствие, не RSS subtraction или SLA.
