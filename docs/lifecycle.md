# Lifecycle, владение и отказ

Приложение владеет значимым model/draft/applied/data revision/outcome. Stable IDs
не зависят от locale, имени, индекса и materialization. Один UI thread, без reentry.
Нормализуйте physical SDL event ровно один раз через `ui_sdl.normalize_event`.
Selected adapters получают этот normalized input, не второй Input/normalizer.
Один interaction/focus owner и Publication, отдельные selected family State.

## Полный цикл

1. Init SDL/TTF/window/renderer, supplied bytes/fonts/images, Publication и
   interaction Context по стабильному адресу; создайте только выбранные State.
   Context заимствует Publication; adapter заимствует общий physical Input.
2. `base.begin_attempt` выключает readiness. Prepare selected text/layout/style,
   resource generations и family candidates. Сверьте полный claim set до commit.
3. Сделайте **все fallible** copies для owning reader, error bytes и precommit.
   Validate owner/attempt/model/sequence/drawable/scale/generations повторно.
4. `base.enter_commit` → только infallible moves/swaps → `base.finish_commit`.
   Без allocation, event loop, reducer или fallible callbacks внутри barrier.
   Затем registration reconciliation/dispose и destroy прежних owners.
5. На один input выберите один dispatcher: active capture/editor/gesture,
   selected layer/control/collection/hold route, ordinary dispatch только если
   событие не consumed. Release/loss cleanup действует и при Not_Ready.
6. Proposal — ещё не успех приложения. Reducer проверяет sequence/token/revision,
   один раз даёт accepted/rejected outcome; editor result явно destroy.
   Затем rebuild/publication до следующей мутации.
7. Frozen owning reader → matching primitive/text/family paint → owning readback
   → present. Renderer-state restoration и generation matching обязательны.
8. Shutdown: cancel/block input/cycles; `editor_sdl.close` при выборе editor;
   readers → selected adapters/families/generations → Context → Publication →
   renderer/window/TTF/SDL. Allocator/backend живут дольше всех retained readers.

Runnable full publisher: `consumer/standalone_menu/runtime.odin`. Он показывает
весь цикл без showcase. Selected compositions — `consumer/ui_showcase/app/`;
это consumer code, не новый public framework.

## Owning и borrowed

Inputs/metrics callbacks заимствуются синхронно до prepare return, если API
конкретного owner не говорит иначе. Published frames владеют retained bytes;
`try_copy_frame` даёт независимый owning reader. Присваивание Odin struct не
создаёт копию владения: move ровно один раз с обнулением источника; destroy
ровно один раз исходным allocator. `context.temp_allocator` не retained storage.
Rich/text candidates содержат geometry **и** family frame — два owners.
Collections retain immutable data; font/image generations удерживают backend
handles. Не освобождайте backend/font sources до последнего reader.

Historical reader переживает source destroy и пригоден для чтения/исторического
render при совместимом drawable, но **не** разрешает current action/snapshot.
Проверяйте `base.is_current(&publication, reader.stamp)` и consumer association.

## Errors и recovery

`describe_error` + `base.try_copy_error` сохраняют family/stage/code/ID до
destroy borrowed source; copy failure не success. Ошибки prepare/resource/copy/
precommit очищают candidates, прежние owners остаются historical, ready=false.
Render/readback/present failure тоже invalidates readiness/captures/clock.
Старые видимые pixels не current snapshot; уже принятая model не откатывается.

Явный host **R** строит принятую model/revision заново, без reducer replay,
clipboard replay, повторного Drop/Apply или physical edge. Ordinary input/resize
не чинят failed publication. StopTextInput failure сохраняет pending cleanup:
не открывайте следующий editor owner и не обнуляйте флаг фиктивно.
Fault fixtures только test/debug gates, не release setters.

В tools `request_id` — корреляция, не deduplication. Потерянный ответ означает
unknown outcome: сначала observation, никогда blind resend mutation. Endpoint
только свой явно разрешённый; capabilities не permission. См. recipes.
