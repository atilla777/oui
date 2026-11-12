# Профили {#profiles}

Нативный showcase объединяет элементы управления в примере настроек профиля.
Выберите один из трёх примеров, измените черновик и сравните его статус с
применёнными значениями. Элементы и состояние принадлежат нативному приложению,
а не браузерной реализации.

![Элементы профилей и применённые настройки Aurora.](/media/profiles-ru-initial.png)

Начальный профиль Aurora, интерфейс RU. Статус — «Применено».

![Диалог предлагает применить, отменить изменения или остаться в изменённом профиле Aurora.](/media/profiles-ru-dialog.png)

После изменения подсказок и выбора Borealis нативный диалог предлагает применить,
отменить изменения или остаться; черновик ещё не применён.

![Профиль Aurora с выключенными подсказками и статусом «Применено».](/media/profiles-ru-applied.png)

В отдельном запуске подсказки выключили и нажали «Применить». Aurora остаётся
выбранным, флажок снят, а статус теперь — «Применено».

## Работа с настройками {#workflow}

Измените подсказки, включение, интенсивность (0–100) или режим на вкладке
«Оформление». «Применить» копирует черновик в применённые значения выбранного
профиля; «Отмена» восстанавливает черновик из них. При смене профиля с
неприменёнными изменениями предлагается применить, отменить их или остаться.
«Сбросить» запрашивает подтверждение и возвращает черновику исходные значения
профиля; чтобы изменить применённые значения, нажмите «Применить» отдельно.

## Границы и пакеты {#boundaries}

Это экспериментальный пример с тремя фиксированными профилями. Применённые
значения хранятся только в памяти, не на диске. Недоступный элемент намеренный.
Композиция использует `ui_controls`, компоновку `ui_layout` и взаимодействие
`ui_interaction`; всему showcase нужны дополнительные пакеты, SDL и ресурсы.
Состоянием и решениями профиля владеет приложение-потребитель.

## Исходники и нативный пример {#source}

Исходники на ревизии `4da8d7a57bd2453227a4c37df6b0b4d171401681`:
[композиция элементов](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/sections/profiles.odin),
[модель профилей](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/controls_demo/model/model.odin),
[showcase](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/consumer/ui_showcase/README.md),
[ресурсы](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/resources.md).

В подготовленном checkout или export с Odin, SDL3, SDL3_ttf, libpng и zlib:

```sh
mkdir -p build
odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase
build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section profiles --locale ru --size 1280x960 --scale 1
```

Откроется нативное окно. Агентам нужен [изолированный display wrapper](https://github.com/atilla777/oui/blob/4da8d7a57bd2453227a4c37df6b0b4d171401681/docs/isd.md), не основной рабочий стол.
