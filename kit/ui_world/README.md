# World anchors — experimental

В подготовленной ветке `task/slyx-iv1.1.6` на базе
`c73700fc27f6d0e2c0faa5ae5c974c0329ded8f3` helper переведён на
`ui_base.Rect/Extent`; изменение ожидает независимого ревью и интеграции.
Алгоритм и прежние пять behavioral fixtures не изменены.

SDL-free `ui_world` зависит только от core и `ui_base`. Он не хранит
якоря, camera, callback или user и не выделяет память. Камера и её revision,
world offset, world data и построение обычного дерева принадлежат приложению.

```odin
import world "ui:ui_world"

p, error := world.place_anchor(
    {id="enemy", world={20,30}, screen_offset={0,-12}, extent={112,48},
     pivot={.5,1}, policy=.Direction, indicator_extent={24,24}},
    {project=my_project, user=&frozen_camera}, viewport_px, ui_scale)
```

`Converter.project(world:[2]f64,user:rawptr)->([2]f64,bool)` возвращает абсолютные
drawable pixels, X вправо/Y вниз, вызывается один раз после валидации.
Description и user borrowed только на вызов. Callback чист относительно camera
snapshot. Размер/offset/pivot — logical, масштаб применяется только при
обычном layout. Не умножайте результат повторно на scale или camera zoom.
Viewport уже пересечён host с safe area/scene, целочисленные pixel edges внутри
drawable. Host проверяет его принадлежность drawable; resolver drawable не знает.

`Placement` — pointer-free value: `raw_screen`, logical `anchor/bounds`,
`visible/indicator/clamped`, `reason`, normalized `direction` (ноль для карточки).
Half-open membership исходной точки предшествует screen offset. Hide скрывает
внешнюю точку, внутри оставляет обычное размещение и viewport clip. Clamp
удерживает весь блок, включая случай внутренней точки с выходящей карточкой.
Direction снаружи заменяет карточку стрелкой у края, независимо от offset.
Empty/oversized selected extent → invisible `No_Space`, без shrinking.

При `Placement_Error.kind != .None` placement пуст: `Invalid_Input`,
`Projection_Failed`, `Unrepresentable`. Error ID borrowed из description, не
сохраняйте его после изменения входа. NaN/Inf, invalid enums/pivot/sizes/scale,
fractional viewport edges и непредставимая геометрия не становятся (0,0).

Создавайте обычный Absolute clipped viewport, children с offset
`p.bounds.origin - viewport.origin/scale`, fixed extent; hidden → visible=false.
Стрелка — обычный Box/Triangle с intrinsic extent; resolver не создаёт renderer,
input targets, transitions или автоматическое измерение дерева.

Для collection imports передайте `-collection:ui=<kit-root>`. Физический kit
для этого helper содержит только `ui_base/` и `ui_world/`: layout, interaction,
text/Unicode, SDL, inspector/debugger/testing adapters не требуются. Результат
встраивается приложением в выбранное layout-дерево; helper layout не создаёт.

Проверки:

```sh
odin test kit/ui_world
odin check kit/ui_world -no-entry-point -vet -vet-style -vet-tabs -vet-semicolon
odin run tests/ui_tools/world_only -collection:ui=kit
```

`world_only` — обычный headless consumer без собственного test runner.
Исторический [world_anchors_demo](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/examples/world_anchors_demo/README.md)
показывает прежний umbrella API и не является проверкой сборки нового API.
Его полная миграция не заявляется этим переносом helper.
