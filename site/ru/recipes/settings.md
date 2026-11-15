# Рецепт: настройки {#settings-recipe}

«Рецепт: настройки» — ограниченная headless-композиция для шаблона настроек:
одна модальная область с однострочным редактором имени и одним флажком на базе
`ui:ui_layers`, `ui:ui_controls` и `ui:ui_editor`. Его исполняемый субъект —
`tests/ui_recipes/settings/main.odin`. Оконный поток «черновик → применить →
подтверждение → отбросить» — это существующий код приложения в
`consumer/ui_showcase/app/lab_menu*`; рецепт не добавляет второй реализации.
На странице [«Лаборатория: настройки»](../labs/settings) показан этот экран и
его подлинные нативные снимки.

## Границы {#boundaries}

Выбранные прямые импорты fixture: `ui_layers`, `ui_controls`, `ui_editor`,
`ui_controls/sdl`, `ui_editor/sdl`, `ui_base`, `ui_layout`, `ui_interaction` и
`ui_text`. Полный compile closure дополнительно содержит `ui_scroll`, `ui_style`,
`ui_sdl`, `ui_sdl_text` и `unicode_graphemes`, и ничего больше. Он не импортирует
collections, gestures, hold, rich text, custom-страницы, transitions, inspection,
testing, debug transport, переводы и загрузчик ресурсов или атласов. Fixture
передаёт собственные строки `Name`/`Enabled` и детерминированные метрики текста.
SDL-адаптеры элементов и редактора компилируются и создаются, но никакое SDL-окно,
renderer, шрифт, событийный цикл или реальные метрики текста здесь не работают,
поэтому это не второе оконное приложение.

Fixture намеренно меньше экрана, который он поддерживает. Он публикует модальную
область, поле редактора и флажок и проверяет общие правила публикации; в нём нет
ползунка, диалога подтверждения, вопроса об отбрасывании и показа применённых
значений. Это остаётся ответственностью приложения в runtime reference ниже.

## Запускаемый fixture {#fixture}

Фрагмент полный: он собирает fixture с точными флагами и запускает его. Из корня
oui, где Odin доступен, а kit подключён коллекцией `ui`:

```sh
mkdir -p build
odin build tests/ui_recipes/settings -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon -out:build/settings-recipe
build/settings-recipe
```

Проверенный stdout в задокументированном нативном окружении:

```text
recipe-settings effects=1 conflicts=1 live=0
```

Это результаты самого fixture, а не признак «дыма». `effects=1` — одно
предложение флажка даёт ровно один результат приложения; `conflicts=1` —
намеренный отказ второй capture family, претендующей на то же поле редактора, до
любой публикации; `live=0` — tracking allocator после destroy. Тот же запуск
проверяет начальный фокус модальной области и scope редактора, что второе
действие не может использовать уже инвалидированный кадр, что submit после
инвалидации возвращает `Not_Ready`, и что owning reader, скопированный до
commit, по-прежнему читает своё значение после уничтожения издателя.

## Runtime reference {#runtime}

Оконный reference — существующий раздел showcase, а не новый пример:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section lab-settings --locale ru --size 1280x960 --scale 1
```

`--section lab-menu` открывает то же приложение на странице меню Lab, откуда
пункт настроек ведёт к тому же диалогу. Сборка добавляет libpng и zlib через
`pkg-config` и связывает SDL3 и SDL3_ttf через vendor-биндинги Odin; SDL3,
SDL3_ttf, libpng, zlib, два поставленных шрифта и оба манифеста атласов должны
быть установлены и доступны при запуске. Бинарник showcase — большое объединение
всех пакетов галереи и Lab, поэтому он шире closure fixture выше; именно это
объединение делает доступным связанный поток отрисовки, ввода и подтверждения. Команда открывает
нативное окно. Агентам нужен
[изолированный display wrapper](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/isd.md),
не основной рабочий стол.

## Владение и ограничения {#ownership}

Приложению принадлежат черновик и применённое имя, черновые «Включено» и
«Количество» и решения применить или отбросить их. «Применить» проверяет черновик
в 1–64 графемы и запрашивает подтверждение; только «Подтвердить» один раз
копирует показанную ревизию в применённые значения, под защитой pending revision
и проверки использованного токена, поэтому устаревшее подтверждение ничего не
применяет, а recovery не повторяет Apply. «Отмена» и «Вернуться в каталог»
спрашивают перед отбрасыванием изменённого черновика и при выборе восстанавливают
применённые значения. Имя однострочное, без IME, undo и нормализации; граница в
64 кластера принадлежит приложению, а не `ui_editor`. Всё живёт в процессе: это
учебные данные без сохранения на диск.

## Исходники {#sources}

Исходники на ревизии `8bc09cff358aa629410437996520283ff98d77d9`:
[ограниченный fixture](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/tests/ui_recipes/settings/main.odin),
[контракт рецепта](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md),
[композиция диалога](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/lab_menu.odin),
[модель применённых настроек](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/lab.odin),
[пакет редактора](https://github.com/atilla777/oui/tree/8bc09cff358aa629410437996520283ff98d77d9/kit/ui_editor),
[пакет элементов](https://github.com/atilla777/oui/tree/8bc09cff358aa629410437996520283ff98d77d9/kit/ui_controls)
и [требования к ресурсам](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md).
