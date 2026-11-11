package main

import "core:testing"
import controls "ui:ui_controls"
import sdl "vendor:sdl3"

@(test)
opening_modal_cancels_selected_hold_without_rearming_the_held_native_edge :: proc(t: ^testing.T) {
	r: Runtime; init(&r); defer destroy(&r); testing.expect(t, publish(&r))
	controls.dispatch(
		&r.controls,
		&r.ctx,
		{kind = .Focus, id = "hold", source = .Agent},
		&r.layers,
		&r.scroll,
	); testing.expect(t, publish(&r))
	key_event(&r, sdl.K_SPACE, true); testing.expect(t, publish(&r))
	r.modal = true; testing.expect(t, publish(&r))
	testing.expect(
		t,
		r.hold.live.phase == .Idle &&
		r.hold.frame.result.count == 1 &&
		r.hold.frame.result.signals[0].reason == .Unavailable &&
		r.p.sequence == 0,
	)
	r.modal = false; testing.expect(t, publish(&r))
	key_event(
		&r,
		sdl.K_SPACE,
		true,
	); testing.expect(t, r.hold.live.phase == .Idle && r.hold.live.cycle == 1 && r.p.sequence == 0 && r.p.ready)
}

@(test)
gamepad_removal_old_device_edges_and_selected_reattach_do_not_duplicate_completion :: proc(
	t: ^testing.T,
) {
	r: Runtime; init(&r); defer destroy(&r); testing.expect(t, publish(&r))
	controls.dispatch(
		&r.controls,
		&r.ctx,
		{kind = .Focus, id = "hold", source = .Agent},
		&r.layers,
		&r.scroll,
	); testing.expect(t, publish(&r))
	e: sdl.Event; e.gbutton = {
		type   = .GAMEPAD_BUTTON_DOWN,
		which  = 9,
		button = u8(sdl.GamepadButton.SOUTH),
	}; input(&r, e)
	e.gdevice = {
		type  = .GAMEPAD_REMOVED,
		which = 9,
	}; input(&r, e); testing.expect(t, publish(&r)); hold_step(&r, 0)
	testing.expect(
		t,
		r.hold.live.phase == .Idle && r.p.sequence == 0,
	); testing.expect(t, publish(&r))
	e.gbutton = {
		type   = .GAMEPAD_BUTTON_DOWN,
		which  = 9,
		button = u8(sdl.GamepadButton.SOUTH),
	}; input(&r, e); testing.expect(t, r.hold.live.cycle == 1 && r.p.ready)
	// Deterministic device-open boundary: attach a newly selected ID. No actual
	// hardware/open-success claim; subsequent native identity/edges are real code.
	r.device.gamepad_id = 10; e.gbutton.which = 10
	input(
		&r,
		e,
	); testing.expect(t, publish(&r)); input(&r, e); testing.expect(t, r.hold.live.cycle == 2 && r.p.sequence == 0)
	hold_step(
		&r,
		0,
	); out := hold_step(&r, 500); testing.expect(t, out.dispatch.has_event && r.p.sequence == 1)
}
