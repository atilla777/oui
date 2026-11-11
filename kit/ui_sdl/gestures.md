# SDL gestures: исторический API

Исторический API. В candidate `slyx-iv1.1.3` adapter algorithms перенесены в
[ui_gestures/sdl](../ui_gestures/sdl/README.md); старый source удалён из unported,
tests сохранены как oracles. Этот документ не является рабочей командой нового
комплекта; [актуальный migration disposition](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/libs/UI_EDITING.md).

Основа — `1003ba7f90d18b27074527b52285dd15c572228d`, accepted R2/D1
[slyx-frx.5](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/docs/specs/slyx-frx.5/spec.md). Core описан
[отдельно](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/libs/ui/gestures.md). [Описание прежнего gestures demo/ISD](https://github.com/atilla777/slyx/blob/8c55d0da6a28fe7d15f58f828b10a25a2851fea7/examples/gestures_demo/README.md)
приведено для исторического API; headless/software/
virtual-gamepad tests сами не подтверждают реальные кадры или физический контроллер.

## Один entry point

Создайте `Gestures_Input`, задайте `controls.layered.legacy.window_id`, затем
используйте **только** `gestures_input_event(input, ctx, event, window_extent)`
для события. Не вызывайте дополнительно controls/layered/legacy input. При
отсутствии gesture owner wrapper сам передаёт событие прежнему Controls_Input;
старые editor/rich/collections screens сохраняют собственные entry points.
В конце вызовите `close_gestures_input` для освобождения gamepad/capture ресурсов.

Нормализованный `Gestures_Input_Result` содержит один выбранный путь:

- `has_gesture`: вызвать `ui.dispatch_gesture` один раз и сразу потребить proposal;
- иначе прежние `has_action`, `has_scroll`, `has_hold`: соответствующий controls,
  scroll или hold dispatcher;
- `consumed` без action: не передавать событие другому UI controller или игре.

После принятого изменения выполните штатный rebuild/paired publication.
App reducer по proposal выполняется **до** rebuild и не повторяется при recovery.
Input хранит только physical edges, pending termination и clock baseline;
kind/phase/cycle/payload/target/offset принадлежат core.

Mouse down в clipped source → Armed. Motion нормализуется window → drawable →
logical units ровно один раз; drag/pan сохраняют capture за пределами owner,
но не окна. Repeat прекращается при выходе за кнопку. Mouse up передаёт последнюю
координату через тот же Move, затем End; release никогда не попадает в legacy
activation. После физического up новые motion уже не двигают capture.

Enter/Space и gamepad South начинают focused Drag/Repeat. Для semantic Drag
Tab/Shift+Tab или DPAD обходят доступные targets в tree order, Enter/South
завершает, Escape/East отменяет. Keyboard OS repeat и повторные down без up не
создают новый цикл. Gamepad ID и window ID проверяются; foreign input не
переадресует cycle. Wheel потребляется, пока новый жест владеет вводом.

Focus loss, window hide, mouse leave и removal управляющего gamepad дают Cancel.
Если core временно not-ready, terminal action сохраняется с точными cycle/source.
Cancel имеет приоритет перед release; old-cycle pending отбрасывается, не
применяется к новому owner. Не пытайтесь возобновить отменённый жест автоматически.

## Pending и время

`step_gestures(input, ctx, now_ms)` не читает системные часы. Host передаёт одно
монотонное nonnegative i64 время. После input/rebuild сначала обработайте
`input.pending`: максимум два шага — финальный Move и End, с rebuild между ними.
Затем допускается обычный clock step. Не повторяйте неуспешную мутацию автоматически.

Первый clock step после Begin/epoch/suspension — только baseline, без Advance.
Повтор выполняется арифметическим core Advance; отпускание не добавляет шаг.
Для тестового explicit-time режима задайте `gesture_clock.deterministic=true`:
wall-clock не используется. Source Agent всегда продвигается только явным
Advance, без параллельного wall-clock. Старый hold clock остаётся отдельным
`step_hold` и не заменяется новым repeat engine.

Не представляйте историческую Frame как текущую при ready=false. Публикация
использует прежний `publish_controls_pair`; его prepare/render/metadata/commit
отказы проходят общий gesture barrier. Capture/snapshot и model revision
проверяются владельцем host. При недоступности окна host также должен запрещать
новый прикладной ввод, не обходя suspension прямым setter.

## Проверки и пределы

```sh
SDL_VIDEODRIVER=dummy odin test kit/ui_sdl -define:ODIN_TEST_THREADS=1 -define:ODIN_TEST_RANDOM_SEED=5
odin check kit/ui_sdl -no-entry-point -vet -vet-style -vet-tabs -vet-semicolon
```

Параллельные SDL tests не изолируют process-global Init/Quit, event queue и
virtual joysticks. Наблюдённый parallel SIGABRT не объявлен исправленным:
последовательный pass — воспроизводимый путь проверки, а не доказательство
отсутствия любой гонки. Настройки SDL и test runner этим срезом не изменяются.
