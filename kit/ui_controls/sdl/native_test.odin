package ui_controls_sdl

import controls ".."
import base "../../ui_base"
import interaction "../../ui_interaction"
import layout "../../ui_layout"
import backend "../../ui_sdl"
import "core:strings"
import "core:testing"
import sdl "vendor:sdl3"

Env :: struct {
	p:      base.Publication,
	ctx:    interaction.Context,
	s:      controls.State,
	g:      layout.Frame,
	a:      Adapter,
	device: backend.Input,
	value:  i64,
}

@(test)
stale_track_geometry_never_creates_native_proposal :: proc(t: ^testing.T) {
	e: Env; init_env(&e, t); defer destroy_env(&e)
	e.g.stamp.attempt += 1
	v: sdl.Event; v.button = {
		type     = .MOUSE_BUTTON_DOWN,
		windowID = 1,
		button   = 1,
		x        = 20,
		y        = 10,
	}
	r := handle(&e.a, &e.s, &e.ctx, &e.g, backend.normalize_event(&e.device, &e.ctx, v, {300, 40}))
	testing.expect(
		t,
		r.consumed &&
		r.result.dispatch.code == .Not_Ready &&
		r.result.event == nil &&
		e.a.capture_id == "" &&
		e.p.sequence == 0 &&
		e.p.ready,
	)
}

@(test)
invalid_coordinate_mouse_up_still_clears_slider_capture :: proc(t: ^testing.T) {
	e: Env; init_env(&e, t); defer destroy_env(&e)
	v: sdl.Event; v.button = {
		type     = .MOUSE_BUTTON_DOWN,
		windowID = 1,
		button   = 1,
		x        = 20,
		y        = 10,
	}
	handle(&e.a, &e.s, &e.ctx, &e.g, backend.normalize_event(&e.device, &e.ctx, v, {300, 40}))
	v.button.type = .MOUSE_BUTTON_UP
	handle(&e.a, &e.s, &e.ctx, &e.g, backend.normalize_event(&e.device, &e.ctx, v, {}))
	testing.expect(t, e.a.capture_id == "" && !e.p.ready)
}

@(test)
slider_capture_cannot_survive_scope_or_unavailable_rebuild :: proc(t: ^testing.T) {
	for unavailable in ([]bool{false, true}) {
		e: Env; init_env(&e, t)
		v: sdl.Event; v.button = {
			type     = .MOUSE_BUTTON_DOWN,
			windowID = 1,
			button   = 1,
			x        = 20,
			y        = 10,
		}
		handle(
			&e.a,
			&e.s,
			&e.ctx,
			&e.g,
			backend.normalize_event(&e.device, &e.ctx, v, {300, 40}),
		); rebuild(&e, t)
		if unavailable {n, _ := interaction.find(&e.ctx.frame, "slider"); n.availability = .Disabled
		} else {delete(e.s.frame.scope_id, e.s.frame.allocator)
			e.s.frame.scope_id = strings.clone("new-scope", e.s.frame.allocator)}
		v.motion = {
			type     = .MOUSE_MOTION,
			windowID = 1,
			x        = 80,
			y        = 10,
		}
		r := handle(
			&e.a,
			&e.s,
			&e.ctx,
			&e.g,
			backend.normalize_event(&e.device, &e.ctx, v, {300, 40}),
		)
		testing.expect(t, e.a.capture_id == "" && r.result.event == nil)
		destroy_env(&e)
	}
}
init_env :: proc(e: ^Env, t: ^testing.T) {e.p, _ = base.create(context.allocator); e.ctx =
		interaction.create(context.allocator, &e.p)
	e.s = controls.create()
	e.a = create(context.allocator)
	e.device = {
			window_id  = 1,
			gamepad_id = 9,
		}
	e.value = 50
	rebuild(e, t)}
destroy_env :: proc(e: ^Env) {destroy(&e.a); controls.destroy(&e.s); interaction.destroy(&e.ctx)
	layout.destroy_frame(&e.g)
	base.destroy(&e.p)}
rebuild :: proc(e: ^Env, t: ^testing.T) {
	stamp, _ := base.begin_attempt(&e.p, 1)
	ns := [2]layout.Node {
		{
			id = "slider",
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 300},
				y = {mode = .Fixed, value = 40},
			},
		},
		{
			id = "track",
			parent = "slider",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 20},
			},
		},
	}
	g, ge := layout.prepare(
		ns[:],
		{drawable = {300, 40}, ui_scale = 1},
		{},
		context.allocator,
		stamp,
	); testing.expect(t, ge.code == .None)
	ts := [1]interaction.Target {
		{"slider", "button", true, true},
	}; i, code := interaction.prepare(&g, ts[:], nil, context.allocator); testing.expect(t, code == .Applied)
	ds := [1]controls.Description {
		{
			id = "level",
			node_id = "slider",
			track_id = "track",
			kind = .Slider,
			maximum = 100,
			step = 10,
			value = e.value,
		},
	}
	c, ce := controls.prepare(
		&i,
		{},
		ds[:],
		context.allocator,
		&g,
	); testing.expect(t, ce.code == .None)
	base.enter_commit(
		&e.p,
		stamp,
	); interaction.commit(&e.ctx, &i, "slider"); controls.commit(&e.s, &c); old := e.g; e.g = g; base.finish_commit(&e.p, stamp); layout.destroy_frame(&old)
}
key :: proc(e: ^Env, k: sdl.Keycode, down: bool) -> backend.Normalized_Input {v: sdl.Event; v.key =
		{
			type     = .KEY_DOWN,
			windowID = 1,
			key      = k,
		}
	if !down {v.key.type = .KEY_UP}
	return backend.normalize_event(&e.device, &e.ctx, v, {300, 40})}

@(test)
slider_keyboard_and_gamepad_use_common_front_before_navigation :: proc(t: ^testing.T) {
	e: Env; init_env(&e, t); defer destroy_env(&e)
	for k, index in ([]sdl.Keycode{sdl.K_RIGHT, sdl.K_LEFT, sdl.K_HOME, sdl.K_END}) {
		r := handle(&e.a, &e.s, &e.ctx, &e.g, key(&e, k, true))
		want := [4]i64{60, 40, 0, 100}
		testing.expect(
			t,
			r.consumed &&
			r.result.event != nil &&
			r.result.event.?.value == want[index] &&
			e.p.sequence == u64(index + 1),
		)
		rebuild(&e, t)
		r = handle(
			&e.a,
			&e.s,
			&e.ctx,
			&e.g,
			key(&e, k, true),
		); testing.expect(t, r.result.event == nil && e.p.ready)
		handle(&e.a, &e.s, &e.ctx, &e.g, key(&e, k, false))
	}
	v: sdl.Event; v.gbutton = {
		type   = .GAMEPAD_BUTTON_DOWN,
		which  = 9,
		button = u8(sdl.GamepadButton.DPAD_RIGHT),
	}
	r := handle(&e.a, &e.s, &e.ctx, &e.g, backend.normalize_event(&e.device, &e.ctx, v, {300, 40}))
	testing.expect(t, r.consumed && r.result.event != nil && r.result.event.?.value == 60)
}

@(test)
slider_drag_continues_only_while_available_and_loss_release_clear_capture :: proc(t: ^testing.T) {
	e: Env; init_env(&e, t); defer destroy_env(&e)
	v: sdl.Event; v.button = {
		type     = .MOUSE_BUTTON_DOWN,
		windowID = 1,
		button   = 1,
		x        = 20,
		y        = 10,
	}
	r := handle(
		&e.a,
		&e.s,
		&e.ctx,
		&e.g,
		backend.normalize_event(&e.device, &e.ctx, v, {300, 40}),
	); testing.expect(t, r.result.event != nil && r.result.event.?.value == 20)
	e.value = 20; rebuild(&e, t)
	v.motion = {
		type     = .MOUSE_MOTION,
		windowID = 1,
		x        = 80,
		y        = 10,
	}
	r = handle(&e.a, &e.s, &e.ctx, &e.g, backend.normalize_event(&e.device, &e.ctx, v, {300, 40}))
	testing.expect(
		t,
		r.consumed &&
		r.result.event != nil &&
		r.result.event.?.value == 80 &&
		e.a.capture_id == "level",
	)
	v.window = {
		type     = .WINDOW_FOCUS_LOST,
		windowID = 1,
	}
	r = handle(&e.a, &e.s, &e.ctx, &e.g, backend.normalize_event(&e.device, &e.ctx, v, {300, 40}))
	testing.expect(t, e.a.capture_id == "" && r.result.event == nil && !e.p.ready)
}
