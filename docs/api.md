# API map — реальные narrow packages

Адреса ниже относительно portable root, collection `-collection:ui=kit`.
Импорт — `import layout "ui:ui_layout"`, не legacy `ui`.
Точные Odin declarations находятся в названных files; prose не заменяет compiler.
Публичные owners experimental; [lifecycle](lifecycle.md) обязателен для всех.

| Package | Основной контракт / source |
|---|---|
| ui_base | Publication, Frame_Stamp, begin_attempt/validate_candidate/enter_commit/finish_commit/is_current/invalidate, owning errors; `kit/ui_base/*.odin` |
| ui_layout | `prepare(nodes,options,metrics,allocator,stamp)` → Layout_Candidate/Error; `find`, `try_copy_frame`, destroy; `kit/ui_layout/layout.odin` |
| ui_interaction | Context, targets, Capture_Claim, prepare/commit/guard/dispatch/dispatch_owned; owning registration tokens и reconciliation; `kit/ui_interaction/` |
| ui_style | prepare paint frame, atlas_resources/nine_slice_patches; metadata, не handles; `kit/ui_style/` |
| ui_text | prepare → owning geometry+text, synchronous metrics, source ranges и limits; `kit/ui_text/` |
| unicode_graphemes | Unicode15.1 EGC `try_boundaries`, count; offsets bytes, не glyph/rune indices |
| ui_layers | prepare partition/paint plan + shared interaction; modal scope, popup shield, noninteractive tooltip; commit не создаёт второго focus owner |
| ui_scroll | ordinary vertical regions, offsets/reveal; не virtual offset owner |
| ui_controls | controlled descriptions/proposals; Bool/Integer/Item/Dialog и готовые recipes; app owns values |
| ui_hold | Description threshold_ms, Progress_Description; Begin/Advance/Release/Cancel, один completion; plain Activate запрещён |
| ui_editor | prepare/dispatch, Accepted/Rejected/External resolution; owning result/proposal destroy; app value/revision, UI caret/anchor/scroll |
| ui_collections | prepare/materialize/project_layout/bind_candidate/validate_regions; immutable data/stable IDs, один offset owner на region |
| ui_gestures | prepare/dispatch/block, Begin/Aim/Move/Advance/End/Cancel; borrowed Result до следующей mutation; app owns Drop outcome |
| ui_rich | bounded grammar, font/image runs и owning geometry; не HTML/editor |
| ui_transitions | explicit external time, frozen visual geometry, retarget/presence/reduced-motion; не меняет layout |
| ui_custom/ui_composition | immutable payload/pure hit/paint metadata; ordinary namespaced nodes/slots, не plugin system |
| ui_world | app-owned projection helper на base geometry, не camera/engine |
| ui_sdl | normalize_event, Input, primitive/image generations/render/readback; vendor:sdl3 |
| ui_sdl_text | explicit TTF font generations/metrics/render; vendor:sdl3/ttf |
| ui_inspect/ui_wire/ui_debug/ui_testing | opt-in owning inspection/DTO/transport/core:testing; family projections выбираются отдельно |

Headless direct imports:
base→ничего; layout→base; interaction→base/layout; style→base/layout;
text→base/layout/style/unicode_graphemes. Layers/scroll/hold используют
base/layout/interaction (headless hold не требует style). Controls добавляет
layers/scroll/style/text; editor — text/Unicode; collections и gestures — scroll;
rich — text/style; transitions/custom — layout/interaction/style;
composition — layout/style; world — base. Реальные direct/transitive graphs
проверяются compiler fixtures, не предположением из названия package.

`<family>/sdl` выбирается отдельно и добавляет своё headless family и `ui_sdl`;
editor/rich используют `ui_sdl_text`, controls adapter сам по себе не требует TTF.
`<family>/inspect` и debug/testing adapters также не подразумеваются core import.
Translations — отдельная consumer-зависимость text gallery, не UI core.

Конкретный новый экран: выберите [recipe](recipes.md), прочитайте declarations
используемых procedures и runtime reference, скомпилируйте snippet в **его**
restricted closure. Не вызывайте старые `ui.prepare_layered*`, не восстанавливайте
umbrella Host/profile facade. Snapshot/query не дают разрешения новой mutation.
