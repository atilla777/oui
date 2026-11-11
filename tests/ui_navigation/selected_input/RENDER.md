# Selected composed render — candidate before integration

Ограниченный вклад `slyx-iv1.1.2`: layers/scroll/hold/controls input и render
используют **один** typed publisher и owning Reader. Основа — R1/D1 и R1-A1/D1-A1
([источник решений](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/docs/specs/slyx-iv1.1/spec.md)), включая разрешённые
frozen geometry / non-clearing node/text/focus repairs. Реализация других families
не добавлена. Ни этот документ, ни software PNG не являются independent approval,
feature acceptance, Git/Dolt publication или завершением всей задачи.

## Граница и владение

`Runtime.render: Render_Config` явно выбирает renderer, font bytes/revisions,
image revision, ru/en и внешние font/image Resource_Ledger. При renderer=nil
сохраняется прежний deterministic input scenario; реальные fonts/textures не
создаются. Текущий combined executable теперь явно импортирует ui_sdl_text/TTF;
независимые headless family closures от него по-прежнему не зависят.

`publish` добавляет к прежней транзакции:

1. Reuse/checked retain generation того же renderer/revision либо fallible создание
   image и font candidates. Sources копируются владельцами generations; смена bytes
   требует новой явной revision, а не скрытого reload по тому же имени.
2. Один `text.prepare` строит geometry и real TTF text metadata. Никакого второго
   layout solver. Label children — обычные Content nodes в Absolute button wrappers;
   fixed inset 4×2, stable IDs, ru/en strings, Checkbox marker и controlled Slider value.
3. Layers и scroll готовят итоговую geometry, hold/controls — metadata. Text line
   positions rebased на **logical** scroll result, затем style materializes final
   sampled numerical visual geometry. Никакого transition solver или editor state.
4. Owning text/style/generations/samples перемещаются в тот же Reader до последнего
   precommit/association check. Только затем infallible swaps всех selected owners,
   finish_commit, capture reconciliation и registration disposal.

Каждый Render_Frame владеет text/style, copied sample IDs и retained generations.
Старый Reader освобождается после coherent swap; отказ до swap освобождает весь
candidate и сохраняет прежние owners/Reader/returns/registrations. Readiness и
native capture/clock baseline блокируются. После model intention recovery строит
принятую модель, не replay reducer. Renderer, ledgers и allocators живут дольше
всех retained readers. Reader переживает Runtime; исторические backend painters
могут его читать, но current rendering/capture требует live publication.

Fonts и images считаются отдельно. Fixture использует настоящий supplied TTF и
одну owning 1×1 RGBA texture с node `image`; decoder/asset registry не добавлен.
Unchanged revisions переиспользуют generation без native handle growth.
Renderer replacement требует полной новой publication; нельзя очистить новый
renderer и рисовать туда/оттуда generations старого renderer.

## Paint plan и sampled agreement

`render_current(&runtime)` проверяет publication, matched geometry/layers/text/
style stamps, renderer identity, output extent, resource revision и font metrics.
Затем сохраняет renderer state, устанавливает pixel coordinates и один раз очищает
output. Исполняет owning layer plan:

- Draw_Node: non-clearing `backend.paint_node`, затем только text **этого** node;
- Scrim: full-output black alpha=128 в точной позиции stack plan;
- Draw_Focus: только focus command после descendants, не общий поздний focus pass.

Base-owned popup/tooltip ниже следующего modal scrim. Popup body закрывает нижний
text; tooltip рисуется поверх popup, но не становится input target. Общий physical
root не рисуется. Render target не переключается. Clip, viewport, logical mode,
scale/color-scale, blend и draw color восстанавливаются и после partial failure;
restore-result проверяется отдельно. Нет reentry/callbacks/reducer внутри painter.

Frozen Geometry_Entry — уже вычисленная caller projection, не анимация. Один
matched numerical bundle задаёт input bounds/clip/content_clip и visual areas.
Text сохраняет logical measured metrics, а per-node rendering применяет его
scale/offset к texture destination и opacity к text alpha. Primitive/focus/fallback
alpha и existing image texture alpha умножаются на per-draw opacity; retained
texture alpha восстанавливается даже при неудачном draw. Reader не меняется.
Zero scale/opacity пропускают node; unrenderable transforms отвергаются до swap.
Caller обязан передать coherent samples затронутых descendants; implicit tree
transform/transition scheduler не появляется.

`readback_current` сначала рисует текущий bundle, затем вызывает owning backend
readback до present. Caller уничтожает Surface. Отказ любой стадии блокирует
readiness/captures, исторические/частичные pixels не объявляются current snapshot.
Сама эта bounded fixture не создаёт window и не делает SDL_RenderPresent.

## Проверки и воспроизведение

Из корня проверенной рабочей копии:

```sh
odin test tests/ui_navigation/selected_input -collection:ui=kit \
  -vet -vet-style -vet-tabs -vet-semicolon \
  -define:SELECTED_RENDER_TEST=true -define:ODIN_TEST_THREADS=1 \
  -out:/tmp/opencode/selected-render-tests
odin build tests/ui_navigation/selected_input -collection:ui=kit \
  -vet -vet-style -vet-tabs -vet-semicolon -show-import-graph \
  -out:/tmp/opencode/selected-render
mkdir -p /tmp/opencode/selected-render-png
/tmp/opencode/selected-render --software-render \
  "$PWD/resources/font.ttf" /tmp/opencode/selected-render-png
```

Последняя команда создаёт шесть **software readback PNG** en/ru × base/popup/modal,
не display screenshots. Оба языка используют настоящий font metrics/render path;
набор отдельно осмотрен: подписи и inset читаются, popup закрывает Hold text,
scrim затемняет нижний scope, Dialog OK/ОК и его focus выше scrim. PNG показывают
только заданную fixture 400×300/ui_scale=1, не произвольную UI usability.

38 combined tests (с флагом выше) сохраняют input tests и добавляют real ru/en,
controlled text, node/text/scrim/focus pixels, tooltip/non-input, retained image,
sampled scale=2/offset/opacity=0.5 text+native slider hit, invalid transforms,
renderer mismatch, native bad font после image candidate, partial-command failure,
state restoration, precommit и readback failure/recovery. Отдельно backend opacity
tests сохраняют image modulation и missing-image fallback alpha.

`SELECTED_RENDER_TEST=true` включает **только test-build** Precommit и Readback
fault seams. Во втором случае сначала выполняется реальный readback, затем Surface
уничтожается и boundary намеренно отказывает. Это не притворное доказательство
ошибки GPU/driver ReadPixels. Без compile flag поле fault не действует; CLI/wire
setters нет. Native malformed-font failure и invalid paint-command failure реальны.

349 input-only и **772** render-publisher backing allocation positions проверены
по одному. Render case заменяет обе revisions и включает три owning samples:
partial resources/text/style/copies освобождаются; старые stamps/refcounts/live
owners сохраняются. Итог failure fixture: peak=255600 bytes, live=0,
fonts created/destroyed=764/764, images=769/769. Odin не измеряет TTF/SDL/GPU heap.

Linux x86_64, Odin `dev-2026-10-nightly:84bc3fc`, SDL3 3.4.16, SDL3_ttf 3.2.2,
Slyx UI font из существующего licensed asset: software scenario + 64 stable
rebuild/render — Runtime=3152, Reader=1368 bytes, allocations=60415,
cumulative bytes=18375013, live=111988, peak=241823; font/image live=1/1,
после уничтожения runtime и последнего reader live=0, bad-frees=0, ledgers=1/1
created/destroyed для каждого вида. Это наблюдение, не SLA или полный native heap.
Cumulative bytes включают PNG path buffers: во внешнем proof с другим output
directory наблюдались 18375157 bytes при тех же live/peak и побайтово одинаковых PNG.

Physical kit теперь содержит 12 root packages: base/layout/interaction/layers/
scroll/hold/controls/style/text/unicode_graphemes/ui_sdl/ui_sdl_text и только
hold/sdl, controls/sdl подпакеты. Font передаётся явно; font/license copies нужны
лишь для независимого proof. Нет assets Slyx в коде, Python runtime, unported,
transition/custom/editor/collection/gesture/tool dependencies.

## Task boundary and final disposition

[Полный owner inventory, AC coverage и optional structure/cost proof](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/libs/UI_NAVIGATION.md)
фиксирует exact scope `.2`: family slices AC-004/005/008/009/010/012/013/014.
Выбранный consumer — этот typed fixture, не обязательная миграция old window app.
R1-A1/D1-A1 допускают old API breaks; прежние selected implementations удалены,
применимые oracles перенесены, foreign snapshots/tools sources не переписаны.

AC-011 real menu выполнен prerequisite `.5` и **не назван в coverage `.2`**.
Здесь нет claim SDL window/present/display, physical hardware open или GPU-driver
failure. Native semantics проверены настоящим normalizer/adapter кодом на
детерминированных SDL events, readback/pixels — software renderer/реальным TTF.
Модель device-open boundary в reattach test не выдаётся за hardware observation.
Эти ограничения не создают новую обязательную window/display/gamepad/driver
matrix, live run или этап «после отдельно разрешённой миграции».

Существующие ISD profiles и old consumers сохраняются как legacy disposition,
не как обязательные passing new-API targets. Runner/setup не менялись. Если
отдельно понадобится новый display claim, он выполняется только через ISD own run,
explicit focus, saved PNG/logs и stop в finally, без main-display fallback.
Для проверки этого implementation candidate достаточны current commands выше,
family/adapter physical closures, combined regressions и независимое review.
