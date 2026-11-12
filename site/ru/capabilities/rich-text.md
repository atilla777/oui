# Форматированный текст {#rich-text}

Нативный showcase выводит локализованную карточку с вложенным выделением и
цветом, размером, курсивом и подчёркиванием, встроенным изображением и примером
запасного шрифта. Следующий элемент остаётся после абзаца. Кнопка переключает
карточку в одну строку с многоточием; другой пример уже показывает этот режим.

![Нативная карточка форматированного текста на русском со стилями и встроенным изображением.](/media/rich-text-ru-initial.png)

Русская карточка в начальном состоянии на указанной ревизии.

![Нативная русская карточка после выбора одной строки с многоточием.](/media/rich-text-ru-alternate.png)

Та же карточка после выбора ограничения в одну строку.

## Границы и пакеты {#boundaries}

Форматированный текст экспериментален. Ограниченная грамматика включает
используемые в примере формы `[b]`, `[i]`, `[u]`, `[color]`, `[size]` и `[img]`;
это не HTML и не редактируемый rich-text редактор. Действуют текстовые лимиты
65 536 байт и 4096 строк; shaping и bidi не обещаются. Пример использует
`ui_rich`, `ui_text`, `ui_style`, `ui_layout`, `ui_base` и `unicode_graphemes`,
SDL-адаптер, основной и запасной шрифты и ресурсы атласа showcase. Покрытие
зависит от шрифтов; запасной шрифт не содержит все возможные символы.

## Исходный код и нативный пример {#source}

[Локализованный пример](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/sections/content.odin),
[пакет rich](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/kit/ui_rich/README.md)
и [требования к ресурсам](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md) закреплены за ревизией снимка.
В подготовленном нативном checkout/export с Odin, SDL3, SDL3_ttf, libpng и zlib:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section rich-text --locale ru --size 1280x960 --scale 1
```

Команда открывает нативное окно. Агенты используют [изолированную обёртку](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/isd.md), а не основной рабочий стол.
