# ui_editor/sdl — selected native editor adapter

Кандидат до интеграции. Import `adapter "ui:ui_editor/sdl"`.
Прямые зависимости: editor, base/interaction, ui_text, ui_sdl, ui_sdl_text,
SDL3/SDL3_ttf, core. Ни controls/hold, ни второй physical Input не вложены.

1. Приложение вызывает `ui_sdl.normalize_event` **один раз**, даже при
   ready=false. `event(&adapter,&shared_input,&interaction,&editor,normalized,
   metrics)` получает synchronous borrowed result; не сохраняйте SDL text pointers.
2. Selected active capture обслуживается до ordinary input. При consumed не
   вызывать ordinary `dispatch_input`. Loss доставляется всем выбранным capture
   owners для cleanup, но не становится activation.
3. После focus click rebuild, `take_pointer`, затем необходимый rebuild selection.
   `drag_tick` принимает явный dt; geometry/scope/removal/focus mismatch отменяет
   capture. Matching release очищает capture и при invalid coordinates/not-ready.
4. `sync(...,window)` управляет Start/StopTextInput и SetTextInputArea по current
   focused editor и выбранной frozen geometry. Ошибка требует блокировать runtime;
   она не разрешает dispatch исторического кадра. Optional `Lifecycle` callbacks
   — testable native boundary, не device owner. Без callbacks используются SDL.
5. `close(&adapter,window)` вызывается до destroy window. При StopTextInput failure
   возвращает false и сохраняет text_active для явного retry; не закрывает shared
   Input/gamepad. Clipboard callbacks get возвращают owning строку указанного
   allocator; ошибка cut не меняет value, empty selection — no-op.

Committed TEXT_INPUT, arrows/Home/End/Shift, Backspace/Delete, Ctrl+A/C/X/V,
Return/keypad Enter и Escape специализируются до base activation. OS repeats
допустимы только для прежних navigation/deletion keys; submit/cancel/clipboard
не повторяются. Printable Space приходит только committed text. Непустой
TEXT_EDITING даёт Unsupported_Composition: IME/preedit support не заявлен.

`matches(font_generation,editor_frame)` проверяет fonts/revisions/metrics/scale/
output. `render(g,frame,focus_id,foreground,selection,id="")` не очищает экран:
paint одного выбранного family, selection и caret используют ту же owning
geometry/EGC runs. Renderer state восстанавливается и после отказа. Generation,
renderer и allocator живут дольше retained readers. Historical owning reader
может рисоваться; current readiness проверяет его publisher, не painter.
Native temporary surfaces/textures освобождаются локально; SDL/GPU heap не
измеряется Odin tracking allocator.

Исполняемый [selected consumer](../../../tests/ui_editing/selected_input/README.md)
показывает общий publisher, error/recovery и composed input без showcase/debugger.
