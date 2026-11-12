# Атлас {#atlas}

Нативный showcase загружает страницы изображений и именованные области для панели,
состояний кнопки, nine-slice с растяжением и повтором и изображения с pivot.
Кнопка A/B переключает два поставляемых набора ресурсов. Reload повторно читает
выбранный набор; это не браузерная реализация kit.

![Нативная страница Atlas: синие ресурсы A, pivot 0.5,0.5 и нулевой счётчик reload.](/media/atlas-ru-initial.png)

Атлас A, начальное состояние; B=false и reload=0.

![Нативная страница Atlas после переключения на золотистые ресурсы B, pivot 1,0 и нулевой счётчик reload.](/media/atlas-ru-alternate.png)

Атлас B после смены ресурса; B=true и reload=0.

![Нативная страница Atlas после перезагрузки B: в статусе B=true и reload=1.](/media/atlas-ru-reload.png)

Атлас B после перезагрузки; B=true и reload=1. При неизменённых файлах внешний
вид может не измениться. Все три снимка получены из нативного приложения на
указанной ниже ревизии, 1280×960, масштаб 1.

## Границы и ресурсы {#boundaries}

Showcase использует `ui_style` для метаданных атласа и `ui_sdl` для отрисовки;
отдельный consumer loader читает файлы через libpng и zlib. Это не PNG-парсер
в ядре UI. Наборы A и B содержат разные manifest и изображения; их SHA-256 и
идентификаторы шрифтов указаны в [ресурсах](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md).

Consumer принимает UTF-8 JSON manifest версии 1 до 1 МиБ, до 16 страниц и
4096 областей с уникальными ID и корректными ссылками на страницы. PNG должен
быть нечересстрочным 8-битным RGB или RGBA, не более 4096×4096 и 16 МиБ в файле;
проверяются CRC и структура, APNG отклоняется. Это ограничения loader, а не
обещание поддержки произвольного PNG или manifest. Ошибка не является успешной
заменой ресурса.

## Исходники и нативный пример {#source}

Ревизия `4da8d7a57bd2453227a4c37df6b0b4d171401681`:
[showcase](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/sections/content.odin),
[loader](https://github.com/atilla777/oui/tree/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/atlas_catalog/loader),
[ресурсы и зависимости](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md).
В подготовленном нативном checkout/export с указанными Odin, SDL3, SDL3_ttf,
libpng и zlib:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section atlas --locale ru --size 1280x960 --scale 1
```

Открывается нативное окно. Агентам нужен [изолированный display wrapper](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/isd.md), а не основной desktop.
