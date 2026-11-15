# Переходы состояния {#transitions}

Нативный пример переходов держит карточку внутри разложенной сцены. Активация «Цели B» перенацеливает отрисовку: дорожка смещения нацелена на (120, 24), масштаб 0.8, прозрачность 0.6, новые цвета переднего плана, фона и границы, а дорожка прогресса проходит от 0.25 к 0.75. «Цель A» возвращает базовое состояние. Удержание Space 1000 мс на контроле «Держать 1с» один раз увеличивает счётчик карточки после отпускания; неполное удержание этого не делает.

![Раздел переходов в состоянии «Цель A»: карточка в базовом положении, счётчик ноль и короткая полоса прогресса; «Цель A» в фокусе.](/media/transitions-ru-initial.png)

Нативные переходы: начальное состояние «Цель A», интерфейс RU.

![Раздел переходов после «Цели B»: карточка смещена и уменьшена, полупрозрачна с другими цветами, полоса прогресса длиннее; «Цель B» в фокусе.](/media/transitions-ru-after-b.png)

Нативные переходы: после «Цели B», интерфейс RU.

## Границы и пакеты {#boundaries}

Механизм экспериментальный: проекции отрисовки и попадания используют замороженный разложенный кадр, меняются только их выборочные значения; сама компоновка не анимируется. Целевое состояние и счётчик принадлежат приложению. Выбранный пример импортирует `ui_transitions`, `ui_hold`, `ui_controls`, `ui_base`, `ui_layout`, `ui_interaction`, `ui_layers`, `ui_scroll`, `ui_style`, `ui_text` и транзитивный Unicode. Полный showcase использует больше пакетов и ресурсов.

## Исходники и нативный пример {#source}

Ссылки закреплены за `8bc09cff358aa629410437996520283ff98d77d9`: [пример showcase](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/sections/transitions.odin), [каталог](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/catalogue.odin), [рецепты](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md) и [ресурсы](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md).

В подготовленном native checkout/export с документированными Odin, SDL3, SDL3_ttf, libpng и zlib:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section transitions --locale ru --size 1280x960 --scale 1
```

Нажимайте Tab до фокуса на «Цели B» и Return, чтобы применить состояние B; затем Tab до контроля «Держать 1с» и удерживайте Space не менее секунды, чтобы увеличить счётчик.
