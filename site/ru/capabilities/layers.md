# Слои {#layers}

Слои разделяют взаимодействие на явные модальные области и панели. Нативный пример открывает A и вложенную B, переключает панель и неинтерактивную подсказку; отмена зависит от выбранной политики. Счётчики и эффекты принадлежат приложению, а не механизму слоёв.

![Раздел слоёв: открытая панель и неинтерактивная подсказка поверх элементов.](/media/layers-popup-tooltip-ru.png)

Нативные слои: панель и неинтерактивная подсказка, интерфейс RU.

![Модальная область A: счётчик в фокусе, прокручиваемые строки и кнопки B, закрытия, панели и подсказки.](/media/layers-modal-ru.png)

Нативные слои: открыта модальная область A, интерфейс RU.

## Границы и пакеты {#boundaries}

Механизм экспериментальный: владение областями и фокус явные, подсказка не принимает ввод. Выбранный механизм использует `ui_base`, `ui_interaction` и `ui_layers`; потребитель отдельно выбирает геометрию, вывод и другие нужные семейства. Полный showcase значительно шире.

## Исходники и нативный пример {#source}

Ссылки закреплены за `4da8d7a57bd2453227a4c37df6b0b4d171401681`: [пример showcase](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/sections/layers.odin), [каталог](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/model/catalogue.odin), [выборочный пример рецепта](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/tests/ui_recipes/settings/main.odin), [рецепты](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/recipes.md) и [ресурсы](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md).

В подготовленном native checkout/export с документированными Odin, SDL3, SDL3_ttf, libpng и zlib:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section layers --locale ru --size 1280x960 --scale 1
```

Откройте A, затем B или закройте область. В базовой области переключите панель и подсказку; Escape закрывает открытую панель.
