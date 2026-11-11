# ui_gestures/sdl — один borrowed physical input

Кандидат до интеграции. Import `ginput "ui:ui_gestures/sdl"`.
Зависимости: gestures, interaction/scroll, ui_sdl и SDL3. Нет text/Unicode/TTF,
controls/hold или собственного gamepad/window edge owner. Adapter содержит только
family pending termination/point, trigger key и свой clock baseline.

`event(adapter,shared_input,interaction,gestures,scroll,Normalized_Input)` получает
результат единственного `normalize_event`. При consumed ordinary dispatch не
вызывается. Keyboard Return/Space и Gamepad South начинают drag/repeat; второй
confirmation завершает drag, release завершает repeat. Tab/Shift+Tab и DPAD
выбирают targets без ordinary focus navigation; Escape/East отменяют cycle.
Mouse acquisition уважает common front target; active drag consumes wheel и
чужой pointer motion. Outside/invalid pointer и matching window/device loss
отменяют capture даже при not-ready, с прежними bounded cancellation signals.

Release до rebuild сохраняет только cycle/source/point, не SDL pointers.
`step(...,now_ms)` после каждой успешной publication отдаёт не более одного
pending Move/End; после каждого такого действия снова требуется rebuild.
Старый cycle не переносится на новый owner.

Wall-clock repeat baseline впервые устанавливается без начисления времени,
сбрасывается при unavailable/readiness/loss/failure/epoch/cycle changes. Agent и
`clock.deterministic=true` не смешиваются с wall time; deterministic Advance
передаётся headless dispatcher явно. Caller при failed rebuild/render вызывает
`gestures.block` и сбрасывает adapter baseline. Shared Input всё равно нормализует
release/loss edges. `close(adapter)` не закрывает borrowed shared Input/device.

Тесты используют реальные SDL event unions, но не заявляют физическую gamepad/
driver/platform qualification. [Selected consumer](../../../tests/ui_editing/selected_input/README.md)
добавляет real isolated SDL display и application reducer evidence.
