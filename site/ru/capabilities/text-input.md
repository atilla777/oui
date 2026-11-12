# Ввод текста {#text-input}

Редактор имени в native showcase показывает однострочный черновик в фокусе,
кнопки применения и отмены и отдельно применённое значение. Значением владеет
приложение; редактор управляет взаимодействием, например кареткой и выделением.

![Редактор имени в фокусе с изменённым черновиком, кнопками применения и отмены и неизменённым применённым значением.](/media/text-input-ru.png)

Native showcase: ввод текста, интерфейс RU; черновик в фокусе после ввода символа; применённое значение не изменено.

## Ограничения и пакеты {#boundaries}

Возможность экспериментальная и однострочная. Редактирование использует
расширенные графемные кластеры (EGC) Unicode 15.1, а не количество байтов или
глифов. Showcase принимает при применении 1–64 EGC и допускает пустой черновик.
Поддержка IME, undo и нормализации Unicode не заявлена. Сегментация EGC не
является shaping или двунаправленной компоновкой. `ui_editor` использует
`ui_text` и `unicode_graphemes` наряду с другими зависимостями kit; showcase
также требует SDL, шрифты и ресурсы атласов.

## Исходники и нативный пример {#source}

Исходники закреплены за `4da8d7a57bd2453227a4c37df6b0b4d171401681`:
[пример имени](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/sections/name.odin),
[редактор](https://github.com/atilla777/oui/tree/4da8d7a57bd2453227a4c37df6b0b4d171401681/kit/ui_editor),
[таблицы Unicode](https://github.com/atilla777/oui/tree/4da8d7a57bd2453227a4c37df6b0b4d171401681/kit/unicode_graphemes),
[требования к ресурсам](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md).

В подготовленном native checkout с указанными зависимостями:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section text-input --locale ru --size 1280x960 --scale 1
```

Откроется нативное окно, а не сайт. Агенты обязаны использовать
[изолированный display wrapper](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/isd.md).
