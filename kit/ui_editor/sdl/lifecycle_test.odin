package ui_editor_sdl
import editor ".."
import base "../../ui_base"
import interaction "../../ui_interaction"
import backend "../../ui_sdl"
import "core:testing"
import sdl "vendor:sdl3"
Lifecycle_Test :: struct {
	started, stopped, areas: int,
	fail:                    bool,
	area:                    sdl.Rect,
	cursor:                  i32,
}
@(test)
text_services_follow_current_focused_editor_without_hidden_replay :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := editor.create(); defer editor.destroy(&s)
	d := editor.Description {
		id           = "name",
		node_id      = "field",
		text_node_id = "value",
		value        = "aя",
		revision     = 1,
	}
	if !publish(t, &p, &ctx, &s, d) {return}
	a := create(); defer close(&a, nil); input := backend.Input {
		window_id = 5,
	}
	services: Lifecycle_Test
	a.lifecycle = {
		start = proc(
			_: ^sdl.Window,
			user: rawptr,
		) -> bool {v := cast(^Lifecycle_Test)user; v.started += 1; return !v.fail},
		stop = proc(
			_: ^sdl.Window,
			user: rawptr,
		) -> bool {v := cast(^Lifecycle_Test)user; v.stopped += 1; return !v.fail},
		size = proc(_: ^sdl.Window, _: rawptr) -> (i32, i32, bool) {return 400, 200, true},
		area = proc(_: ^sdl.Window, r: sdl.Rect, cursor: i32, user: rawptr) -> bool {
			v := cast(^Lifecycle_Test)user
			v.area, v.cursor = r, cursor
			v.areas += 1
			return !v.fail
		},
		user = &services,
	}
	testing.expect(
		t,
		sync(&a, &input, &ctx, &s, nil) &&
		a.text_active &&
		services.started == 1 &&
		services.area.w == 200 &&
		services.cursor == 40,
	)
	testing.expect(
		t,
		sync(&a, &input, &ctx, &s, nil) && services.started == 1 && services.areas == 2,
	)
	base.invalidate(&p)
	testing.expect(t, sync(&a, &input, &ctx, &s, nil) && !a.text_active && services.stopped == 1)
	if !publish(t, &p, &ctx, &s, d) {return}
	services.fail = true
	testing.expect(t, !sync(&a, &input, &ctx, &s, nil) && !a.text_active)
	services.fail = false
	testing.expect(t, sync(&a, &input, &ctx, &s, nil) && a.text_active)
	testing.expect(t, close(&a, nil) && !a.text_active && services.stopped == 2)
}
