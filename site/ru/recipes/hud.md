# Рецепт HUD {#hud-recipe}

Рецепт HUD — узкая композиция для HUD с восстановлением удержанием: области панели и подсказки из layers, порог 1000 мс из hold и учебный HP, которым владеет приложение. Это не экран Lab. [Лаборатория HUD](../lab/hud) — более широкий экран showcase с полной оболочкой, строками и ресурсами атласа.

## Замыкание зависимостей {#dependency-closure}

Прямые выбранные импорты — `ui_layers`, `ui_hold` и `ui_hold/sdl`, а также `ui_base`, `ui_layout`, `ui_interaction`, `ui_style`, `ui_text`, `ui_sdl` и `ui_sdl_text`; единственное транзитивное добавление — Unicode через text.

| Импорт | Роль |
| --- | --- |
| `ui_layers` | Модальные области, панели и подсказки; разделы и доступность готовятся до привязки удержания. |
| `ui_hold` | Состояния удержания, порог 1000 мс, прогресс и завершения. |
| `ui_hold/sdl` | Нормализует физические события SDL в намерения удержания для кнопки восстановления в фокусе. |
| `ui_base` | Публикация, ревизии, последовательности и примитивы владеющих копий. |
| `ui_layout` | Детерминированная геометрия для ограниченного примера. |
| `ui_interaction` | Маршрутизация, фокус и исключительные захваты. |
| `ui_style` | Метаданные отрисовки для составленных блоков. |
| `ui_text` | Подготовка текста для подписей. |
| `ui_sdl` | Нативное окно, рендерер и приём событий. |
| `ui_sdl_text` | Генерация шрифта SDL3_ttf для переданного шрифта. |
| `unicode_graphemes` | Транзитивная сегментация Unicode, используемая text. |

Рецепту не нужны `ui_controls`, `ui_editor`, `ui_collections`, `ui_gestures`, `ui_rich`, `ui_custom`, `ui_transitions`, translations, `ui_inspect`, `ui_wire` и `ui_debug`. Загрузчика атласа здесь нет, поэтому самому рецепту HUD не нужны libpng и zlib.

## Владение и ресурсы {#ownership-and-resources}

Приложению принадлежат HP, счётчик удержаний и эффект: kit сообщает прогресс и одно завершение, а вызывающий применяет восстановление и пересобирает состояние. Приложение также передаёт шрифт и свои строки и решает содержимое панели и подсказки. Готовьте кандидаты, захваты и владеющие копии до барьера commit; восстановление пересобирает принятую модель без повтора эффекта или удерживаемого ввода.

Обычный Activate не обходит удержание, неполное удержание не даёт эффекта, панель экранирует удержание, а потеря фокуса отменяет начатое удержание. Один новый цикл 1000 мс даёт не более одного завершения.

## Сборка и запуск {#build-and-run}

В подготовленном native checkout/export с Odin, SDL3 и SDL3_ttf (рецепт HUD не линкует кодеки изображений):

```sh
mkdir -p build
odin build tests/ui_recipes/hud/native -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon -out:build/hud-recipe
build/hud-recipe --font resources/font.ttf --locale en --size 800x600 --scale 1
# Или для русского:
build/hud-recipe --font resources/font.ttf --locale ru --size 800x600 --scale 1
```

Этот пример открывает нативное окно. Нажмите F11, чтобы выполнить ограниченный сценарий проверки; он печатает `native-hud=ok threshold=999+1 loss=cancel failure=not-ready recovery=no-replay input=native-synthetic`. F12 завершает работу. Обычные пользователи запускают его в собственной графической сессии; агенты обязаны использовать изолированную обёртку дисплея, описанную в [документе ISD](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/isd.md).

## Проверка {#verification}

Ограниченный пример композиции и нативный пример проверены на указанной ревизии с флагами vet выше и `-define:ODIN_TEST_THREADS=1`:

```sh
odin build tests/ui_recipes/hud -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon -out:build/hud-recipe-headless
build/hud-recipe-headless
# recipe-hud effects=1 conflicts=1 live=0

odin test tests/ui_recipes/hud/native -collection:ui=kit -define:ODIN_TEST_THREADS=1 -vet -vet-style -vet-tabs -vet-semicolon
# Finished 1 test; the test was successful.

odin test kit/ui_hold -collection:ui=kit -define:ODIN_TEST_THREADS=1 -vet -vet-style -vet-tabs -vet-semicolon
# Finished 20 tests; all tests were successful.

odin test kit/ui_hold/sdl -collection:ui=kit -define:ODIN_TEST_THREADS=1 -vet -vet-style -vet-tabs -vet-semicolon
# Finished 4 tests; all tests were successful.

odin test kit/ui_layers -collection:ui=kit -define:ODIN_TEST_THREADS=1 -vet -vet-style -vet-tabs -vet-semicolon
# Finished 24 tests; all tests were successful.
```

Ограниченный пример проверяет порог 999+1 мс, один эффект приложения, отклонённый обычный Activate, отклонённого конфликтующего владельца, `Not_Ready` после инвалидации, восстановление без повтора и нулевую живую память tracking allocator. Нативный пример использует настоящее окно SDL и синтетические события клавиш; он не заменяет полную нативную приёмку.

## Исходники {#runtime-sources}

Ссылки закреплены за `8bc09cff358aa629410437996520283ff98d77d9`: [ограниченный пример](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/tests/ui_recipes/hud/main.odin), [нативный пример](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/tests/ui_recipes/hud/native/main.odin), [рабочий цикл](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/tests/ui_recipes/hud/native/cycle.odin), [тест цикла](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/tests/ui_recipes/hud/native/cycle_test.odin), [поддержка нативного примера](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/tests/ui_recipes/native_fixture/fixture.odin), [композиция Lab HUD](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/app/lab_hud.odin), [метаданные каталога](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/consumer/ui_showcase/model/catalogue.odin), [рецепты](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/recipes.md#3-hud) и [ресурсы](https://github.com/atilla777/oui/blob/8bc09cff358aa629410437996520283ff98d77d9/docs/resources.md).

См. [Лаборатория HUD](../lab/hud), [HUD и удержание](../capabilities/hud) и [Использование oui](../guide/using-oui) — экран, его границу и карту пакетов.