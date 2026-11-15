# Свои примитивы {#custom}

Два рецепта с namespace собирают панели рядом с владеемыми приложением узлами-кругами. Описание custom-примитива несёт неизменяемые payload-байты и доверенные чистые callbacks validate, measure и hit; круг активируется только внутри своей круглой области, а подвал панели считает записанные активации. «Стиль» и «Подвал» переключают оформление левого рецепта и его подвал, а popup и подсказка располагаются поверх панелей.

![Страница showcase с действиями Стиль, Подвал, Недоступность, Щит popup и Подсказка над двумя панелями с кругами и счётчиком ноль.](/media/custom-ru-initial.png)

Native showcase: свои примитивы, интерфейс RU; начальное состояние.

![Та же страница: счётчик в подвале левой панели стал равен одному после активации круга.](/media/custom-ru-activated.png)

Native showcase: свои примитивы, интерфейс RU; левый круг активирован один раз.

![Та же страница: левая панель переоформлена, её подвал удалён; правая панель не изменилась.](/media/custom-ru-styled.png)

Native showcase: свои примитивы, интерфейс RU; применён стиль и удалён подвал.

![Та же страница: поверх панелей открыт popup с кнопкой закрытия и подсказка в зарезервированной позиции.](/media/custom-ru-popup-tooltip.png)

Native showcase: свои примитивы, интерфейс RU; показаны щит popup и подсказка.

## Границы и пакеты {#boundaries}

Механизм экспериментальный. Проверка попадания чистая и не выделяет память; семантическая активация её не вызывает. Callbacks — доверенные функции на время процесса, а не sandbox или plugin ABI, а рендеринг живёт в отдельном SDL-адаптере. Выбранные пакеты: `ui_custom`, `ui_composition`, `ui_base`, `ui_layout`, `ui_interaction` и `ui_style`; полный showcase использует больше пакетов и ресурсов.

## Исходники и нативный пример {#source}

Ссылки закреплены за `8bc09cff358aa629410437996520283ff98d77d9`: [пример showcase](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/sections/custom.odin), [runtime круга](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/custom_runtime.odin), [каталог](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/catalogue.odin), [README пакета](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/kit/ui_custom/README.md), [рецепты](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md) и [ресурсы](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md).

В подготовленном native checkout/export с документированными Odin, SDL3, SDL3_ttf, libpng и zlib:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section custom --locale ru --size 1280x960 --scale 1
```

Активируйте круг в фокусе клавишей Enter, затем «Стиль», «Подвал», «Щит popup» и «Подсказка», чтобы менять рецепты и оверлеи; клики вне круглой области круга его не активируют.
