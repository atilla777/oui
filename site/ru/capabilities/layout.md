# Компоновка {#layout}

Layout размещает геометрию интерфейса приложения. Нативный showcase показывает
строку и столбец, перекрывающиеся элементы стека, сетку, абсолютное размещение с
якорем и намеренное обрезание. Окружающие элементы управления и подписи принадлежат
showcase, а не являются браузерной реализацией oui.

![Окно showcase: примеры строки, столбца, стека, сетки, абсолютного размещения и намеренного обрезания.](/media/layout-ru.png)

Native showcase: layout, интерфейс RU; указанная ревизия, начальное состояние.
Подпись обрезана намеренно. Снимок относится к указанной ниже ревизии, а не ко
всем будущим версиям.

## Границы и пакеты {#boundaries}

Layout экспериментален. Каталог showcase явно указывает: **нет wrap, span и
auto-placement**. Некорректная геометрия и отказ аллокатора не считаются успешной
компоновкой. Для layout-only достаточно `ui_base` и `ui_layout`; текст,
interaction, SDL, шрифты и полный showcase не нужны. Сам showcase — более крупный
consumer с дополнительными пакетами и ресурсами.

## Исходники и нативный пример {#source}

Ссылки закреплены за `646dc817cd1b9e3149d6a018ef8bf83f5c87b3bb`:
[пример showcase](https://github.com/atilla777/oui/blob/646dc817cd1b9e3149d6a018ef8bf83f5c87b3bb/consumer/ui_showcase/app/pages.odin#L160),
[каталог](https://github.com/atilla777/oui/blob/646dc817cd1b9e3149d6a018ef8bf83f5c87b3bb/consumer/ui_showcase/model/catalogue.odin),
[layout-only fixture](https://github.com/atilla777/oui/blob/646dc817cd1b9e3149d6a018ef8bf83f5c87b3bb/tests/ui_foundation/layout_only/main.odin)
и [требования к ресурсам](https://github.com/atilla777/oui/blob/646dc817cd1b9e3149d6a018ef8bf83f5c87b3bb/docs/resources.md).

В подготовленном нативном checkout/export с документированными Odin, SDL3,
SDL3_ttf, libpng и zlib обычный пользователь может собрать и запустить showcase:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section layout --locale ru --size 1280x960 --scale 1
```

Это нативное окно, не сайт. Агенты используют
[изолированный display wrapper](https://github.com/atilla777/oui/blob/646dc817cd1b9e3149d6a018ef8bf83f5c87b3bb/docs/isd.md), без fallback на основной desktop.
