# API: прочитать перед реализацией

В выбранном portable root читайте `docs/api.md`, `docs/lifecycle.md` и
`docs/compatibility.md`; source form — `docs/ui-kit/` вместо `docs/`.
Collection `-collection:ui=<kit-root>`, portable kit-root `kit/`, source `kit/`.
Реальные signatures — в выбранных packages, runnable полный publisher —
`consumer/standalone_menu/runtime.odin` (source `consumer/standalone_menu/`).

Layout-only импортирует только base/layout. Menu добавляет interaction/style/
text/Unicode/SDL/TTF, не controls. HUD выбирает layers/hold, settings — layers/
controls/editor, inventory — collections/gestures/layers с отдельной drag ручкой.
Не импортируйте общий showcase для доказательства маленького closure.
Rich/custom/transitions/tools явно optional; translations — consumer-only выбор.

Нормализуйте physical input один раз, затем один selected dispatcher. App owns
draft/applied/selection/data и принятие proposal; не второй callback на Button.
Соберите claims всех selected targets; row/editor/hold/gesture double owner
отклоняется, не решается обходом guard. У virtual region один offset owner.

Prepare → все owning copies/precommit → validate stamp/model/resources →
enter_commit → infallible moves → finish_commit → reconcile → dispose old.
Descriptors borrowed до prepare return; retained frames own copies/generations.
Не shallow-copy owning values, не удерживайте borrowed views после mutation/
destroy. Reader переживает runtime, не allocator/backend. Historical не current.

Errors сохраняют family/stage/code/ID до destroy source. Failure leaves ready=false;
R rebuild current accepted model, никогда replay reducer/clipboard/Drop/Apply.
Destroy editor Result; close native text input до смены owner; failed close
оставляет cleanup pending. Release/loss очищают capture также при Not_Ready.

Сохраните single-line/Unicode15.1/65536 bytes/4096 text lines, vertical non-nested
scroll/uniform collections, Grid без span и Row/Column без wrap. Нет IME/preedit/
bidi/shaping/undo/normalization/rich editor или arbitrary combination powerset.
Fractional Pixel_Perfect отказывает, tight viewport не разрешает уменьшить текст.
