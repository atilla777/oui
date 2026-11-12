# Оформление {#styling}

Нативный showcase показывает существующие фигуры, изображение и панель роли с
токеном темы и визуальными состояниями. «Тема» меняет акцент с синего на
фиолетовый; «Выбор» и «Недоступность» меняют состояние примера, последнее также
отключает счётчик. «Нет ресурса» показывает fallback. Это действия showcase,
а не редактор тем.

![Нативная палитра оформления с синим акцентом и кнопками состояний.](/media/styling-ru-initial.png)

Нативное оформление, интерфейс RU; исходная синяя тема.

![Нативная палитра с фиолетовым акцентом после нажатия «Тема».](/media/styling-ru-changed.png)

Нативное оформление, интерфейс RU; тема переключена.

## Границы и пакеты {#boundaries}

Пример сочетает объявления роли, именованный стиль и локальные переопределения.
Токен акцента задаёт обычный фон роли; именованный стиль — границу и параметры
фокуса; локально заданы радиус и фон первой фигуры. Для выбранного, наведённого,
нажатого, сфокусированного и недоступного состояний заданы цвета роли.
Показаны только существующие примитивы и каскад темы; API экспериментален.
Выберите `ui_style` с `ui_base` и `ui_layout`; интерактивный текст и отрисовка
showcase требуют дополнительных пакетов и нативных зависимостей.

Resolver начинает со значений по умолчанию, затем применяет роль, именованный
стиль и локальные объявления; последующие переопределяют предыдущие по свойству.
На каждом уровне применяются Normal, Selected, Hovered, Pressed, Focused и затем
Disabled, если состояние активно. Disabled подавляет Hovered и Pressed. Отсутствие
именованного стиля или токена отмечается как fallback, а не задаёт новое значение.

## Исходники и нативный пример {#source}

Ревизия `4da8d7a57bd2453227a4c37df6b0b4d171401681`:
[пример](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/sections/content.odin#L319),
[модель](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/model/model.odin),
[исходник style](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/kit/ui_style/style.odin) и
[ресурсы](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md).
В подготовленном checkout или export с документированными Odin, SDL3, SDL3_ttf,
libpng и zlib:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section styling --locale ru --size 1280x960 --scale 1
```

Это нативное окно. Агенты используют [изолированную обёртку](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/isd.md).
