# UI Showcase — experimental consumer

Current standalone acquisition/build/test and six selected recipes:
[Odin UI kit](../../README.md). Source command
`bash scripts/test-ui-showcase --portable` preserves source/notice parity.
Historical stage/qualification notes below are not prerequisite reading and do
not independently approve this documentation branch before integration.

В кандидате F5 общий consumer вынесен в `app/`; `main.odin` — тонкий
обычный entrypoint. Model/sections сохраняют прежние каталоги. Тесты consumer
запускаются отдельно: `odin test consumer/ui_showcase/app -collection:ui=kit
-define:UI_SHOWCASE_TEST=true -define:ODIN_TEST_THREADS=1
-extra-linker-flags:"$(pkg-config --libs libpng zlib)"` (SDL/TTF fixtures
требуют последовательного выполнения). Это разделение исходников не включает
debug transport в обычную import closure. Отдельный кандидат
[showcase-v19 tools и CLI](../ui_showcase_tools/README.md) ожидает независимого
ревью и интеграции: ISD profile `ui-showcase-tools`, оба runtime-флага
`--ui-debug --ui-profile showcase-v19`. Обычные `ui-showcase` и minimal-menu
defaults не меняются; accessibility data projections сохраняются.

В этой рабочей ветке добавлен **Integration Lab (`slyx-iv1.4`)** по
[принятым R1/D1](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/docs/specs/slyx-iv1.4/spec.md), поверх основы
`953cd154bb01e3e0a6ab7bf201e34b87a1654458`. Описание Lab ниже относится к
локальному кандидату **до независимого ревью и интеграции**, не к уже поставленной
возможности. Полная обязательная display/native matrix и отдельный осмотр PNG
не заменяются software-тестами или успешной сборкой; AC-007 здесь не объявляется
выполненным. Исходные F3 gallery IDs/metadata и следующие исторические описания
сохраняются; отдельная группа Lab не расширяет frozen manifest `gallery-f479-v1`.

Кандидат `slyx-iv1.3.3` по [R1/D1 и ограниченной D1-A1](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/docs/specs/slyx-iv1.3/spec.md),
до независимого ревью/интеграции. Поверх поставленных F2 (`f479b103…`),
G01–G08 (`6b8ead53…`) и G09–G14 (`85295c3e…`) он добавляет
Composition (G15), Custom (G16), Transitions (G17), Accessibility (G18), World (G19)
и combined Diagnostics/Performance (G20–G21) в одном процессе. Frozen manifest
`gallery-f479-v1` содержит ровно 19 открываемых IDs, experimental status и явные
ограничения. Наличие страниц не заменяет итоговую проверку G/C/AC, независимое
ревью, интеграцию или приёмку фичи. Старые demo hosts, game, test-main, debugger
transport и RIS не импортируются. Обычной сборке не нужны Python или ISD.

Composition: дочерняя кнопка → родитель, Stop, два счётчика, удаление/возврат
дочерней регистрации. Callback записывает bounded intention; один reducer outcome
применяется после routing. Custom: два `ui_composition.compose_panel` с namespaced
title/content/footer, собственными цветами и 72-unit кругами; Style/Footer/Disabled,
popup и неинтерактивная подсказка. Pure circle predicate и SDL Canvas используют
тот же строгий круг; semantic Activate не требует координат. Смена страницы
сохраняет counters/style/slot/disabled, но не popup/tooltip/press. World: A/B/C,
перемещение A/камеры ±64, zoom1/2 и Hide/Clamp/Direction/reset. Viewport использует
исходные logical insets32/160/32/32, card112×48 с 75/100, offset(0,-12), pivot(.5,1),
indicator24×24. Численные placements принадлежат consumer, не renderer/game.

Новые локальные страницы `.3` (не завершённая integrated qualification):

- Transitions: A/B, четыре easing, presence/reduced motion, frozen paint/hit,
  неподвижный marker, sampled progress, slider и hold1000ms в одном publisher.
- Accessibility: исходный pure token reducer с narrow interaction import;
  Hold/Dialog, initial Cancel, thresholds4.5/24 либо7/32, strict assessment,
  отдельные читаемые Warning/Unassessed пояснения, target24 и исходный clipped
  target40×40 с видимой областью20×40, настоящий reduced-motion sample.
  Выбранный Normal/Strict виден на кнопке и в результате Previous capture:
  Normal использует existing common inspection check, Strict дополнительно
  учитывает accessibility Warning. Оба сохраняют обычные действия доступными.
  Common layout diagnostics (включая намеренный clipped-target overflow) могут
  независимо провалить Normal; accessibility Warning сам по себе его не проваливает.
  `coverage=false` при Unassessed не является утверждением соответствия стандарту.
  Текущая owning assessment принадлежит reader; строка Previous capture честно
  показывает предыдущую оценку. Она не авторизует действия.
  C08 явно выбирает style/text/rich/layers/scroll/hold/editor/gestures/custom/transitions
  projections. Дополнительные editor/gesture образцы справа — **только для оценки**,
  не второй интерактивный editor или новый composer. Их реальные candidates,
  rich runs и owning readers относятся к той же geometry/stamp. Rich фиксированного
  размера проходит существующие resource/layout/display stages на единственном
  итоговом layout, без второго solver. Полные интерактивные flows остаются G09/G14.
- Rich Text: C07 совмещает исходную rich card с custom circle и transition.
  Click круга переключает тот же ellipsis control и смещение0/30 за400ms;
  painter/hit используют одну frozen geometry. У этого runtime нет hold owner.
- Diagnostics/Performance: реально совмещены editor и 10000-item collection,
  с отдельными от G09/G11 section models. Кнопки probes вызывают настоящие
  duplicate/invalid/unsupported layout, capture-owner conflict и invalid-font guards.
  Последний bounded diagnostic хранит копию ID и отличает expected/unexpected,
  current-model/historical. Реальный отказ сохраняет stage/code/attempt; после R
  failed attempt остаётся видимым историческим наблюдением, а не current authority.
  On/off управляет consumer CPU phase timers prepare/copy/commit/draw/readback/present;
  недоступные samples помечены available=false, не измеренным нулём.
  Обёртки actual `Text_Layout_Metrics` prepare/editor callbacks считают отдельно
  font metrics/line measure/glyph validation; это не все внутренние font calls
  guards/renderer. Operation counters считают завершённые consumer phase scopes.
  Runtime destroy имеет отдельный sample вокруг настоящего teardown family/readers/
  generations; app models/shared Input и observer shutdown в него не входят.
  `performance_page_test.odin` печатает ru/en × on/off ×3 software наблюдения,
  failure/recovery, tracking totals/peak и native ledger. Observer/IO не включены
  в phase timers; cold/failure/recovery observations вложены и не суммируются.
  Эквивалентные idle rebuild проверяют bounded retained live (decimal timing strings
  меняют длину), а destroy — zero live/bad-frees. Fixed software output отвергает
  несовпадающий drawable; положительный native resize проверяется отдельно через ISD.
  stdout `performance` содержит raw last samples/counters/availability и section
  model; это наблюдение, не transport или release command endpoint. Instrumentation
  off сохраняет сценарий и guards, но метрики недоступны, а не «ускорение до нуля».

Standalone closure явно включает `ui_accessibility/{projection,inspect}`,
`ui_inspect` и обязательные `ui_wire` DTO. Это выбранная data projection,
не debugger/socket, не восстановление umbrella API.

## Независимая сборка

Linux x86_64; Odin `dev-2026-10-nightly:84bc3fc`, SDL3 `3.4.16`,
SDL3_ttf `3.2.2`, libpng `1.6.59`, zlib `1.4` и их shared libraries
(F8 candidate, pending integration/qualification).
Другие платформы не квалифицированы. PNG loader — существующий consumer package,
не зависимость UI core.

```text
proof/
  kit/{ui_base,ui_layout,ui_interaction,ui_style,ui_text,unicode_graphemes,
       ui_layers,ui_scroll,ui_controls,ui_sdl,ui_sdl_text,ui_rich,ui_editor,
       ui_collections,ui_hold,ui_gestures,translations}/
   kit/{ui_custom,ui_composition,ui_world,ui_transitions,ui_inspect,ui_wire}/
   kit/ui_accessibility/{projection,inspect}/
  consumer/ui_showcase/{main.odin,app/*.odin,model/*.odin,sections/*.odin}
  consumer/atlas_catalog/loader/*.odin
  consumer/controls_demo/model/model.odin
  consumer/gestures_demo/model/model.odin
   consumer/virtualized_collections_demo/model/model.odin
   consumer/accessibility_demo/model/model.odin
  resources/{font.ttf,fallback.ttf,atlas/{a,b}/,notices/,font notices}
```

`kit/{ui_controls,ui_rich,ui_editor,ui_collections,ui_hold,ui_gestures}/sdl/`
и `kit/ui_custom/sdl/` также включены. Profiles переиспользует только
существующий pure reducer, не controls demo host. Невыбранные optional families,
`ui_sdl/unported`, test-main и symlinks обратно в Slyx отсутствуют.
Из `proof/consumer/ui_showcase/`:

```sh
odin build . -collection:ui=../../kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:../../showcase
../../showcase --font ../../resources/font.ttf --fallback-font ../../resources/fallback.ttf \
  --assets ../../resources/atlas/a/manifest.json --alternate-assets ../../resources/atlas/b/manifest.json \
  --section rich-text --locale ru --size 1280x960 --scale 1
```

Font предоставляется явно; системного поиска шрифта и абсолютного Slyx-пути нет.
Для локального воспроизведения физического kit и import graph:
`bash scripts/test-ui-showcase`. Скрипт создаёт новый `/tmp/opencode/...` root,
копирует только production Odin sources, supplied fonts/atlas и существующие notices, выполняет
fresh build/check и negative CLI/real invalid-font startup. Unicode License v3
сохраняется в `unicode_graphemes/data/LICENSE.txt`; font notices — рядом с font.
Atlas CC0 notice и codec notices — в `resources/notices/`. Скрипт использует
проверенные `/usr/share/licenses/{libpng,zlib}/LICENSE`; в другой раскладке
передайте точные `LIBPNG_LICENSE`/`ZLIB_LICENSE`, ничего не устанавливая автоматически.
Новой лицензии UI-кода/repository этот пример не выбирает.

CLI: обязательный `--font PATH`; `--section catalogue|FROZEN_ID|LAB_ID`
(default catalogue), `--locale ru|en` (default ru), `--size WIDTHxHEIGHT`
(default 800x600, положительные SDL i32), `--scale 1|1.5|2` (default 1),
`--pixel-perfect` (default Normal). Unknown/duplicate/missing/malformed args
отклоняются до окна; 1.5 + Pixel_Perfect — ошибка, без округления.
Дополнительные параметры: `--fallback-font PATH`, `--assets MANIFEST`,
`--alternate-assets MANIFEST`. Пути относительны cwd. Rich Text требует fallback,
Atlas — явно supplied pack; отсутствие ресурса даёт адресную ошибку входа,
а не замену обязательного примера. Ошибка аргумента, font или partial init даёт
diagnostic и ненулевой exit. Список IDs печатается также при ошибке CLI:
`layout`, `controls`, `profiles`, `styling`, `atlas`, `text`, `rich-text`,
`text-input`, `scroll-table`, `collections`, `layers`, `hud`, `gestures`,
`composition`, `custom`, `transitions`, `accessibility`, `world`, `diagnostics-performance`.
Отдельные Lab IDs: `lab-menu`, `lab-settings`, `lab-hud`, `lab-inventory`.
Они доступны также четырьмя обычными кнопками группы Integration Lab в каталоге;
старые `hud`, `profiles`, `collections`, `gestures` не являются их aliases.
Кнопка Lab/«Лаборатория» открывает эту отдельную группу вместо двух gallery rows;
Gallery/«Галерея» возвращает прежний каталог с сохранённым offset. Это сохраняет
малую F2 layout matrix без добавочной высоты, text shrink или изменения frozen IDs.

## Integration Lab — локальные reference recipes F4

```sh
odin build consumer/ui_showcase -collection:ui=kit -out:/tmp/opencode/showcase
/tmp/opencode/showcase --font resources/font.ttf \
  --section lab-menu --locale ru --size 1280x960 --scale 1
```

Для агентского графического запуска используйте только [обёртку ISD](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/docs/isd.md),
а не прямой запуск из примера команды. Обычному consumer не нужны ISD/Python,
fallback font или atlas для Lab; старые resource requirements других страниц
сохраняются. Это mock app data без импорта `game/`, дискового сохранения или
новой игровой механики.

| Selector | Полный путь и владельцы |
|---|---|
| `lab-menu` | Главное меню → подменю → settings modal → Apply confirmation → возврат. Menu/settings используют один typed runtime, editor и physical Input, а не переключение старых demo hosts. Initial focus — Submenu. |
| `lab-settings` | Прямой вход в тот же settings recipe, возврат в подменю. Initial focus — name field. Draft name/Checkbox/Slider (false, 50; 0…100/1) отдельно от applied. Apply показывает имя и Bool/Integer values; только Confirm применяет одну транзакцию. Decline/верхний Escape сохраняют draft. Empty Apply отказывает с причиной, draft остаётся исправимым; committed single-line Unicode EGC и glyph checks прежние. |
| `lab-hud` | HP60/100, ±10 clamp, HP/hold progress, popup shield и неинтерактивный tooltip. Удержание 1000 ms восстанавливает HP и увеличивает отдельный completion count один раз; release до порога/loss/failure отменяют незавершённое удержание. Initial focus — hold; plain Activate его не обходит. |
| `lab-inventory` | Две независимые uniform List collections, 12 stable-ID именованных карточек, по шесть в контейнере. Up/Down и wheel/reveal позволяют выбрать offscreen item. Selection показывает ID/локализованное имя/источник; отдельная ручка, не row target, владеет Drag. Drop на заголовок другого контейнера только открывает confirmation. Cancel не меняет membership; Confirm переносит существующий ID в конец другого контейнера ровно один раз. Reverse меняет только display order. |

При dirty departure из settings открывается отдельный Discard/Stay dialog.
Stay сохраняет draft, Discard восстанавливает applied и выполняет только
запомненный переход; чистый уход не задаёт вопрос. Shell Catalogue/Layout/Controls
адресуют **намерение ухода settings guard**, не background base activation.
Native и semantic routes сходятся перед этим guard; physical press связан с
текущей publication attempt. Пока открыт Apply/Discard dialog, новое намерение
ухода блокируется. Другие фоновые controls не обходят модальность; Escape всегда
адресует верхний scope. Initial focus верхнего решения — Decline/Stay/Cancel.

Значимые settings/menu route, HP/count, inventory membership/order/selection и
общие locale/scale/mode живут у приложения до выхода. Name draft/applied — checked
owning copies. Pending transfer синхронно копирует borrowed IDs/type/correlation
и удерживает lifetime; проверяются token, inventory revision и исходный контейнер.
Refused/stale/same-container/loss не превращаются в перенос или очередь retry.
Открытие диалога меняет shell revision, не inventory data revision.
Уход/cold reconstruction очищает pending/modal/popup/tooltip/capture/clock, но не
значимую model и не physical latches: удержанному вводу нужны release и новый front.
R восстанавливает surviving decision только того же runtime; после его утраты
решение не реконструируется из historical gesture result. Уже применённые
Apply/Drop/hold outcomes при R не повторяются.

`lab_menu.odin`, `lab_hud.odin`, `lab_inventory.odin`, `lab_input.odin` и
`lab_transfer.odin` — явная consumer composition поверх narrow public kit;
`lab_strings.odin` — статические ru/en resources, semantic IDs/введённое имя не
переводятся. Pure settings/HUD transitions находятся в `model/lab.odin`, membership
переиспользует `gestures_demo/model`, не его host. Один normalizer и общий
layer-ordered interaction обслуживают выбранные owners. Inventory Tab использует
единый logical order двух lists/shell/dialog; wheel/nav направляются ровно в одну
область. Два collection candidates последовательно проецируют offsets в один
text/layout result и связываются с общей final geometry/layers/gestures; ordinary
scroll owner для этих regions отсутствует. Hidden layout nodes не рисуются также
специализированным editor painter. Historical owning readers остаются читаемыми,
но не авторизуют actions.

Поддержка ограничена этими сочетаниями D1: settings layers+controls+editor,
HUD layers+hold, inventory two collections+Drag/Drop+layers. Нет arbitrary family
powerset, row activation+drag owner на одном target, nested scroll, row pan/repeat,
внутри-контейнерного drag-reorder, stacks/equipment/merge/split, multiline editor,
IME/preedit/bidi/shaping или новых public kit APIs. Labels/body могут быть
многострочными, editor остаётся NoWrap/Clip. Базовая читаемость — 1280×960 Normal1
ru/en; Normal1.5/2, Pixel_Perfect1/2 и resize туда-обратно остаются обязательными
применимыми fixtures каждого recipe. Fractional Pixel_Perfect отказывает без
смены предыдущего состояния; tight viewport не разрешает скрыто уменьшить текст.

Lab tests разделены на parser/catalogue, pure transitions, composed native-synthetic
flows и software pixels, lifetime/currentness, stage faults и allocation refusals.
`lab_contract_test.odin` дополнительно проверяет surviving Apply/transfer decisions
при failure/R до и после эффекта, отмену pending при cold lifetime replacement,
held-front barrier, historical action refusal и named preedit/wrong-scope/row-pan
refusals на действующих Lab geometry/family owners. Это software/native-synthetic
проверки, не display evidence или заявление о завершении полного suite.
`lab_render_test.odin` ловит ghost-editor на холодном меню и после закрытия settings.
`lab_lifecycle_test.odin` поочерёдно отказывает backing allocations entry/rebuild/
reader-copy; `lab_mutation_allocation_test.odin` — edit, Apply open/Confirm, Discard,
transfer offer/Confirm/Cancel и selection на том же consumer path. Owning copies
при logical focus/reveal, Drag Begin/Aim, reverse и scale также проходят
через этот allocator harness; это не новый input runner или внешняя среда.
Отказ owning
transition — Not_Ready barrier, не обычная invalidation с неявным rebuild; R не
повторяет intention. Сохранившиеся app values и pending decision проверяются
отдельно от publication; cleanup проверяет zero tracked live/bad-frees и balanced
native ledger. Это не fault injection внутри SDL/TTF/driver и не их heap measurement.

## Управление и состояние

Tab/Shift-Tab — focus; Return/Space, mouse и gamepad South — activation.
Slider: mouse track/drag; keyboard Left/Right/Home/End; gamepad Left/Right.
Начальные controlled значения: Checkbox=false, Toggle=false, Slider=50 (0…100/1).
`[ ]`/`[x]`, числа, подписи и отдельная focus-рамка различимы не только цветом.
На экране общие navigation/language/scale/mode buttons. Недопустимое fractional
Pixel_Perfect явно отклоняется с diagnostic, прежние параметры/values остаются.

Shell хранит values, ru/en и scale/mode до завершения процесса; дисковой записи
нет. Новый вход холодно строит страницу с initial focus: catalogue → Layout,
Layout → Controls, Controls → Checkbox. Внутри-page rebuild сохраняет доступный
stable focus ID. Layout: Row/Column, Stack bottom→top, explicit Grid, Absolute
anchor/pivot и Clip с единственным ожидаемым `Container_Overflow` у
`layout/clipped`; обрезанная часть не hit target. Остальные diagnostics — отказ.

`model/` — pure reducer; `strings.odin` — собственные ru/en; `pages.odin` — typed
composition. `Shell` владеет одним physical `ui_sdl.Input`, model и активным
Runtime по стабильному адресу. Host font source переживает разделы. При уходе
отменяются press/capture, затем уничтожаются reader, adapter/family/resource
owners, Context и Publication. Physical latches не сбрасываются при переходе:
удержанное требует release и нового front. Нет старого кадра как новой model.

Runtime готовит один выбранный text/layout либо rich/layout результат,
interaction/style и для Controls/Profiles — layers/controls metadata; Profiles
добавляет ordinary scroll owner. Затем выполняются owning reader copies и validation.
До enter_commit всё fallible; в commit только ownership moves/commits, затем
finish, reconciliation и destroy старых owners. Profiles демонстрирует
Select/Dropdown, Tabs, List, Dialog и Tooltip через тот же physical input;
layer paint/hit plan сохраняет popup shields. Rich owners/reader выбираются
явным tagged variant; второй solver или normalizer не запускается.
`copy_reader` — checked owning copy, `destroy_reader` — освобождение;
присваивание не копирует ownership. Historical reader может пережить Runtime в
lifetime test, но не разрешает current action/snapshot. Allocator/SDL/renderer
и optional native ledger должны пережить readers.

Один normalize_event перед specialization/точной shell-vs-control маршрутизацией.
Proposal не outcome: reducer принимает checked lifetime/attempt/model/sequence
ровно один раз. После technical/application mutation нужен rebuild.
Смешанные stamps/resources/drawable блокируют actions. Ошибки prepare/resource/
copy/precommit/render/readback/present оставляют ready=false; обычный input и
resize не восстанавливают его. **R** (также физическая клавиша R в ru-раскладке) — независимый host retry принятой model,
без replay перехода/value. Painter идёт по structural paint order с node/text/
focus primitives; readback Surface всегда освобождается до завершения present.

## Страницы G01–G08

Все имеют ru/en baseline 1280×960 Normal1. Каталог листается обычными
Previous/Next; IDs и ограничения process-lifetime, не runtime plugin registry.

| Группа | Fixture и обычные controls |
|---|---|
| G01–G02 | Шесть прежних Layout fixtures; More/Ещё — Fixed/Content/Fill/Percent, min/max, grow/shrink, margin/padding/gap и align/justify. Safe area — физические insets 12/18/12/18. Существующие scale/mode и intentional Clip сохраняются. |
| G03 | Checkbox=false, Toggle=false, Slider=50, 0…100/1; прежние native/semantic paths. |
| G04 | Aurora/Borealis/Cirrus; draft/applied, Apply/Cancel/Reset, dirty departure Apply-and-go/Discard-and-go/Stay. Tabs открывают General/Appearance; Select имеет Cancel до Dialog Cancel; List Up/Down меняет focus/reveal, не selection. Tooltip не принимает ввод; selected markers и disabled reason видимы. |
| G05 | Theme role → named override → local declarations/tokens; Normal/Selected/Hovered/Pressed/Focused/Disabled, отдельная focus-рамка. Rectangle/Rounded/Line/Border/Ellipse/Triangle/Polygon/Image/Panel; Missing image — реальный fallback. |
| G06 | Независимые light/dark и A/B, controlled count/selected/disabled, именованные regions и читаемый pivot из metadata, Stretch/Repeat/omit-center. Reload и R читают файлы; обычный focus/value rebuild удерживает generation. Files_Changed отказывает до commit без blind retry. |
| G07 | `ui:translations`, исходные whole normal/short/probe ru/en строки; WordWrap/Content-height, Clip/Ellipsis/max_lines/alignment и source ranges. Четыре cases: EGC limit отсутствует/0 × probe width Fill/30; EGC warning и pixel overflow независимы. |
| G08 | Исходная whole rich card: bold/italic/underline, size24, inline star/icon U+F500, Greek/∞ fallback, combining acute; wrap/ellipsis и исходные byte mappings. Это не HTML или rich editor. |

Models живут до выхода; transient select/capture/press не восстанавливаются после
ухода. Плотный viewport показывает реальные clips/expected overflow, без скрытого
уменьшения font/scale. Поддержка произвольного powerset families не заявляется;
итоговые C01–C08/full-gallery acceptance остаются отдельной интегрированной проверкой.

Atlas использует один `atlas_catalog/loader`: manifest≤1 MiB, pages≤16,
regions≤4096, PNG≤16 MiB, dimensions≤4096, compressed/decoded sums≤64 MiB;
RGB8/RGBA8 noninterlaced, CRC/order/framing и path/symlink guards не ослаблены.
PNG/deflate не реализуются заново. [Renderer API](../../kit/ui_sdl/README.md)
содержит только разрешённый D1-A1 port; font generations остаются отдельными.

Ledger в host считает primary font и прямые backend generations, включая atlas
pages. Native fonts/inline images rich factory не входят в этот счётчик;
их lifetime проверяют selected adapter tests/retained readers, не объявляя этот
ledger полной SDL/TTF/driver/GPU heap-метрикой. Odin tracking также не является
измерением native heap. Физический gamepad и другие платформы не квалифицированы.

Security reading **2026-11-08**: просмотрены [libpng advisories pages1/2](https://github.com/pnggroup/libpng/security/advisories)
и [zlib release notes](https://zlib.net/). CVE-2026-46675 затрагивает версии libpng
через 1.6.58, но [advisory явно исключает simplified API](https://github.com/pnggroup/libpng/security/advisories/GHSA-qvg3-h654-xq3j),
который использует loader. Новая zlib 1.4 (2026-11-04) содержит security fixes;
выбранный libpng reader не вызывает затронутые gz*/minizip, inflateGetDictionary,
inflateSync, inflatePrime, inflateBack или deflateResetKeep (проверены undefined
symbols установленного `/usr/lib/libpng16.so.16.58.0`). Это ограниченная проверка
применимости опубликованных сообщений, не полный аудит или vulnerability clearance.
Это историческое наблюдение на 1.6.58/1.3.2. F8 candidate по отдельному решению
обновляет pins до 1.6.59/1.4; [новый provenance и regression scope](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/examples/atlas_catalog/README.md)
не заменяют полную F8 qualification и не переписывают F7 evidence.

## Проверки

### G09–G14: дополнительный срез до интеграции

Структурные fixtures находятся в `sections/`; selected runtimes используют
существующие narrow packages, не legacy hosts. Для virtual reducer уникальное
package name `collections_demo_model` устраняет конфликт линковки с соседним
pure reducer. Внешний production-only kit включает оба reducer source folders.

| ID | Поведение и управление |
|---|---|
| G09 | Начальные draft/applied «Алексей», 1–64 EGC при Apply/Enter; пустой draft допустим, пустой Submit отказывает. Escape/Cancel восстанавливает applied, blur ничего не применяет. Ctrl+A/C/X/V, EGC caret/selection/delete, native committed ru/en; отказ clipboard/IME/preedit/вставки виден отдельной строкой. StopTextInput failure сохраняет owner и блокирует дальнейший ввод; только R повторяет cleanup/вход, а при запросе выхода — shutdown. |
| G10 | A/B: 32/33 stable rows, item-05 quantity=99 в B. Три общих Fixed tracks измеряются по всем labels/headers; header не прокручивается. Wheel=три высоты строки, Up/Down без wrap, selected/focus/anchor раздельны. Fixture control: полный/удаление item-05/обратный/3 строки/пусто. Удаление сбрасывает selection; scroll owner выбирает successor, затем predecessor старого порядка. |
| G11 | 10 000 stable IDs; List/Grid, reverse/delete/restore, start/middle/end reveal. height32/gap4/card132/overscan1; final solver geometry связывается с collections candidate, ordinary scroll owner на том же регионе отсутствует. Один logical Tab stop и selected collection adapter; offscreen lookup не придумывает bounds. |
| G12 | Base→A→B, scoped count/hold/ordinary scroll, Checkbox, Cancel policy, popup close/return, noninteractive tooltip. Shell actions блокируются modal guard; R не повторяет count/hold outcome. |
| G13 | HP60/100, ±10 clamp (каждый принятый request имеет revision/effect), Restore1000ms. Progress/counter, early release/loss; plain Activate возвращает Activation_Required. |
| G14 | 12 cards, rows48/viewport192, drag threshold6, frozen preview и typed target. Same_Panel application refusal; mouse/keyboard/gamepad aim/end/cancel. Четыре repeat ±24/delay400/interval100ms и две pan handles без inertia. Встроенный editor имеет отдельный draft/applied и общий normalizer/focus/scroll barrier (C04). |

Значимые name/table/collection/card/count/HP values process-local; transient
press/capture/modal/popup/clock/focus не переживают уход. UI proposal не заменяет
прикладной reducer; bounded sequence/cycle watermarks не являются историей событий.
`interaction_pages_test.odin` проверяет публичные native synthetic flows,
EGC/clipboard/lifecycle, bounded lookup/reveal, selected stamps, scoped layers,
999+1/release/loss, 5/6 threshold, Drop/Same_Panel, repeat/pan/gamepad и preview
readback. `interaction_allocation_test.odin` поочерёдно отказывает каждому
наблюдаемому Odin allocation entry/rebuild/reader-copy шести страниц и insertion
G09; compact G11 failure fixture содержит 3 ID (happy-path остаётся 10 000).
Исторические owners сохраняются, допускается только скопированный diagnostic ID;
cleanup проверяет tracked bytes/bad-frees и native ledger. Это не инъекция внутрь SDL.

`python3 -B scripts/test-ui-showcase-interaction-live.py --isd /path/to/checked/isd` запускает свежие
ISD ru/en baseline1280×960 и native fixtures G09–G14, сохраняет captures.json,
source hashes, PNG и logs в `/tmp/opencode/iv132-display-*`. Это не автоматическое
визуальное одобрение: `inspected=false` до отдельного осмотра. Native ru/us ввод
использует существующие публичные ISD layout/keycode операции, до launch
выбирается ru/us, physical38 даёт `ф`/`a`. Wrapper разрешает `--keyboard-layout`
только для editor sections text-input/gestures/diagnostics-performance и прежних editor/performance profiles.
Выбранный ISD должен поддерживать native ru/us input и полную linux-abstract-v1 isolation policy. Его установка/обновление не выполняется UI kit автоматически. PNG и stdout observations не атомарны.
Физический gamepad не квалифицирован. C03 preliminary regression остаётся
`tests/ui_content/collection_input`; final combined visible/performance C03/G21
принадлежит `.3`. Общая all-page acceptance здесь не утверждается.

```sh
odin test consumer/ui_showcase/model -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon -out:/tmp/opencode/showcase-model-tests
odin test consumer/ui_showcase/app -collection:ui=kit -define:UI_SHOWCASE_TEST=true -define:ODIN_TEST_THREADS=1 -vet -vet-style -vet-tabs -vet-semicolon -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:/tmp/opencode/showcase-tests
odin check consumer/ui_showcase -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon
odin build consumer/ui_showcase -collection:ui=kit -out:/tmp/opencode/showcase
python3 -B scripts/test-slyx-isd.py
bash scripts/test-ui-showcase
```

Tests разделяют parser/reducer, exact geometry/hit/clip, native synthetic events,
software render, test-only stage faults, historical readers, 64 cold round trips,
stable live bytes и native ledgers. Refusal coverage ограничена явными сценариями:

- `every_observed_owning_allocation_refusal`: Catalogue/Layout/Controls/Profiles,
  init/rebuild/copy/scale прежнего harness;
- `g05_g08_every_reader_allocation_refusal_preserves_current_source`: owning reader
  copy для Styling/Atlas/Text/Rich Text, не замена проверке init/prepare;
- `g05_g08_consumer_init_prepare_scale_and_atlas_replacement_allocation_refusals`:
  для этих четырёх страниц — consumer init, первый rebuild, rebuild после обычного
  model action и scale 1→1.5; для Atlas дополнительно A→B и explicit Reload.
  Используются реальные supplied primary/fallback/atlas ресурсы и 1280×960.
  Fault allocator установлен до создания всех owners; каждый allocation request
  успешного сценария по очереди получает отказ. Проверяются cleanup кандидата,
  сохранность исторических live owners/readers, Not_Ready, R без model replay,
  нулевые tracked live/bad-frees и balanced native ledger после destroy.

Это не exhaustive powerset всех значений/языков/страниц/путей отказа и не инъекция
отказов внутрь SDL/TTF/libpng. Odin allocator не измеряет SDL/TTF/driver heap;
ledger считает retained native handles, не RSS. Нет числового SLA или обещания
нулевой цены. Применимые package/selected-input/standalone-menu oracles сохраняются.

Настоящий display проверяется **только через ISD**:

```sh
python3 -B scripts/ui_isd.py start --profile ui-showcase --font resources/font.ttf \
  --fallback-font resources/fallback.ttf \
  --assets resources/atlas/a/manifest.json \
  --alternate-assets resources/atlas/b/manifest.json \
  --section profiles --locale ru --size 1280x960 --scale 1 --test-controls
# RUN — точный run ответа; focus явно, input/PNG только своему run.
python3 -B scripts/ui_isd.py focus "$RUN"
python3 -B scripts/ui_isd.py screenshot "$RUN" --output "$RUN/controls.png"
python3 -B scripts/ui_isd.py key "$RUN" tap F12
python3 -B scripts/ui_isd.py stop "$RUN"
```

Stop обязателен в finally, включая ошибку; изоляционный отказ не допускает
main-display fallback. `check --profile ui-showcase --font FILE` использует
явную test-сборку и graceful F12, не добавляет release `--window-check`.
Только test build `UI_SHOWCASE_TEST=true` + `--test-controls`: F1 next entry fault,
F2–F5 prepare/resource/copy/precommit; F6–F8 render/readback/present; F10 настоящий
resize 960×720 ↔ 800×600; F12 normal exit. Release отвергает `--test-controls`;
нет socket, setters или нового automation/debug API.

`python3 -B scripts/test-ui-showcase-live.py --proof <напечатанный proof root>`
сохраняет F2 ru/en × 800×600/960×720 × Normal 1/1.5/2, Pixel_Perfect 1/2,
плюс исторический default subset: baseline первых семи страниц/каталога,
metadata traversal, native profile/
style/atlas/text/rich controls, resize и fault/R/no-replay. `--f2-only` и
`--gallery-only` выбирают эти независимые части существующего harness.
Полный baseline всех 19 страниц и каталога для текущей задачи:
`python3 -B scripts/test-ui-showcase-live.py --proof <proof root>
--gallery-only --full-gallery --baseline-only`. Page-specific native/critical
сценарии проверяются отдельно; baseline не заменяет их.
`captures.json`, sources/environment и per-run logs связывают PNG с fixture,
состоянием, drawable, scale, resources и временем. Каждый normal start
останавливается в finally; PNG и logs сохраняются, каждый PNG нужно осмотреть.
Software/native synthetic evidence не заменяет display; ISD не квалифицирует
физический hardware gamepad. Задача `.3` владеет полной галереей G01–G21/C01–C08;
F5/F6/F7/F8 остаются вне её области. Эти команды не означают независимого
одобрения, feature acceptance или публикации.
