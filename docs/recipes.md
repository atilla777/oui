# Шесть выборочных recipes

Ниже base/layout/... означают `ui_base`/`ui_layout`/...; Unicode —
`unicode_graphemes`. Во всех runtime recipes app owns model, один physical Input,
interaction/focus/Publication; init→prepare/copies→commit→input/proposal→app outcome
→rebuild/publish→render→destroy описаны в [lifecycle](lifecycle.md).
Restricted snippets — обычный Odin: bounded headless typed publishers с real
claims, prepare/bind/validate, owning copies, shared commit, dispatch/outcome,
rebuild и destroy. Это не новые оконные приложения/generic build profiles.
HUD/inventory используют deterministic geometry, settings — fake text metrics;
SDL adapters/font types компилируются, но native resources/paint/event loop здесь
не запускаются. Connected render/input reference
исполняется отдельно в showcase с **большим union** всех gallery/Lab packages:
base/layout/interaction/style/text/Unicode, layers/scroll/controls/editor/rich/
collections/gestures/hold/custom/composition/world/transitions, SDL/text adapters,
selected inspect/accessibility/wire и consumer-only translations/atlas loader.
Tools дополнительно выбирает debug transport. Это не closure minimal screen.

## 1. Layout-only

Direct imports base/layout; transitive UI closure только base/layout. Никаких
interaction/text/Unicode/SDL/fonts/tools. Fixture:
`tests/ui_foundation/layout_only/main.odin`: begin attempt → layout.prepare →
owning copy/geometry assertions → destroy. Metrics только если Content требует
измерения. Invalid/duplicate geometry и allocator refusal не successful layout.

## 2. Basic menu

Direct selected imports base/layout/interaction/style/text/sdl/sdl_text;
transitive добавляет только Unicode. Свои строки и supplied primary font;
нет layers/controls/editor/collections/translations/inspection/tools/socket.
Полный executable `consumer/standalone_menu`, publisher `runtime.odin`, pure
reducer `model/`. Две кнопки main, отдельное submenu с language/back. SDL event
нормализуется один раз, interaction intention → checked model sequence → один
effect → rebuild/publish/render. Partial init, prepare/copy/resource/render faults
блокируют readiness; R строит принятую model без replay. Reader destroy до backend.

## 3. HUD

Direct selected imports layers/hold и hold/sdl + base/layout/interaction/style/
text/sdl/sdl_text; transitive Unicode. Нет controls/editor/collections/debug.
`tests/ui_recipes/hud/main.odin` реально публикует layers+hold с exclusive claim,
отклоняет conflicting owner и plain Activate, выполняет 999+1 ms → один app
effect, восстанавливает publication без replay и читает owning copy после destroy.
Reference
`--section lab-hud`: HP60/100, ±10 clamp, progress, popup/tooltip, hold1000ms.
Layers partition/availability готовится до hold binding; полный claim set до
commit, targets ±10 и hold раздельны. Один explicit time delta, 999ms+release
не effect, новый1000ms cycle — одно completion/outcome. Plain Activate не обходит
hold; popup shields/loss отменяют, render/recovery не начисляют время.

## 4. Settings

Direct selected imports layers/controls/editor, controls/sdl/editor/sdl,
base/layout/interaction/style/text/sdl/sdl_text; transitive scroll/Unicode.
Нет collections/gestures/hold/rich/custom/transitions/debug. Supplied primary
font и свои strings. `tests/ui_recipes/settings/main.odin` публикует modal layer,
Checkbox и editor в одном Context: text.prepare с deterministic metrics,
раздельные field/text-child/control claims, family copies/validate/commit;
Bool proposal → один outcome → rebuild, Not_Ready guard и retained reader.
Конфликт editor/control на одном field отказывает до публикации. Runtime reference
`--section lab-menu` либо `lab-settings`, `consumer/ui_showcase/app/lab_menu*`.
Editor field/text-child claims отличны от controls targets; один scope/focus.
Draft/applied раздельны. Apply → Confirm; Decline сохраняет draft для редактирования.
Dirty departure → Stay/Discard; только Confirm применяет показанную draft revision
один раз. Invalid/stale pending не применяет значения. Закройте/reconcile editor
input перед сменой owner; StopTextInput failure оставляет cleanup pending.
Нет новой persistence/editor semantics. Recovery не повторяет Apply.

## 5. Inventory

Direct selected imports collections/gestures/layers, collections/sdl/gestures/sdl
+ base/layout/interaction/style/text/sdl/sdl_text; transitive scroll/Unicode.
Нет controls/editor/hold/rich/custom/transitions/debug. Font/strings явно supplied.
`tests/ui_recipes/inventory/main.odin` выполняет две prepare/materialize/projection/
bind цепочки и gesture candidate поверх общего layers/interaction, копирует все
readers до commit. Проверяет row+drag conflict и duplicate region refusal,
Begin/Aim/End → owning pending copy → одно app decision → новая data revision,
lookup stable selection в другом контейнере, recovery без replay и reader после
destroy. Для краткости здесь deterministic headless geometry и явное app decision,
не новый диалоговый host. Сквозной Cancel/Confirm/render reference — `--section lab-inventory`,
`consumer/ui_showcase/app/lab_inventory*`, existing `gestures_demo/model` reducer.
Две ненестированные uniform List: validate_regions → materialize обеих → общий
text/layout → project_layout каждой области → layers interaction → bind_candidate
обеих → gestures с scroll=nil для Drag/Drop → copies/validate/commit.
У каждой State единственный offset owner; отдельный ordinary scroll State запрещён.
Stable row IDs/selection не меняются при reverse. Row activation selects item;
отдельная ручка selected item — Drag_Source; внешние headers — Drop_Target.
Begin/Aim/End формирует copied bounded pending, не переносит предмет. Cancel —
никакого membership effect; Confirm проверяет lifetime/token/data revision/source
и переносит один раз. Same-panel/stale/duplicate owners отказывают, R не replay.
Нет row+drag double owner, pan/repeat на rows, stacks/equipment/gameplay.

Все три snippets исполняются existing portable-check в собственных restricted
roots; их stdout oracle — `recipe-NAME effects=1 conflicts=1 live=0`.
Это результат реального dispatch/publication/retention пути и tracking allocator,
а не проверка non-nil symbols. Например из portable root:

```sh
odin build tests/ui_recipes/settings -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon -out:build/settings-recipe
build/settings-recipe
```

## 6. Development tools

Direct selected imports inspect/debug/testing; transitive base/layout/interaction/
wire. Нет обязательных text/Unicode/SDL/fonts. `ui_testing` нужен **только тестам**, не production binary.
`tests/ui_recipes/tools/main.odin` — headless selected API fixture.
Runtime reference — отдельный `consumer/ui_showcase_tools` с union showcase
и opt-in `ui_debug`, text/style/rich inspect; ordinary/menu не импортируют socket.

```sh
odin build consumer/ui_showcase_tools -collection:ui=kit -debug -define:UI_SHOWCASE_TOOLS=true -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/tools
# Обычный пользователь, не агент на основном дисплее:
build/tools --font resources/font.ttf --ui-debug --ui-profile showcase-v19 --section controls
python3 scripts/ui-showcase-cli.py --socket "$OWN_SOCKET" --profile showcase-v19 capabilities
python3 scripts/ui-showcase-cli.py --socket "$OWN_SOCKET" --profile showcase-v19 activate controls/checkbox
python3 scripts/ui-showcase-cli.py --socket "$OWN_SOCKET" --profile showcase-v19 snapshot
```

OWN_SOCKET получают только из своего endpoint record/run. Build flag выбирает
composition, **не permission**; endpoint требует debug либо UI_DEMO_TEST=true
**и** runtime --ui-debug + --ui-profile showcase-v19. Release без test gate
отказывает opt-in. `--test-time` требует compile test gate и runtime opt-in;
RPC его не включает. Off mode не создаёт endpoint. Ordinary entrypoint отвергает
tools flags. Unix socket private0700/0600, max8 clients/2s/1MiB line, Linux-only.

Один UTF-8 JSON line protocol19/request_id/op; exact operation fields, без
duplicates/NUL/extra keys. Capabilities/list-sections/select-section; tree/find/
inspect/geometry; diagnostics/assert-no-errors; focus/navigate/activate/cancel;
scroll; begin-hold/advance-hold/release-hold/cancel-hold; snapshot. Unsupported
setters/drag/editor/gesture RPC/overlays/crop не эмулируются. Find exact ID/role/name
возвращает все matches; collections показывают materialized nodes, не весь data.
Проверяйте dispatch/application.status/observation/effects, а не только ok.
CLI exit0 success,1 structured refusal,2 unknown outcome. Unknown → observe,
**не resend**; request_id не deduplication. Historical query не current action.
Snapshot удерживает frozen reader, actual pixels/readback/present и association;
JSON/BMP — одна publication, external display PNG отдельно. Incomplete output
не successful snapshot. Capabilities никогда не заменяют разрешения владельца.
