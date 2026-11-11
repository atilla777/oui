package main

import "core:testing"
import controls "ui:ui_controls"
import sdl "vendor:sdl3"

button :: proc(r: ^Runtime, x, y: f32, down: bool) -> Input_Result {e: sdl.Event; e.button = {
		type     = .MOUSE_BUTTON_DOWN,
		windowID = 1,
		button   = 1,
		x        = x,
		y        = y,
	}; if !down {e.button.type = .MOUSE_BUTTON_UP}; return input(r, e)}
key_event :: proc(r: ^Runtime, k: sdl.Keycode, down: bool) -> Input_Result {e: sdl.Event; e.key = {
		type     = .KEY_DOWN,
		windowID = 1,
		key      = k,
	}; if !down {e.key.type = .KEY_UP}; return input(r, e)}

@(test)
composed_pointer_checkbox_uses_control_dispatch_once_not_base_activation :: proc(t: ^testing.T) {
	r: Runtime; init(&r); defer destroy(&r); testing.expect(t, publish(&r))
	a := button(
		&r,
		10,
		10,
		true,
	); testing.expect(t, a.consumed && a.control.event == nil && r.ctx.pressed_id == "check" && !r.p.ready)
	testing.expect(t, publish(&r)); a = button(&r, 10, 10, false)
	testing.expect(
		t,
		a.control.event != nil &&
		a.control.event.?.kind == .Bool &&
		a.control.event.?.checked &&
		r.p.sequence == 1 &&
		!r.checked,
	)
	r.checked =
		true; testing.expect(t, publish(&r)); a = button(&r, 10, 10, false); testing.expect(t, a.control.event == nil && r.p.sequence == 1)
}

@(test)
popup_shields_slider_and_cancel_priority_is_selected_scope_only :: proc(t: ^testing.T) {
	r: Runtime; init(&r); defer destroy(&r); r.popup = true; testing.expect(t, publish(&r))
	a := button(
		&r,
		60,
		60,
		true,
	); testing.expect(t, a.control.event == nil && r.controls_input.capture_id == "" && r.p.sequence == 0 && r.ctx.pressed_id == "")
	a = key_event(
		&r,
		sdl.K_ESCAPE,
		true,
	); testing.expect(t, a.control.event != nil && a.control.event.?.kind == .Close && a.control.event.?.control_id == "choice")
	r.popup = false; key_event(&r, sdl.K_ESCAPE, false); testing.expect(t, publish(&r))
	r.modal = true; testing.expect(t, publish(&r)); a = key_event(&r, sdl.K_ESCAPE, true)
	testing.expect(
		t,
		a.control.event != nil &&
		a.control.event.?.kind == .Result &&
		a.control.event.?.control_id == "dialog" &&
		a.control.cancel != nil &&
		r.p.sequence == 2,
	)
}

@(test)
wheel_and_list_navigation_use_scroll_owner_and_commit_pending_focus :: proc(t: ^testing.T) {
	r: Runtime; init(&r); defer destroy(&r); testing.expect(t, publish(&r))
	e: sdl.Event; e.wheel = {
		type     = .MOUSE_WHEEL,
		windowID = 1,
		mouse_x  = 10,
		mouse_y  = 140,
		y        = -1,
	}
	a := input(
		&r,
		e,
	); testing.expect(t, a.consumed && a.scroll.code == .Applied && r.scroll.has_pending && !r.p.ready)
	testing.expect(
		t,
		publish(&r),
	); testing.expect(t, r.scroll.frame.regions[0].offset > 0 && r.p.sequence == 0)
	controls.dispatch(
		&r.controls,
		&r.ctx,
		{kind = .Focus, id = "4:list1:a", source = .Agent},
		&r.layers,
		&r.scroll,
	); testing.expect(t, publish(&r))
	a = key_event(
		&r,
		sdl.K_DOWN,
		true,
	); testing.expect(t, a.control.dispatch.code == .Applied && r.scroll.has_pending)
	testing.expect(
		t,
		publish(&r),
	); testing.expect(t, r.ctx.focus_id == "4:list1:b" && r.p.sequence == 0)
	a = key_event(
		&r,
		sdl.K_DOWN,
		true,
	); testing.expect(t, !r.scroll.has_pending && r.p.ready, "repeat front cannot create second pending move")
}

@(test)
hold_native_capture_consumes_front_and_release_while_blocked :: proc(t: ^testing.T) {
	r: Runtime; init(&r); defer destroy(&r); testing.expect(t, publish(&r))
	controls.dispatch(
		&r.controls,
		&r.ctx,
		{kind = .Focus, id = "hold", source = .Agent},
		&r.layers,
		&r.scroll,
	); testing.expect(t, publish(&r))
	a := key_event(
		&r,
		sdl.K_SPACE,
		true,
	); testing.expect(t, a.hold.count == 1 && r.hold.live.phase == .Holding && r.p.sequence == 0)
	a = key_event(
		&r,
		sdl.K_SPACE,
		false,
	); testing.expect(t, a.consumed && r.hold_input.has_pending && r.hold.live.phase == .Holding)
	testing.expect(t, publish(&r))
	hold_step(&r, 900000)
	testing.expect(t, r.hold.live.phase == .Idle && r.p.sequence == 0 && !r.hold_input.has_pending)
}
