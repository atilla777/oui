package ui_editor_sdl
import editor ".."
import base "../../ui_base"
import interaction "../../ui_interaction"
import backend "../../ui_sdl"
import text "../../ui_text"
import "core:mem"
import sdl "vendor:sdl3"

Error :: enum {
	None,
	Clipboard,
	Unsupported_Composition,
	Text_Lifecycle,
	Allocation,
}
Clipboard :: struct {
	get:  proc(a: mem.Allocator, user: rawptr) -> (string, bool),
	set:  proc(value: string, user: rawptr) -> bool,
	user: rawptr,
}
Adapter :: struct {
	lifecycle:                              Lifecycle,
	allocator:                              mem.Allocator,
	clipboard:                              Clipboard,
	text_active:                            bool,
	capture_id, scope_id, pending_click_id: string,
	anchor:                                 int,
	point:                                  [2]f64,
	geometry:                               base.Frozen_Geometry,
}
Result :: struct {
	editor:               editor.Result,
	consumed, has_editor: bool,
	error:                Error,
}
create :: proc(a := context.allocator) -> Adapter {return {allocator = a}}
event :: proc(
	a: ^Adapter,
	input: ^backend.Input,
	ctx: ^interaction.Context,
	s: ^editor.State,
	n: backend.Normalized_Input,
	metrics: text.Text_Layout_Metrics,
) -> Result {
	if r := pointer_event(a, input, ctx, s, n, metrics); r.consumed {return r}
	if !n.accepted ||
	   n.suspended ||
	   input.suspended ||
	   !interaction.ready(ctx) ||
	   s.frame.stamp != ctx.frame.stamp {return {}}
	active: ^editor.View
	for &v in s.frame.editors {if v.node_id == ctx.focus_id && v.availability == .Applied {active = &v; break}}
	if active == nil {return {}}
	if interaction.guard(ctx, active.node_id, .Keyboard) != .Applied {return {}}
	e := n.event
	action := editor.Action {
		id     = active.id,
		source = .Keyboard,
	}
	#partial switch e.type {
	case .TEXT_INPUT:
		action.kind, action.text = .Insert, string(e.text.text)
	case .TEXT_EDITING:
		if string(e.edit.text) != "" {return {consumed = true, error = .Unsupported_Composition}}
		return {consumed = true}
	case .KEY_DOWN:
		if e.key.mod & sdl.KMOD_CTRL != {} {
			if !n.front || e.key.repeat {return {consumed = true}}
			switch e.key.key {
			case sdl.K_A:
				return {
					editor = editor.dispatch(
						s,
						ctx,
						{
							id = active.id,
							kind = .Select,
							source = .Keyboard,
							caret = len(active.value),
							anchor = 0,
						},
						metrics,
					),
					consumed = true,
					has_editor = true,
				}
			case sdl.K_C, sdl.K_X, sdl.K_V:
				return clipboard_action(a, ctx, s, active, e.key.key, metrics)
			case:
				return {consumed = true}
			}
		}
		repeatable :=
			e.key.key == sdl.K_LEFT ||
			e.key.key == sdl.K_RIGHT ||
			e.key.key == sdl.K_HOME ||
			e.key.key == sdl.K_END ||
			e.key.key == sdl.K_BACKSPACE ||
			e.key.key == sdl.K_DELETE
		if !n.front && !(e.key.repeat && repeatable) {return {consumed = true}}
		shift := e.key.mod & sdl.KMOD_SHIFT != {}
		switch e.key.key {
		case sdl.K_LEFT:
			action.kind, action.direction, action.extend = .Move, .Left, shift
		case sdl.K_RIGHT:
			action.kind, action.direction, action.extend = .Move, .Right, shift
		case sdl.K_HOME:
			action.kind, action.direction, action.extend = .Move, .Home, shift
		case sdl.K_END:
			action.kind, action.direction, action.extend = .Move, .End, shift
		case sdl.K_BACKSPACE:
			action.kind = .Backspace
		case sdl.K_DELETE:
			action.kind = .Delete
		case sdl.K_RETURN, sdl.K_KP_ENTER:
			action.kind = .Submit
		case sdl.K_ESCAPE:
			action.kind = .Cancel
		case sdl.K_SPACE:
			return {consumed = true}
		case:
			return {}
		}
	case:
		return {}
	}
	return {editor = editor.dispatch(s, ctx, action, metrics), has_editor = true, consumed = true}
}
