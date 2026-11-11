# Layers — experimental headless API

`import layers "ui:ui_layers"`, `-collection:ui=<kit-root>`; в репозитории — `kit/`.
Минимальный physical closure: `ui_base`, `ui_layout`, `ui_interaction`, `ui_layers`.
Только Odin core; нет SDL, fonts/text/style resources, hold/scroll/controls,
редактора/gestures/tools, переводов, assets, RIS или runtime Python.

Кандидат `slyx-iv1.1.2`, R1/D1 и R1-A1/D1-A1
([источник решений](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/docs/specs/slyx-iv1.1/spec.md)). Завершённый headless
layers-вклад **до независимого ревью/интеграции**; не завершение всей задачи,
не приёмка F1 и не доказательство full SDL combinations или pixels.
Прежний `kit/ui/layers.odin` удалён без compatibility facade/дублирования solver;
historical tests сохранены как semantic oracles, не как текущий build target.

## Partition, scope и order

`Layers{base_root_id,modals,popups,tooltips}` заимствует IDs/slices на prepare.
Base, modal, popup и tooltip roots — различные immediate children одного
root Stack/Absolute без parent; каждый его непосредственный ребёнок объявляется
ровно один раз. Roots и physical common root не являются Button targets.
Layout ancestry не переписывается; synthetic parents/node tree не создаются.

Modals задают ordered stack; верхний modal — активный scope. Пустой scope ID
означает base, **не** base_root_id. Owner popup/tooltip — base или объявленный
modal, не popup/tooltip/self. Modals должны быть visible+enabled. Tooltip
subtree не может содержать input targets, даже disabled/hidden; его projected
interaction availability — Non_Interactive_Overlay, не дополнительный focus stop.

Переходы: сохранить префикс modal roots; push максимум одного нового modal,
pop одного/нескольких, сохранить depth. Замена существующего root, смена base
или скачок push на несколько уровней отклоняются Invalid_Transition. Изменение
initial/cancel metadata существующего modal само по себе не переоткрывает его.
Partition errors проверяются раньше transition errors, как в прежнем oracle.

Paint order каждого scope: main subtree → popups в descriptor order → tooltips
в descriptor order. Перед каждым modal добавляется Scrim. Subtree emits Draw_Node
в DFS и Draw_Focus после descendants. `Paint.node_index` / `Group.root_index`
адресуют **ту же owning layout projection**, не переупорядоченный interaction
array. Common physical root не рисуется. Draw здесь — план, не renderer call.

## Prepare, focus и capture

`create(allocator)` / `destroy(&state)` владеют published metadata; State не имеет
своих focus manager, clocks, handlers или application model.

`prepare(&state,&interaction_context,&geometry,targets,claims,plan,allocator)`
возвращает `(Candidate,Error)`. Candidate владеет descriptions/return IDs/paint/
groups, новым interaction frame и snapshots исходных hover/press. Его выбранные
focus/hover/press IDs заимствуют candidate interaction storage; origin Context
заимствуется до validate/commit. Geometry нужна только на вызов и затем отдельно
renderer/hit consumer; сам layer Frame не владеет её nodes.

Prepare не меняет live owners/model/registrations. Один publisher начинает attempt,
готовит geometry/выбранные families, copies и precommit, затем проверяет общий
stamp/ownership через `validate_candidate(&publication,&candidate)`. Origin должен
принадлежать этой publication; hover/press loss после prepare делает candidate
невалидным. Нельзя resurrect captures из stale projection.

`base.enter_commit` → `layers.commit(&state,&interaction,&candidate)` → прочие
явно выбранные swaps → `base.finish_commit` → registration reconciliation.
Commit — infallible move нового interaction+layers, установка согласованного
focus/hover/press и освобождение прежних frames; candidate обнуляется. Callbacks
только после всех выбранных swaps. Нет family registry или другого publication owner.

Opening modal требует доступный initial focus **в его main subtree**, не popup
и не другой scope. Return ID клонируется из прежнего focus. Push выбирает initial;
pop восстанавливает соответствующий return. Missing/disabled return fallback —
первый доступный main button активного scope, затем popups в descriptor order.
В неизменном scope доступный выбранный ID сохраняется; отсутствие доступных
buttons очищает focus, но не запрещает later recovery и не требует initial заново.

Закрытие/скрытие/disable popup возвращает его explicit return_focus_id только
в owner scope, иначе тот же main-first fallback. Navigation использует единственный
interaction algorithm с frozen layer order, не физический sibling order.
Scope depth или popup order/owner change очищает hover/press; в том же порядке
сохраняются только доступные IDs. Claims передаются общему interaction arbitration;
несовместимые двойные owners отклоняются, скрытая capture-система не вводится.

## Semantic input, hit и routing

`dispatch(&state,&interaction,Action)` возвращает `Result{dispatch,cancel}`.
Общие readiness/source guards выполняются первыми; wrong-stamp State даёт
Not_Ready. Focus/Navigate/Activate идут через общий routed dispatcher. Disabled/
Not_Visible сохраняют приоритет перед Blocked_By_Modal; вне активного scope нет
activation/focus. Missing ID — Not_Found; недопустимый source/action — Invalid_Action.

Cancel адресует только верхний modal при cancel_allowed, выдаёт один
`Cancel_Requested{root_id,source,sequence}`, не закрывает modal/model сам.
Cancel не создаёт Button_Activated и не маршрутизирует второй callback effect.
Отказ cancel policy сохраняет ready; успешное намерение требует rebuild.
Common sequence exhaustion возвращает Exhausted, не wrap, и блокирует ready.
Host применяет intent ровно один раз; recovery не replay reducer/event.

Routed delivery идёт target→ancestors и заканчивается на **выбранном layer root**,
не переходит на physical common root или соседний scope. Stop прекращает route.
Handlers/dispose принадлежат interaction; callbacks read-only/record intention,
без reentry, prepare/commit/reducer/registration mutations. Failed prepare не
снимает регистрации; removal/role/kind change после successful coherent swap
вызывает dispose один раз. Disabled/hidden сами по себе не удаляют регистрацию.

`hit_test(&layers_frame,&geometry,&interaction_frame,drawable_x,drawable_y)`
требует одинаковые stamps и положительный ui_scale. Reverse group order;
tooltip не принимает hit и не shields. Popup visible body+paint clip shields
нижние groups даже без доступного target; hidden popup не shields. Rect bounds
half-open, учитываются scale, bounds и clip. Пользуйтесь **этим** выбранным hit
owner для layered physical input: plain `interaction.hit_test` не знает popup
shield. SDL normalization/specialization/dispatch integration остаётся отдельно.

## Readers, failures и диагностика

`try_copy_frame(&frame,allocator) -> (Frame,bool)` клонирует все descriptions,
return IDs, paint/groups и удерживает lifetime stamp. Reader переживает исходные
State/Context/Publication, но historical reader не разрешает current input.
Geometry/interaction/text/style readers копируются отдельно explicit bundle;
индексы paint остаются применимыми только к matched layout projection.
Allocator живёт дольше owners. Простое присваивание не копирует владение.

Отказ не возвращает partial success; candidate/copy owners очищаются. Ошибки:
Invalid_Layers, Invalid_Transition, Allocation, Interaction с underlying Code.
`Error.id` заимствует input/geometry ID; для сохранения используйте
`base.try_copy_error(layers.describe_error(error),allocator)` и destroy_error.
Family.Layers, stage по умолчанию Prepare, existing_code хранит interaction code.
Failed publication сохраняет published owners/returns/registrations, ready=false;
renderer/native failure также должен явно блокировать ready и свой clock baseline.

## Проверяемые границы и accounting

```sh
odin test kit/ui_layers -vet -vet-style -vet-tabs -vet-semicolon -out:<fresh-tests>
odin build tests/ui_navigation/layers_only -collection:ui=kit -show-import-graph -out:<fresh-fixture>
```

[`layers_only`](../../tests/ui_navigation/layers_only/main.odin): физически
минимальный typed publisher, separate owning geometry/interaction/layers reader,
two-modal stack, popup shield/tooltip, routed activation, два controlled Cancel,
возврат focus, 64 rebuild без live growth, reader после runtime destroy; scale=2.
Проверяется внешний kit ровно из четырёх каталогов без symlinks и source drift.

23 package tests покрывают depth-three transition/return matrix, opening versus
same-scope fallback/empty/recovery, exact partition errors, all-source top Cancel,
policy/stale/source/exhaustion guards, descriptor navigation/reorder capture loss,
popup hide/disable/return/shield/half-open hit, tooltip non-input, route/Stop/
reentry/dispose, cancellation-staleness, wrong publication, owning readers/errors.
21 базовая и 47 expanded prepare backing allocation-позиций, 15 expanded copy
позиций, retention/cleanup до zero live; 64 stable rebuild плюс 32 open/fault/pop
цикла без накопления истории. Автоматического подключения семейств нет.

Linux x86_64, Odin `dev-2026-10-nightly:84bc3fc`: fixture State=208, Frame=208,
Candidate=384 bytes; cumulative allocations=3568, bytes=723650, live=3794,
peak=33733 с matched reader+одной registration после 64 rebuild. Destroy live=0,
bad-frees=0. Expanded refusal fixture peak=4235 bytes. Учтены common/layout/
interaction/fixture/readers, не только layers; backend resources=0. SLA/GPU memory
не заявляются. Не подтверждены pixels/fonts, SDL event composition, полные
layered text/scroll/hold/transition/custom/editor/collection consumers. Их integration
не восстанавливается через прежний umbrella API и остаётся отдельным результатом.
