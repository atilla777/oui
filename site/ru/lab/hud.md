# Лаборатория HUD {#lab-hud}

Экран «Лаборатория HUD» в Integration Lab — учебный экран HUD с восстановлением удержанием. Учебный HP начинается с 60 из 100; -10 и +10 ограничивают его; кнопке восстановления нужно удержание Space 1000 мс; Popup открывает панель с кнопкой «Закрыть», а Explain показывает неинтерактивную подсказку. Нативные метаданные — `Mock HP; hold 1000 ms`, ограничение Lab — «Учебные данные; состояние только до завершения процесса»: учебные данные, состояние живёт только до завершения процесса.

![Лаборатория HUD: учебный HP 60, покой и счётчик ноль, кнопка удержания в фокусе.](/media/lab-hud-initial-ru.png)

Нативная лаборатория HUD, интерфейс RU; учебный HP 60, покой и счётчик ноль.

![Лаборатория HUD с открытой панелью поверх элементов удержания.](/media/lab-hud-popup-ru.png)

Нативная лаборатория HUD, интерфейс RU; открытая панель поверх элементов удержания.

![Лаборатория HUD во время удержания: полоса прогресса заполнена частично.](/media/lab-hud-hold-ru.png)

Нативная лаборатория HUD, интерфейс RU; удержание в процессе, 698 мс.

![Лаборатория HUD после одного полного удержания: учебный HP 100 и счётчик один.](/media/lab-hud-completed-ru.png)

Нативная лаборатория HUD, интерфейс RU; после одного полного удержания и отпускания, HP 100 и счётчик один.

## Учебный HP, удержание и различия отказов {#distinctions}

- Порог: удержание 999 мс с последующим отпусканием не даёт эффекта; полное удержание 1000 мс с отпусканием восстанавливает HP до 100 и увеличивает счётчик один раз.
- Activate: обычный Activate на кнопке восстановления не обходит удержание.
- Отмена: открытая панель экранирует удержание, поэтому закройте её перед удержанием; потеря фокуса отменяет начатое удержание.
- Без повтора: восстановление пересобирает принятую модель и не повторяет завершённое восстановление.
- Завершение: полное удержание применяется один раз, и кнопка возвращается в покой.

Эти исходы покрывает [тест контракта](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/lab_contract_test.odin) в нативной композиции.

## Границы и пакеты {#boundaries}

`app/lab_hud.odin` импортирует `ui_base` и `ui_interaction` и составляет `sections/hud.odin`, который выбирает `ui_hold`, а через общие помощники страницы — layout, style, text и другие семейства showcase; страница Lab добавляет `ui_layers` для панели и подсказки. Запущенный showcase — более широкое объединение: его бинарник содержит и загрузчик атласа, поэтому линкует libpng и zlib, хотя на этом экране нет содержимого атласа. HP, счётчик удержаний и эффект остаются в модели приложения; kit только сообщает прогресс и одно завершение.

## Исходники и нативный пример {#source}

Ссылки закреплены за `8bc09cff358aa629410437996520283ff98d77d9`: [композиция Lab HUD](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/lab_hud.odin), [раздел HUD](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/sections/hud.odin), [метаданные каталога](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/catalogue.odin), [тест контракта](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/lab_contract_test.odin) и [документ ISD](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/isd.md).

В подготовленном native checkout/export с документированными Odin, SDL3, SDL3_ttf, libpng и zlib:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section lab-hud --locale en --size 1280x960 --scale 1
# Или для русского:
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section lab-hud --locale ru --size 1280x960 --scale 1
```

Tab перемещает фокус, Return активирует кнопку в фокусе, а Space, удерживаемый около секунды на кнопке восстановления, выполняет удержание; отпускание раньше 1000 мс не даёт эффекта. Программа открывает нативное окно. Обычные пользователи запускают её в собственной графической сессии; агенты обязаны использовать изолированную обёртку дисплея с выбранной проверенной копией ISD, как описано в [документе ISD](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/isd.md).

См. [Рецепт HUD](../recipes/hud) для узкого замыкания зависимостей и [HUD и удержание](../capabilities/hud) для границы галереи.