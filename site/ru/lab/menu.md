# Меню лаборатории {#lab-menu}

Экран `lab-menu` в Integration Lab — учебный поток настроек, собранный из существующих семейств menu, layers, controls и editor. Главная страница предлагает `Открыть подменю`; в подменю есть `Настройки` и `Главное меню`; «Настройки» открывают модальное окно с однострочным черновиком имени, «Применить» и «Отмена», флажком «Включено», ползунком «Количество» и возвратом в каталог. «Применить» показывает подтверждение для отображаемого черновика; «Подтвердить» применяет его один раз, «Продолжить редактирование» возвращает к черновику.

Настройки — учебные данные. В каталоге экран помечен как **Mock settings; process-local**, а ограничение раздела — «Учебные данные; состояние только до завершения процесса». Значения настроек не читаются с диска и не записываются на диск; они исчезают вместе с процессом. Поле имени использует однострочный editor: при применении 1–64 расширенных графемных кластера, без IME, undo и нормализации.

![Начальный экран меню лаборатории с кнопкой «Открыть подменю» в фокусе.](/media/lab-menu-initial-ru.png)

Native Lab menu: меню лаборатории, интерфейс RU; начальный экран, фокус на «Открыть подменю».

![Подменю меню лаборатории: «Настройки» в фокусе и «Главное меню» ниже.](/media/lab-menu-submenu-ru.png)

Native Lab menu: подменю с «Настройки» и «Главное меню», интерфейс RU.

![Модальные настройки меню лаборатории: черновик имени, «Применить» и «Отмена», флажок «Включено», ползунок «Количество» и возврат в каталог.](/media/lab-menu-settings-ru.png)

Native Lab menu: настройки с черновиком имени в фокусе, интерфейс RU.

![Подтверждение применения в меню лаборатории: имя черновика, «Включено: false», «Количество: 50», «Продолжить редактирование» и «Подтвердить».](/media/lab-menu-confirm-ru.png)

Native Lab menu: подтверждение применения неизменённого черновика, интерфейс RU.

## Границы и пакеты {#boundaries}

Механизм экспериментальный. Экран показывает модальный слой, флажок и ползунок controls и editor в одной композиции; это не общая система настроек, не слой хранения и не form framework. Черновик и применённые значения раздельны, и только подтверждение применяет показанный черновик. Уход с изменениями вызывает существующий выбор Stay/Discard. Неверные или устаревшие pending-значения не применяются; recovery не повторяет Apply.

`consumer/ui_showcase/app/lab_menu.odin` импортирует семейства UI `ui_base`, `ui_interaction`, `ui_layers`, `ui_controls`, `ui_editor` и `ui_sdl_text`, а также собственные пакеты showcase `model` и `sections`. Общая композиция `sections` дополнительно выбирает layout, style и text, а работающий showcase — **более широкий union**: в нём все экраны галереи и Lab, backend SDL и consumer atlas loader с libpng и zlib. Этот union не является набором зависимостей одного экрана. Узкое исполняемое меню без layers, controls, editor и атласов описано в [рецепте меню](../recipes/menu).

## Исходники и нативный пример {#source}

Закреплено за `b4c8be17b81125f4d1ef44b97de99d8c327825fb`:
[экран lab-menu](https://github.com/atilla777/oui/blob/b4c8be17b81125f4d1ef44b97de99d8c327825fb/consumer/ui_showcase/app/lab_menu.odin),
[строки Lab](https://github.com/atilla777/oui/blob/b4c8be17b81125f4d1ef44b97de99d8c327825fb/consumer/ui_showcase/app/lab_strings.odin),
[редактор имени](https://github.com/atilla777/oui/blob/b4c8be17b81125f4d1ef44b97de99d8c327825fb/consumer/ui_showcase/sections/name.odin),
[модель](https://github.com/atilla777/oui/blob/b4c8be17b81125f4d1ef44b97de99d8c327825fb/consumer/ui_showcase/model/model.odin),
[ID и ограничения каталога](https://github.com/atilla777/oui/blob/b4c8be17b81125f4d1ef44b97de99d8c327825fb/consumer/ui_showcase/model/catalogue.odin),
[граница рецепта](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md#4-settings) и
[ресурсы](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md).

Showcase подключает consumer atlas loader, поэтому кроме Odin, SDL3 и SDL3_ttf нужны libpng и zlib. Текущие pins ресурсов — libpng 1.6.59 и zlib 1.4. Подготовьте эту пару в private prefix и направьте на одни и те же библиотеки и `pkg-config`, и runtime loader; не смешивайте с ней системные headers или библиотеки. Архивы, дайджесты и notices записаны в [документации ресурсов](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md).

В подготовленном native checkout или export с этими зависимостями:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section lab-menu --locale en --size 1280x960 --scale 1
# Русский интерфейс:
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section lab-menu --locale ru --size 1280x960 --scale 1
```

Return открывает элемент в фокусе. С начального экрана Return на `Открыть подменю` открывает подменю; Return на `Настройки` открывает модальные настройки. Tab доходит до «Применить»; Return показывает подтверждение, где Tab переходит на «Подтвердить» и Return применяет черновик один раз, а Return на «Продолжить редактирование» возвращает к черновику.

Откроется нативное окно, а не сайт. Агенты обязаны использовать [изолированный display wrapper](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/isd.md), а не основной рабочий стол.