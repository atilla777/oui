# HUD и удержание {#hud}

Нативный HUD показывает HP, кнопки плюс/минус и действие восстановления удержанием. Удержание 1000 мс завершается один раз; после отпускания пример возвращается в покой с HP 100 и счётчиком 1. HP, счётчик и эффект принадлежат приложению.

![HUD: HP 60 из 100, состояние покоя и счётчик ноль; кнопка удержания в фокусе.](/media/hud-idle-ru.png)

Нативный HUD: покой, HP 60, интерфейс RU.

![HUD после полного удержания: HP 100 из 100, состояние покоя, счётчик один.](/media/hud-completed-ru.png)

Нативный HUD: после одного полного удержания и отпускания, интерфейс RU.

## Границы и пакеты {#boundaries}

Механизм экспериментальный: обычный Activate не обходит удержание; неполное удержание не восстанавливает HP. Рецепт HUD выбирает `ui_layers`, `ui_hold`, `ui_hold/sdl`, `ui_base`, `ui_layout`, `ui_interaction`, `ui_style`, `ui_text`, `ui_sdl`, `ui_sdl_text` и транзитивный Unicode. Полный showcase использует больше пакетов и ресурсов.

## Исходники и нативный пример {#source}

Ссылки закреплены за `4da8d7a57bd2453227a4c37df6b0b4d171401681`: [пример showcase](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/sections/hud.odin), [каталог](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/model/catalogue.odin), [выборочный пример рецепта](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/tests/ui_recipes/hud/main.odin), [рецепты](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/recipes.md) и [ресурсы](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md).

В подготовленном native checkout/export с документированными Odin, SDL3, SDL3_ttf, libpng и zlib:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section hud --locale ru --size 1280x960 --scale 1
```

Используйте -10 или +10, затем удерживайте Space на кнопке восстановления не менее секунды и отпустите.
