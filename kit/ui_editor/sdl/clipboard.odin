package ui_editor_sdl
import editor ".."
import interaction "../../ui_interaction"
import text "../../ui_text"
import "core:mem"
import "core:strings"
import sdl "vendor:sdl3"

@(private)
system_get :: proc(a: mem.Allocator, _: rawptr) -> (string, bool) {
	bytes := sdl.GetClipboardText(); if bytes == nil {return "", false}; defer sdl.free(bytes)
	v, e := strings.clone(string(cast(cstring)bytes), a); return v, e == nil
}
@(private)
system_set :: proc(v: string, _: rawptr) -> bool {
	z, e := strings.clone_to_cstring(v); if e != nil {return false}; defer delete(z)
	return sdl.SetClipboardText(z)
}
@(private)
clipboard_action :: proc(
	a: ^Adapter,
	ctx: ^interaction.Context,
	s: ^editor.State,
	e: ^editor.View,
	key: sdl.Keycode,
	metrics: text.Text_Layout_Metrics,
) -> Result {
	get, set := a.clipboard.get, a.clipboard.set
	if get == nil {get = system_get}; if set == nil {set = system_set}
	if key == sdl.K_V {
		v, ok := get(a.allocator, a.clipboard.user); defer delete(v, a.allocator)
		if !ok {return {consumed = true, error = .Clipboard}}
		if v == "" {return {consumed = true}}
		return {
			editor = editor.dispatch(
				s,
				ctx,
				{id = e.id, kind = .Insert, text = v, source = .Keyboard},
				metrics,
			),
			has_editor = true,
			consumed = true,
		}
	}
	if e.caret == e.anchor {return {consumed = true}}
	if !set(
		e.value[min(e.caret, e.anchor):max(e.caret, e.anchor)],
		a.clipboard.user,
	) {return {consumed = true, error = .Clipboard}}
	if key == sdl.K_C {return {consumed = true}}
	return {
		editor = editor.dispatch(
			s,
			ctx,
			{id = e.id, kind = .Backspace, source = .Keyboard},
			metrics,
		),
		has_editor = true,
		consumed = true,
	}
}
