# Рецепт меню {#basic-menu}

Standalone-меню — минимальный исполняемый пример обычного интерактивного экрана: главная страница с двумя кнопками, подменю с выбором языка и Back, без слоёв, controls и editor. Тот же пример собирается из документированных исходников kit и запускается со шрифтом, который передаёт вызывающая сторона.

Это не экран Integration Lab. `lab-menu` в Lab добавляет к меню модальный слой, controls и editor; это более широкий пример со своей страницей [Меню лаборатории](../lab/menu). Список зависимостей ниже относится только к `consumer/standalone_menu`.

## Границы зависимостей {#dependencies}

Меню напрямую импортирует перечисленные семейства; `unicode_graphemes` — единственный транзитивный UI-пакет, он приходит через `ui_text`.

| Импорт | Роль в этом меню |
| --- | --- |
| `ui_base` | Примитивы publication, ошибки и общее состояние публикации. |
| `ui_layout` | Подготовка и проверка узлов, текста и геометрии. |
| `ui_interaction` | Targets, focus, routing и намерения ввода. |
| `ui_style` | Метаданные отрисовки, подготовленные из принятой композиции. |
| `ui_text` | Подготовка текста и измеренная компоновка. |
| `ui_sdl` | Выбранный backend SDL3: renderer, input и события. |
| `ui_sdl_text` | Адаптер шрифтов и текста SDL3_ttf. |
| `unicode_graphemes` | Транзитивно через `ui_text`; сегментация расширенных графемных кластеров. |

Другие семейства UI не нужны: пример не импортирует `ui_layers`, `ui_controls`, `ui_editor`, `ui_collections`, `ui_gestures`, `ui_rich`, `ui_hold`, `translations`, `ui_inspect`, `ui_wire`, `ui_debug` и `ui_testing`. Здесь нет atlas loader, поэтому libpng и zlib в этот рецепт не входят. Та же граница описана в [документе рецептов](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md#2-basic-menu).

## Владение и ресурсы {#ownership}

Приложению принадлежат значимые значения: страница, локаль и счётчик. `model/model.odin` — чистый reducer над этими значениями; `runtime.odin` владеет типизированным publisher и retained reader; `strings.odin` содержит собственные английские и русские строки приложения. Семейства UI владеют только техническим состоянием, описанным [контрактом жизненного цикла](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/lifecycle.md): подготовьте candidates, claims и fallible copies до commit barrier, затем опубликуйте, обработайте input, примените один outcome приложения, перестройте и отрисуйте. Proposal не является эффектом, а recovery перестраивает принятую модель без повтора input.

Основной шрифт передаёт вызывающая сторона через `--font`; пример не ищет системные шрифты и не встраивает шрифт через `#load`. Сохраняйте notices выбранного шрифта. MIT-лицензия kit не перелицензирует шрифты, данные Unicode и native-зависимости; pins и notices — в [ресурсах](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md), заметка самого примера — в `consumer/standalone_menu/README.md`.

## Сборка и запуск {#build-and-run}

Из подготовленного source или portable root, где linker и loader находят Odin `dev-2026-10-nightly:84bc3fc`, SDL3 `3.4.16` и SDL3_ttf `3.2.2`:

```sh
mkdir -p build
odin build consumer/standalone_menu -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon -out:build/menu
build/menu --font resources/font.ttf --locale en --size 800x600 --scale 1
# Или русский интерфейс:
build/menu --font resources/font.ttf --locale ru --size 800x600 --scale 1
```

Начальная главная страница показывает `Action` и `Submenu`; фокус стоит на `Action`. Tab переводит на `Submenu`, Return открывает подменю с кнопкой языка и `Back`. Return на кнопке языка переключает локаль интерфейса. Это обычные outcomes приложения, а не скрытые эффекты. Запускайте по одной команде на подходящей графической сессии.

Эти интерактивные команды предназначены обычным пользователям. Агенты не должны использовать основной дисплей; им нужен отдельно предоставленный проверенный ISD через [wrapper](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/isd.md), собственный run, явный focus и очистка.

## Проверки {#verify}

Сборка и тесты ниже используют существующий fixture; production-сборка не получает лишних тестовых флагов:

```sh
odin test consumer/standalone_menu/model -vet -vet-style -vet-tabs -vet-semicolon -out:build/menu-model-tests
odin test consumer/standalone_menu -collection:ui=kit -define:STANDALONE_MENU_TEST=true -define:ODIN_TEST_THREADS=1 -vet -vet-style -vet-tabs -vet-semicolon -out:build/menu-tests
odin test kit/ui_sdl -define:ODIN_TEST_THREADS=1 -out:build/ui-sdl-tests
odin test kit/ui_sdl_text -define:ODIN_TEST_THREADS=1 -out:build/ui-sdl-text-tests
```

Эти команды выполнены на закреплённой ревизии в Linux x86_64 с указанными версиями: меню собралось, прошли 2 теста модели и 4 теста consumer, а также 17 тестов backend SDL и 1 тест текста SDL. Успешная сборка и тесты не заменяют native display qualification и не охватывают другие платформы. Allocation, lifetime reader и fault-тесты примера описаны в README.

## Исходники {#sources}

Закреплено за `8bc09cff358aa629410437996520283ff98d77d9`:

| Файл | Роль |
| --- | --- |
| [main.odin](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/standalone_menu/main.odin) | Инициализация SDL/TTF, окно, цикл событий и shutdown. |
| [options.odin](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/standalone_menu/options.odin) | Параметры шрифта, локали, размера и масштаба. |
| [runtime.odin](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/standalone_menu/runtime.odin) | Типизированный publisher, reader, render и recovery. |
| [model/model.odin](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/standalone_menu/model/model.odin) | Чистая модель приложения и reducer. |
| [strings.odin](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/standalone_menu/strings.odin) | Собственные локализованные строки примера. |
| [README.md](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/standalone_menu/README.md) | Независимый root, поведение, lifetime и заметки о тестах. |

Карта пакетов, правила владения и ограничения совместимости — в [использовании oui](../guide/using-oui), [рецептах](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md) и [документации ресурсов](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md). Более широкий экран со слоями, controls и editor описан на странице [Меню лаборатории](../lab/menu).