# Controlled components — experimental headless API

Последующий [selected composed-input вклад](../../tests/ui_navigation/selected_input/README.md)
и [slider SDL adapter](sdl/README.md) связывают native paths отдельно от этого
headless результата; layered renderer остаётся pending, не подтверждённым здесь.

`import controls "ui:ui_controls"`, `-collection:ui=<kit-root>`; в репозитории
kit-root — `kit/`. Прямые зависимости: base/layout/interaction/layers/scroll/
style/text. Полный физический closure: `ui_base`, `ui_layout`, `ui_interaction`,
`ui_layers`, `ui_scroll`, `ui_style`, `ui_text`, `unicode_graphemes`, `ui_controls`.
Нет SDL, hold/editor/gestures/custom/collections, tools, переводов или ресурсов Slyx.

Это завершённый headless-вклад кандидата `slyx-iv1.1.2`, **до независимого ревью
и интеграции**, не завершение всей задачи/F1. Основа — R1/D1 и R1-A1/D1-A1 по
[исходным решениям](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/docs/specs/slyx-iv1.1/spec.md). SDL input/render composition,
реальная графика и дальнейшие optional-family combinations проверяются отдельно.

## Модель, bindings и подготовка

`Description` хранит stable control/node/item IDs и заимствованные на вызов
локализованные label/on_text/off_text/body/disabled_reason. Значимое состояние
`checked`, integer value/range/grid, `selected_id`, `open` принадлежит приложению.
Пустой selected ID означает none, не первый item. Язык/позиция не меняют identity.

Поддерживаются Checkbox, Toggle, Slider, Select, Tabs, List, Tooltip, Dialog.
Slider использует i128 intermediate arithmetic, конечную i64 range/grid, exact
Set_Value без rounding и Adjust -1/+1 с clamp. `track_id` — non-button descendant;
auxiliary +/- targets не обходят guard владельца. Select проверяет popup root,
owner scope, return focus и соответствие open/visibility. Dialog проверяет modal
root/initial focus/cancel policy и объявленный cancel item. Tooltip проверяет
overlay/trigger binding; Tabs/List/Select/Dialog — ancestry и item ownership.
Каждый binding имеет одного control owner; targets, требующие exclusive family
completion (например hold), отвергаются `Duplicate_Ownership`.

`prepare(&interaction_frame,layers_plan,descriptions,allocator,geometry=nil)`
возвращает `(Candidate,Error)` с owning descriptions/items/scope и frozen gates.
Для structural/non-interactive owners передайте geometry **того же stamp**:
она даёт enabled/visible gate без превращения контейнера в focus/activation target.
Без geometry отсутствующий structural action gate остаётся `Invalid_Action`;
это не скрытый focus manager или восстановление недоступного интерфейса.
Frozen modal/overlay refusals остаются общими interaction codes.

Prepare проверяет metadata/roles/ranges/items/namespace/layer/track/auxiliary
bindings до публикации. Unknown bindings, несовместимые ownership и values
отклоняются адресно; mixed geometry stamp — `Stale`. Prepare не меняет live State,
application model, focus, registrations или published frame. Полная partition/
transition validation Layers остаётся у `layers.prepare`; controls её не заменяет.

`create()` / `destroy(&state)` владеют только immutable published metadata.
`validate_candidate(&publication,&candidate)` проверяет общую association;
`commit(&state,&candidate)` — infallible ownership move только внутри проверенного
typed publisher. Candidate обнуляется, предыдущий frame освобождается. Begin attempt,
fallible readers/precommit, enter_commit, swaps выбранных owners, finish_commit,
затем registration reconciliation — обязанности **одного** typed publisher.
Не публикуйте новую interaction рядом со старой controls projection.

## Семантический ввод и наблюдение

`dispatch(&state,&interaction,Action,layer_state=nil,scroll_state=nil)` возвращает
`Result{dispatch,event,cancel}` — UI-намерение, не применённый reducer outcome.
Общие readiness/source/availability guards выполняются до value validation;
historical/wrong-stamp family не dispatches. После technical/application mutation
нужен rebuild. Source отказа и UI sequence едины с общим interaction owner.

- Focus/Navigate используют существующий общий navigator/routed dispatcher.
- Activate Checkbox/Toggle предлагает Bool; items — Item; Dialog items — Result.
- Slider Adjust/Set_Value и +/- предлагают Integer только при изменении value;
  underlying activation/sequence остаётся единичным даже на границе range.
- Select owner Activate предлагает Open/Close. Cancel сначала рассматривает
  открытый Select **активного scope**, независимо от позиции Dialog в descriptors.
  Его отказ не проваливается в отмену содержащего Dialog.
- Dialog Cancel допускает только объявленный доступный cancel item и использует
  переданный **реальный выбранный** `layers.State`/его общий Cancel sequence.
  Если Dialog control не владеет отменой, сохраняется обычный layer cancel.
- `Result.cancel` сохраняет underlying layer cancel; при наличии `event` это
  та же самая intention, не второй application effect.
- List Move_Item явно использует переданный `ui_scroll.State`: focus/reveal
  commits при rebuild, selection не меняется. Без этого owner — explicit refusal.
  Move_Left/Move_Right здесь отклоняются; virtual collection/grid navigation не
  включается молча и принадлежит отдельному будущему выбранному семейству.

`inspect_control(&frame,id)` возвращает borrowed View: description, role,
availability и actions. Роли: checkbox/switch/slider/combobox/tablist/list/tooltip/
dialog. Недоступный control не рекламирует actions. Container actions адресуются
его объявленным item targets, а не создают новую semantic кнопку контейнера.

`tooltip_for_controls(&frame,&interaction_frame,focus_id,hover_id)` — чистый
read-only выбор активного overlay: доступный focus имеет приоритет над hover
независимо от descriptor order, только в активном scope и на общем stamp.
Tooltip никогда не берёт focus/input. Host явно обновляет выбранный layer plan.

## Owning recipes

```odin
recipe, error := controls.compose_control(description, "base", "root", allocator,
    font = {"my-font"}, font_size = 16)
// inspect error; append typed arrays to this consumer's explicit composition
defer controls.destroy_composition(&recipe)
```

После allocator доступны optional `enabled=true`, `visible=true`,
`font={"default"}`, `font_size=16`. Font ID/size — metadata для внешних metrics,
не font loader. Recipe не содержит SDL handles или глобального theme/profile.

Composition владеет клонированным `control`, ordinary `nodes`, `targets`, `styles`,
`texts`, scroll descriptions, generated text/IDs/font declarations и optional
popup/tooltip/modal descriptions. Массивы стилей/текста/layer/scroll descriptions
заимствуют **внутреннюю owning storage Composition**, не временные входы. Они
живут до destroy Composition; owning frames нужно подготовить/скопировать до него.
Присваивание Composition не копирует владение. Пользовательские ресурсы и metrics
заимствуются только во время их собственного prepare.

Root/part IDs детерминированы; `item_node_id(namespace,item,allocator)` возвращает
`(owned_string,bool)` с length-prefixed encoding, не зависящим от порядка/перевода.
List включает обычный fixed viewport + natural Column, не новую UI tree.
Slider имеет отдельные 120×10 track, rail, thumb и auxiliary buttons; label/owner
width не подменяют track. Bool recipes используют различимый `[ ]`/`[x]` marker.
Items передают Selected appearance из controlled selected_id без изменения input.

Recipe предлагает typed descriptions; host вызывает один text/layout solver,
выбранные scroll/layers stages и final interaction/style prepare. Не создавайте
второй normalizer, focus manager или umbrella runtime. Для cross-family ownership
host явно объединяет `Capture_Claim{target.id,"controls"}` выбранных recipe targets
с claims других выбранных owners; общий interaction отказывает конфликту.
Scroll/transition geometry для render/text/hit связывается явной frozen projection,
не повторным layout solver или копией чужого алгоритма. Renderer integration не
объявляется выполненной этим headless package.

## Копии, ошибки и lifecycle

`try_copy_frame(&frame,allocator) -> (Frame,bool)` независимо клонирует все
description/item/label/scope strings, arrays и frozen gates, удерживает stamp.
Reader переживает destroy исходных State/Composition/layout/interaction/publication;
allocator живёт дольше reader. Geometry/text/style readers копируются отдельно
выбранным bundle. Historical reader не разрешает current dispatch/snapshot.

Allocator отказ возвращает `Allocation`/false без fallback и partial success;
частичные clones/recipe vectors/fonts metadata освобождаются. `Error.control_id`
и `node_id` заимствуют input, не уничтоженный candidate. Для сохранения:
`base.try_copy_error(controls.describe_error(error),allocator)`, затем
`base.destroy_error`. Family Controls, stage по умолчанию Prepare; node ID имеет
приоритет адреса, иначе control ID. Dispatch refusals используют общий Code.

Handlers/disposal принадлежат общему interaction. Dispose вызывается только после
согласованного successful swap выбранных owners; failure не снимает регистрации.
Callbacks read-only/record intention, без reentry/reducer/prepare/commit. Recovery
строит уже принятую модель, а не повторяет Bool/Integer/Item intention.

## Проверки, imports и миграция

```sh
odin test kit/ui_controls -vet -vet-style -vet-tabs -vet-semicolon -out:<fresh-tests>
odin build tests/ui_navigation/controls_only -collection:ui=kit -show-import-graph -out:<fresh-fixture>
```

[`controls_only`](../../tests/ui_navigation/controls_only/main.odin) показывает
typed prepare → owning reader/precommit → infallible swap → one application Bool
effect → ru rebuild → destroy, с собственными en/ru строками и fake metrics.
Это headless consumer, не доказательство pixels/реального шрифта/SDL поведения.
Физический внешний kit использует только девять каталогов выше, без symlinks.
Framework, Python, Slyx checkout/assets/RIS не являются runtime dependencies.

Package tests сохраняют применимые прежние controls/control_composition oracle:
восемь kinds/real text-layout-layer bindings, controlled proposals и exact grid,
aux owner gates, namespace/selection/reorder boundaries, Select cancel priority,
declared Dialog result/cancel, tooltip focus-before-hover/scope, List→scroll focus,
popup focus return, routed disposal/coherent swap, stale/refusal/recovery/readers.
Проверены 214 recipe backing allocation позиций по восьми kinds, 20 prepare и
20 copy позиций, 64 rebuild без live growth и cleanup до zero live.

Linux x86_64, Odin `dev-2026-10-nightly:84bc3fc`, Normal scale=1, locale=en/ru,
fake font metrics: fixture cumulative allocations/bytes/live/peak наблюдались как
init `1/32/32/32`, en published+reader `130/33208/8605/24663`, ru rebuilt+reader
`259/66484/8645/33316`, destroy `259/66484/0/33316`. State=96, Frame=96,
Composition=760 bytes; общие Publication=72 и interaction Context=216.
Цифры включают выбранные layout/text/style/layers/ID/reader costs и fixture,
не только controls; peak отдельного refusal fixture=6471 bytes. Собственные
handlers/backend resources controls=0. Driver/GPU memory и SLA не заявляются.

Прежние `kit/ui/controls.odin` и `control_composition.odin` удалены, compatibility
facade не добавлен. Historical tests/docs и старые examples могут ссылаться на
удалённый монолит согласно R1-A1/D1-A1; их сборка не восстанавливается здесь.
Оставшиеся collection/custom/transition/SDL/tool adapters не превращены в скрытую
зависимость и остаются отдельной интеграцией. Enum ordinals нового API не являются
старыми wire codes. Вся задача `slyx-iv1.1.2` этим вкладом не закрывается.
