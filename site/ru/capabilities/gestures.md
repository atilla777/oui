# Жесты {#gestures}

Нативный пример жестов показывает две панели карточек с кнопками повторной прокрутки, обрезанными строками по 48 пикселей, ручкой прокрутки и заголовком-целью на каждой панели. Нажатие на карточку начинает перетаскивание; пока кнопка удерживается, пример сообщает предложение и помечает заголовок панели под указателем как «Перенос: разрешён». Карточка при этом остаётся в исходной панели. Приложение применяет один перенос только после отпускания; инерции и автоматического повторения переноса нет.

![Две панели по шесть карточек, кнопки повторной прокрутки, ручки прокрутки и черновик имени в фокусе.](/media/gestures-ru-initial.png)

Нативные жесты: обе панели по шесть карточек, интерфейс RU.

![Карточка удерживается над заголовком правой панели с надписью «Перенос: разрешён», но остаётся в левой панели.](/media/gestures-ru-proposal.png)

Нативные жесты: предложение при ещё нажатой кнопке мыши, интерфейс RU.

![После отпускания левая панель начинается с card-02, а правая панель содержит перенесённую карточку.](/media/gestures-ru-applied.png)

Нативные жесты: приложение применило перенос после отпускания, интерфейс RU.

## Границы и пакеты {#boundaries}

Механизм экспериментальный: предложение не является применённым переносом, и отпускание применяет не более одного изменения состава. Запросы из той же панели, устаревшие, повторные или недоступные отклоняются без перемещения карточки; за указателем не следует инерция. Путь жестов импортирует `ui_gestures` и `ui_gestures/sdl` вместе с `ui_base`, `ui_layout`, `ui_interaction`, `ui_scroll` и `ui_sdl`; showcase добавляет собственные семейства вывода и текста. Полный showcase значительно шире.

## Исходники и нативный пример {#source}

Ссылки закреплены за `8bc09cff358aa629410437996520283ff98d77d9`: [пример showcase](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/sections/gestures.odin), [среда выполнения жестов](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/gesture_runtime.odin), [модель-редьюсер](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/gestures_demo/model/model.odin), [каталог](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/catalogue.odin), [рецепты](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md) и [ресурсы](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md).

В подготовленном native checkout/export с документированными Odin, SDL3, SDL3_ttf, libpng и zlib:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section gestures --locale ru --size 1280x960 --scale 1
```

Нажмите на карточку, переведите указатель на заголовок другой панели до надписи «Перенос: разрешён» и отпустите. Используйте -24 или +24 либо перетащите ручку прокрутки, чтобы прокрутить обрезанные строки.