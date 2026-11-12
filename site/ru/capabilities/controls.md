# Элементы управления {#controls}

Нативный showcase составляет флажок, переключатель и целочисленный ползунок.
Значения принадлежат приложению; элементы выдают предложения, которые приложение
может принять и передать в следующее описание. Изначально флажок снят,
переключатель выключен, ползунок равен 50. На втором снимке флажок включён пробелом.

![Нативные элементы: флажок снят, переключатель выключен, ползунок на 50.](/media/controls-ru-initial.png)

Нативные элементы, интерфейс RU; начальное состояние.

![Нативные элементы: флажок установлен, переключатель выключен, ползунок на 50.](/media/controls-ru-changed.png)

Нативные элементы, интерфейс RU; флажок включён пробелом.

## Границы и пакеты {#boundaries}

В этом экспериментальном примере ползунок имеет диапазон 0–100 и шаг 1;
модель отвергает значения вне диапазона. Предложение само не является состоянием
приложения. Выберите `ui_controls` и headless зависимости: `ui_base`, `ui_layout`,
`ui_interaction`, `ui_style`, `ui_text`, `ui_layers`, `ui_scroll` и
`unicode_graphemes`. Полный showcase также требует SDL, текст и ресурсы.

## Исходники и нативный пример {#source}

Ревизия `4da8d7a57bd2453227a4c37df6b0b4d171401681`:
[пример](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/app/pages.odin#L271),
[модель](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/model/model.odin),
[API controls](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/kit/ui_controls/README.md) и
[ресурсы](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md).
В подготовленном checkout или export с документированными Odin, SDL3, SDL3_ttf,
libpng и zlib:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section controls --locale ru --size 1280x960 --scale 1
```

Это нативное окно, а не браузерный элемент. Агенты используют [изолированную обёртку](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/isd.md).
