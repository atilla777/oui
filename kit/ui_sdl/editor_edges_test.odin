package ui_sdl

import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"
import sdl "vendor:sdl3"

@(test)
editor_edges_share_window_loss_and_physical_latches :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	i := Input {
		window_id = 5,
	}
	e: sdl.Event
	e.text = {
		type     = .TEXT_INPUT,
		windowID = 5,
	}
	n := normalize_event(&i, &ctx, e, {640, 480})
	testing.expect(
		t,
		n.accepted && !n.has_action,
		"text must reach selected editor without base activation",
	)
	e.text.windowID = 6
	testing.expect(t, !normalize_event(&i, &ctx, e, {640, 480}).accepted)
	e.edit = {
		type     = .TEXT_EDITING,
		windowID = 5,
	}
	testing.expect(t, normalize_event(&i, &ctx, e, {640, 480}).accepted)
	for key in ([7]sdl.Keycode{sdl.K_BACKSPACE, sdl.K_DELETE, sdl.K_A, sdl.K_C, sdl.K_V, sdl.K_X, sdl.K_KP_ENTER}) {
		e.key = {
			type     = .KEY_DOWN,
			windowID = 5,
			key      = key,
		}
		testing.expect(t, normalize_event(&i, &ctx, e, {640, 480}).front)
		testing.expect(
			t,
			!normalize_event(&i, &ctx, e, {640, 480}).front,
			"duplicate editor key must not repeat",
		)
		e.window = {
			type     = .WINDOW_FOCUS_LOST,
			windowID = 5,
		}
		normalize_event(&i, &ctx, e, {640, 480})
		e.key = {
			type     = .KEY_UP,
			windowID = 5,
			key      = key,
		}
		testing.expect(t, !normalize_event(&i, &ctx, e, {640, 480}).front)
		e.window = {
			type     = .WINDOW_FOCUS_GAINED,
			windowID = 5,
		}
		normalize_event(&i, &ctx, e, {640, 480})
	}
}
