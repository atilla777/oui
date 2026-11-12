# Прокрутка и таблица {#scroll-table}

Обычная вертикальная прокрутка перемещает таблицу в области просмотра. В showcase три фиксированные колонки: предмет, вид и количество; после прокрутки на снимке видны строки 24–32.

![Нативная таблица прокручена к предметам с 24 по 32; видны колонки предмета, вида и количества.](/media/scroll-table-ru.png)

Нативный showcase scroll-table, интерфейс RU; таблица прокручена к концу.

## Границы и пакеты {#boundaries}

Это экспериментальная вертикальная невложенная прокрутка; пример использует три фиксированные колонки. Это обычная прокрутка, а не виртуализация коллекции. Выбирайте `ui_scroll` вместе с необходимыми `ui_base`, `ui_layout` и `ui_interaction`.

## Исходники и нативный пример {#source}

[Showcase source](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/app/pages.odin) · [Native catalogue](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/model/catalogue.odin) · [API](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/api.md) · [Resources](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md) · [ISD](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/isd.md).

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section scroll-table --locale ru --size 1280x960 --scale 1
```

Команда открывает нативное окно, а не сайт. Агентам нужен изолированный display wrapper; основной рабочий стол использовать нельзя.
