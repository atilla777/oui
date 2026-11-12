# Виртуальные коллекции {#collections}

Виртуальные коллекции материализуют видимый диапазон однородного списка или сетки, не создавая видимые узлы для всех элементов. В showcase 10 000 элементов; действие «Середина» показывает строки около item 05000.

![Нативный виртуальный список в середине 10000 элементов: видны элементы с 04995 по 05000.](/media/collections-ru.png)

Нативный showcase collections, интерфейс RU; список материализован в середине.

## Границы и пакеты {#boundaries}

Это экспериментальный API с однородной геометрией. У каждой области ровно один владелец смещения: нельзя добавлять ordinary scroll state к той же виртуальной области. Выбирайте `ui_collections` с зависимостями base, layout и interaction; showcase использует дополнительные пакеты и ресурсы.

## Исходники и нативный пример {#source}

[Showcase source](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/app/collection_runtime.odin) · [Native catalogue](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/model/catalogue.odin) · [API](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/api.md) · [Resources](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md) · [ISD](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/isd.md).

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section collections --locale ru --size 1280x960 --scale 1
```

Команда открывает нативное окно, а не сайт. Агентам нужен изолированный display wrapper; основной рабочий стол использовать нельзя.
