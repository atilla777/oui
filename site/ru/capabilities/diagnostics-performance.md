# Диагностика и производительность {#diagnostics-performance}

Нативная страница G20–G21 объединяет пример с редактором и коллекцией и
потребительские замеры. Она показывает фазы CPU для prepare, copy, commit,
draw, readback и present (p/c/k/d/r/p), счётчики обратных вызовов метрик текста
и операций. «Замеры вкл/выкл» скрывает все фазы и счётчики. Пять проб —
«Дубликат», «Невалидный», «Ресурс», «Владение» и «Не поддержано» — выдают
собственные наблюдения family, stage, code и id вместо изменения обычного
состояния страницы.

Строка состояния начинает показывать фазы CPU после первого полного кадра.
Однострочный редактор удерживает одну строку в фокусе, а список коллекции над
ним остаётся редактируемым.

![Нативная страница G20-G21: пять диагностических проб, переключатель замеров, счётчики фаз CPU и панели редактора и коллекции.](/media/diagnostics-performance-ru-initial.png)

Нативная страница диагностики и производительности, интерфейс RU; фазы CPU после первого полного кадра.

![Нативная страница G20-G21 после пробы «Дубликат»: строка состояния сообщает ожидаемое наблюдение Layout Prepare с кодом 2 и id fixture.](/media/diagnostics-performance-ru-diagnostic.png)

Нативная страница диагностики и производительности, интерфейс RU; наблюдение пробы «Дубликат».

## Границы и пакеты {#boundaries}

Механизм экспериментальный и включается явно на стороне потребителя: страница
наблюдает собственные замеры отправки CPU. Здесь нет транспорта отладчика,
измерения времени GPU, учёта кучи SDL и числовых SLA. Наблюдение описывает одну
ожидаемую сбойную пробу, а обычные действия требуют актуального кадра. Путь
страницы использует `ui_base`, `ui_layout`, `ui_interaction`, `ui_text`,
`ui_editor`, `ui_editor/sdl`, `ui_collections`, `ui_sdl_text` и `ui_sdl`, а также
общую отрисовку оболочки `ui_style` и транзитивный Unicode. Полный showcase
связывает больше пакетов и ресурсов.

## Исходники и нативный пример {#source}

Ссылки закреплены за `4da8d7a57bd2453227a4c37df6b0b4d171401681`: [страница showcase](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/sections/performance.odin), [среда проб](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/app/diagnostic_runtime.odin), [каталог](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/model/catalogue.odin) и [ресурсы](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md).

В подготовленном native checkout/export с документированными Odin, SDL3, SDL3_ttf, libpng и zlib:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section diagnostics-performance --locale en --size 1280x960 --scale 1
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section diagnostics-performance --locale ru --size 1280x960 --scale 1
```

Tab переводит фокус на «Дубликат», Return запускает эту пробу; один и тот же
раздел и ресурсы служат обоим языкам. Это нативное окно, а не браузерный
элемент. Агенты используют [изолированную обёртку](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/isd.md).