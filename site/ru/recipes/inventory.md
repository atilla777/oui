# Рецепт инвентаря {#inventory-recipe}

Ограниченный рецепт инвентаря — headless-программа на Odin: `tests/ui_recipes/inventory/main.odin` публикует две неналоженные однородные списочные области и одну цепочку drag-жеста в одной публикации. Он готовит и материализует обе коллекции, проецирует их через общий layout, связывает один layers candidate и один gestures candidate, копирует всех readers до commit barrier и уничтожает readers и состояния в конце. Окно не открывается, шрифт не загружается, event loop и renderer отсутствуют.

Это не экран Integration Lab. `lab-inventory` в Lab добавляет к тому же решению приложения видимую строку выбора, модальное подтверждение переноса с «Отмена» и «Подтвердить», локализованные сообщения статуса и переключатель порядка показа. У более широкого примера есть своя страница [Инвентарь лаборатории](../lab/inventory). Список зависимостей ниже относится только к `tests/ui_recipes/inventory`.

## Границы зависимостей {#dependencies}

Fixture напрямую импортирует `ui_base`, `ui_layout`, `ui_interaction`, `ui_layers`, `ui_collections`(+`/sdl`), `ui_gestures`(+`/sdl`), `ui_text` и `ui_sdl_text`. Выбранные SDL-адаптеры подключают `ui_sdl`, а транзитивное замыкание добавляет `ui_style`, `ui_scroll` и `unicode_graphemes`.

| Импорт | Роль в этом рецепте |
| --- | --- |
| `ui_base` | Примитивы publication, ошибки, commit barrier и frame stamps. |
| `ui_layout` | Подготовка и проверка узлов, текста и геометрии. |
| `ui_interaction` | Targets, capture claims, focus и routing. |
| `ui_style` | Транзитивно через `ui_text` и `ui_sdl_text`; метаданные отрисовки. |
| `ui_text` | Детерминированная headless-подготовка текста и измеренная компоновка. |
| `ui_sdl` | Выбранный backend SDL3, достигаемый через SDL-адаптеры коллекций и жестов; компилируется, но окно и event loop не запускаются. |
| `ui_sdl_text` | Адаптер шрифтов и текста SDL3_ttf; компилируется, шрифт не загружается. |
| `ui_scroll` | Транзитивно через collections и gestures; один владелец смещения на область. |
| `ui_collections` | Два описания однородных списков, материализация, устойчивые ID и выбор. |
| `ui_collections/sdl` | SDL-адаптер ввода коллекций; упоминается, но физическим вводом здесь не управляется. |
| `ui_gestures` | Drag source, drop targets, Begin/Aim/End и ограниченное proposal. |
| `ui_gestures/sdl` | SDL-адаптер ввода жестов; упоминается, но физическим вводом здесь не управляется. |
| `unicode_graphemes` | Транзитивно через `ui_text`; сегментация расширенных графемных кластеров. |

Другие семейства UI не нужны: рецепт не импортирует `ui_controls`, `ui_editor`, `ui_hold`, `ui_rich`, `ui_custom`, `ui_composition`, `ui_world`, `ui_transitions`, `translations`, `ui_inspect`, `ui_wire`, `ui_debug` и `ui_testing`. Здесь нет atlas loader, поэтому libpng и zlib в этот рецепт не входят. Та же граница описана в [документе рецептов](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md#5-inventory).

## Владение и ресурсы {#ownership}

Приложению принадлежат значимые значения: обе панели, состав их карточек, выбранная строка и решение об ожидающем переносе. `tests/ui_recipes/inventory/main.odin` — чистый headless publisher над этим состоянием. Семейства UI владеют только техническим состоянием, описанным [контрактом жизненного цикла](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/lifecycle.md): подготовленные candidates, capture claims и fallible copies проверяются до commit barrier, затем следуют publication, dispatch, один outcome приложения, rebuild и render. Proposal не является эффектом, а recovery перестраивает принятую модель без повтора input.

Устойчивые ID строк берутся из данных приложения, а не из индекса отображения. Активация строки выбирает предмет; отдельная ручка выбранного предмета — это `Drag_Source`, а заголовки панелей — `Drop_Target`. Строки никогда не владеют drag и не владеют обычным scroll state: у каждой списочной области ровно один владелец смещения, и две области в одной публикации не должны делить ID области. `Begin`/`Aim`/`End` создаёт скопированное ограниченное pending proposal и не переносит предмет. `Cancel` не влияет на состав. `Confirm` повторно проверяет lifetime reader, pending token, ревизию модели и наличие источника и переносит предмет ровно один раз; запросы same-panel, stale-model, unknown-card и unknown-target отклоняются. После подтверждённого переноса устойчивый ID ищется в другом контейнере, поэтому выбор следует за предметом, а не за позицией отображения.

Этому fixture не нужны native-ресурсы. Он компилирует адаптеры SDL и SDL3_ttf и проверяет только их наличие, использует детерминированную геометрию вместо реальных метрик текста и не загружает шрифт, атлас, PNG или системную библиотеку. Не выводите из этого рецепта лицензии шрифтов или notices атласа: MIT-лицензия kit не перелицензирует шрифты, данные Unicode и native-зависимости; pins и notices — в [ресурсах](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md).

## Сборка и запуск {#build-and-run}

Из подготовленного source или portable root с Odin `dev-2026-10-nightly:84bc3fc`:

```sh
mkdir -p build
odin build tests/ui_recipes/inventory -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon -out:build/inventory-recipe
./build/inventory-recipe
```

Это headless-фрагмент: программа не открывает окно, не принимает физический ввод и печатает одну строку oracle. На закреплённой ревизии фактический вывод был таким:

```text
recipe-inventory effects=1 conflicts=1 live=0
```

`effects=1` — единственный применённый outcome приложения после скопированного proposal; `conflicts=1` — отклонённая попытка отдать одной строке одновременно claim коллекций и claim жестов; `live=0` — число живых байт tracking allocator после уничтожения всех readers и состояний. Команда завершилась с кодом 0. Oracle доказывает реальный путь dispatch, publication и retention с tracking allocator, а не только ненулевые символы.

## Проверки {#verify}

Oracle выше выполнен на Linux x86_64 с закреплённым релизом Odin. Он не рисует и не принимает физический ввод, поэтому это не display qualification.

Существующий native fixture `tests/ui_recipes/inventory/native/main.odin` проверяет тот же рецепт с окном, переданным шрифтом и синтетическими pointer-событиями. Он был собран и один раз запущен через проверенный изолированный display wrapper проекта: окно стартовало, явный focus доставлен, F11 выполнил ограниченный сценарий и напечатал

```text
native-inventory=ok two-regions=true drag-effect=1 stable-membership=true recovery=no-replay input=native-synthetic
```

затем F12 запросил cleanup, приложение завершилось с кодом 0, а run был остановлен в `finally`. Этот сценарий подтверждает один drag-эффект, поиск устойчивого членства в другом контейнере и отклонённый dispatch после инвалидации публикации без replay. Скриншоты того запуска — приватное доказательство, а не медиа сайта.

> Фрагмент: две команды ниже не являются полной сессией агента. `start` возвращает run id, после чего агент обязан использовать `focus`, адресовать все key/input/PNG этому run, отправить F11, прочитать журнал, отправить F12, проверить завершение приложения и всегда вызывать `stop` в `finally`. Обычным пользователям следует запускать существующий native-пример из раздела [Инвентарь лаборатории](../lab/inventory).

```sh
odin build tests/ui_recipes/inventory/native -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon -out:build/inventory-native
python3 -B scripts/ui_isd.py start --profile standalone-menu --isd "$ISD" --consumer-root tests/ui_recipes/inventory/native --kit-root kit --font resources/font.ttf --locale en --size 800x600 --scale 1
```

Полная portable-проверка, использованная для этой документации, собирает оба fixture из экспортированного root; см. [проверки](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/rules/checks.md). Успешная сборка и этот ограниченный сценарий не заменяют native display qualification и покрывают только Linux с закреплёнными входами.

## Исходники {#sources}

Закреплено за `8bc09cff358aa629410437996520283ff98d77d9`:

| Файл | Роль |
| --- | --- |
| [main.odin](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/tests/ui_recipes/inventory/main.odin) | Headless-публикация, две списочные области, цепочка жестов, скопированные readers и oracle. |
| [native/main.odin](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/tests/ui_recipes/inventory/native/main.odin) | Native-окно, синтетический pointer-сценарий и управление F11/F12. |
| [native_fixture/fixture.odin](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/tests/ui_recipes/native_fixture/fixture.odin) | Общая инициализация fixture, нормализация событий, проверки шрифта и teardown. |
| [ui_collections](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/kit/ui_collections/README.md) | Владение областями, материализация, устойчивые ID и выбор. |
| [ui_gestures](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/kit/ui_gestures/README.md) | Drag/drop candidates, lifetime proposal и правила отказа. |
| [рецепты](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md#5-inventory) | Контракт ограниченного рецепта и его пределы. |
| [жизненный цикл](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/lifecycle.md) | Prepare, commit, publish, outcome и recovery. |
| [ISD](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/isd.md) | Изолированный display wrapper для native-сценария. |

Карта пакетов и правила владения — в [использовании oui](../guide/using-oui). Видимый экран с модальным окном, сообщениями статуса и переключателем порядка показа описан на странице [Инвентарь лаборатории](../lab/inventory).