# Якоря мира {#world}

Якоря мира размещают обычные карточки в точках мировых координат. Камерой владеет приложение, и оно передаёт callback проекции; kit возвращает границы, видимость, прижатие и нормализованное направление для каждого якоря. В showcase три якоря: A следует за кнопками объекта, B закреплён в мировой точке (800, 0), а C — в (-800, -500). Каждая кнопка камеры сдвигает вид на 64 мировые единицы, Zoom переключает масштаб 1 и 2, а Reset восстанавливает начальную модель. Карточки показывают подпись и полосу прогресса; строка заголовка сообщает причину для каждого якоря, например Placed или Offscreen.

![Страница world: карточка A в центре, причины A/B/C и политика Hide.](/media/world-initial-ru.png)

Нативные якоря мира, интерфейс RU; начальное состояние: A размещён, B и C за экраном (политика Hide).

![Страница world после трёх шагов Camera +X: A смещён влево, у краёв два индикатора B и C при политике Direction.](/media/world-indicators-ru.png)

Нативные якоря мира, интерфейс RU; после трёх шагов Camera +X и политики Direction.

## Границы и пакеты {#boundaries}

Механизм экспериментальный: helper не хранит якоря, камеру или callback и не выделяет память; моделью, снимком камеры и проекцией владеет приложение. Страница world выбирает `ui_base`, `ui_layout`, `ui_interaction`, `ui_style` и `ui_world`; полный showcase использует больше пакетов и ресурсов. Hide скрывает якоря за экраном, Clamp удерживает всю карточку внутри области просмотра, а Direction заменяет карточку за экраном индикатором у края. Здесь нет движка, графа сцены и Game Bridge; приложение собирает обычную обрезанную область просмотра.

## Исходники и нативный пример {#source}

Ссылки закреплены за `8bc09cff358aa629410437996520283ff98d77d9`: [раздел world в showcase](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/sections/world.odin), [нативный каталог](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/catalogue.odin), [helper мира](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/kit/ui_world/anchors.odin), [API](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/api.md), [ресурсы](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md) и [ISD](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/isd.md).

В подготовленном native checkout/export с документированными Odin, SDL3, SDL3_ttf, libpng и zlib:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section world --locale ru --size 1280x960 --scale 1
```

Команда открывает нативное окно, а не сайт. Агентам нужен изолированный display wrapper; основной рабочий стол использовать нельзя. Tab перемещает фокус, Space или Return активирует кнопки объекта, камеры, Zoom, политики и Reset.