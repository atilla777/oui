# Текст {#text}

Нативный showcase выводит локализованный абзац с явными переводами строк,
пустой строкой, комбинируемыми знаками и неразрывными пробелами. Также показаны
перенос, обрезание, многоточие и выравнивание. Кнопка ключа выбирает короткую
локализованную строку; случай лимита меняет пример подсчёта графем у потребителя.

![Нативный раздел текста: русский абзац, примеры обрезания и многоточия.](/media/text-ru-initial.png)

Русский текстовый пример в начальном состоянии на указанной ревизии.

![Нативный раздел текста с выбранным коротким русским абзацем.](/media/text-ru-alternate.png)

Тот же пример после выбора короткого текстового ключа.

## Границы и пакеты {#boundaries}

Текст экспериментален и ограничен 65 536 байтами и 4096 строками. Shaping и
двунаправленная раскладка не поддерживаются. Отчёт примера считает расширенные
графемные кластеры Unicode 15.1; это пример потребителя, а не текстовый редактор.
Пример использует `translations`, `ui_text`, `ui_layout`, `ui_base` и
`unicode_graphemes`, а также SDL-отрисовку и шрифты showcase. Для своего
потребителя выбирайте только необходимые пакеты и ресурсы.

## Исходный код и нативный пример {#source}

[Локализованный пример](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/sections/content.odin),
[каталог](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/model/catalogue.odin)
и [требования к ресурсам](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md) закреплены за ревизией снимка.
В подготовленном нативном checkout/export с Odin, SDL3, SDL3_ttf, libpng и zlib:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section text --locale ru --size 1280x960 --scale 1
```

Команда открывает нативное окно. Агенты используют [изолированную обёртку](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/isd.md), а не основной рабочий стол.
