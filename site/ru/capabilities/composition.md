# Вложенная композиция {#composition}

Панели собираются из владеемых слотов в фиксированном порядке заголовок, содержимое и подвал. Нативный пример вкладывает дочернюю кнопку в составную родительскую; активация дочерней записывает намерение в родительском маршруте, пока не включён Stop, а строка счётчиков показывает, что записала каждая активация. Присутствие элементов, счётчики и эффект принадлежат приложению.

![Страница showcase: составная родительская кнопка с вложенной дочерней, счётчики parent=0 и child=0, Stop включён.](/media/composition-ru-initial.png)

Native showcase: композиция, интерфейс RU; начальное состояние, Stop включён.

![Та же страница при выключенном Stop после одной активации дочерней кнопки; счётчики parent=1 и child=1.](/media/composition-ru-propagated.png)

Native showcase: композиция, интерфейс RU; активация дочерней кнопки распространена на родительскую.

## Границы и пакеты {#boundaries}

Механизм экспериментальный. Callbacks записывают намерения, без reentry, а дерево панелей — это описание до layout: у него нет собственного publication stamp, dispatch, clock или владельца фокуса, и приложение само связывает тексты и интерактивные описания с ID узлов. Выбранные пакеты: `ui_composition`, `ui_base`, `ui_layout`, `ui_interaction` и `ui_style`; полный showcase использует больше пакетов и ресурсов.

## Исходники и нативный пример {#source}

Ссылки закреплены за `8bc09cff358aa629410437996520283ff98d77d9`: [пример showcase](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/sections/composition.odin), [каталог](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/catalogue.odin), [README пакета](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/kit/ui_composition/README.md), [рецепты](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md) и [ресурсы](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md).

В подготовленном native checkout/export с документированными Odin, SDL3, SDL3_ttf, libpng и zlib:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section composition --locale ru --size 1280x960 --scale 1
```

Активируйте дочернюю кнопку клавишей Enter, затем переключите Stop и активируйте снова, чтобы увидеть запись намерения в родительском маршруте; «Удалить дочернюю» и «Вернуть дочернюю» меняют вложенную структуру.
