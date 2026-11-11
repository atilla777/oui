package main

import "core:mem"
import "core:testing"
import sdl "vendor:sdl3"

@(test)
popup_item_and_modal_pointer_results_remain_controlled :: proc(t: ^testing.T) {
	r: Runtime; init(&r); defer destroy(&r); r.popup = true; testing.expect(t, publish(&r))
	button(&r, 10, 50, true); testing.expect(t, publish(&r)); a := button(&r, 10, 50, false)
	testing.expect(
		t,
		a.control.event != nil &&
		a.control.event.?.kind == .Item &&
		a.control.event.?.item_id == "item" &&
		r.popup &&
		r.p.sequence == 1,
	)
	r.popup = false; r.modal = true; testing.expect(t, publish(&r))
	button(&r, 210, 10, true); testing.expect(t, publish(&r)); a = button(&r, 210, 10, false)
	testing.expect(
		t,
		a.control.event != nil &&
		a.control.event.?.kind == .Result &&
		r.modal &&
		r.p.sequence == 2,
	)
}

@(test)
native_gamepad_cancel_front_loss_and_pending_hold_completion_are_single_effects :: proc(
	t: ^testing.T,
) {
	r: Runtime; init(&r); defer destroy(&r); r.modal = true; testing.expect(t, publish(&r))
	e: sdl.Event; e.gbutton = {
		type   = .GAMEPAD_BUTTON_DOWN,
		which  = 9,
		button = u8(sdl.GamepadButton.EAST),
	}
	a := input(
		&r,
		e,
	); testing.expect(t, a.control.cancel != nil && a.control.event != nil && r.p.sequence == 1)
	testing.expect(
		t,
		publish(&r),
	); a = input(&r, e); testing.expect(t, a.control.event == nil && r.p.ready)
	e.gbutton.type = .GAMEPAD_BUTTON_UP; input(&r, e)
	r.modal = false; testing.expect(t, publish(&r))
	button(&r, 10, 90, true); testing.expect(t, publish(&r)); hold_step(&r, 0)
	a.hold = hold_step(&r, 500); testing.expect(t, a.hold.dispatch.has_event && r.p.sequence == 2)
	testing.expect(
		t,
		publish(&r),
	); a.hold = hold_step(&r, 1000); testing.expect(t, !a.hold.dispatch.has_event && r.p.sequence == 2)
	button(&r, 10, 90, false); testing.expect(t, publish(&r))
	button(&r, 10, 90, true)
	e.window = {
		type     = .WINDOW_FOCUS_LOST,
		windowID = 1,
	}; input(&r, e)
	testing.expect(t, r.hold_input.has_pending)
	testing.expect(t, publish(&r)); hold_step(&r, 900000)
	testing.expect(t, r.hold.live.phase == .Idle && r.p.sequence == 2)
}

@(test)
reader_survives_all_runtime_owners_and_rebuilds_do_not_accumulate_history :: proc(t: ^testing.T) {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	tracking.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	previous :=
		context.allocator; context.allocator = mem.tracking_allocator(&tracking); defer {context.allocator = previous}
	r: Runtime; init(&r); testing.expect(t, publish(&r)); live := tracking.current_memory_allocated
	for _ in 0 ..< 64 {testing.expect(t, publish(&r)); testing.expect(t, tracking.current_memory_allocated == live)}
	saved := r.reader; r.reader = {}; destroy(&r)
	testing.expect(
		t,
		!saved.layers.stamp.lifetime.alive &&
		saved.controls.controls[0].id == "checked" &&
		saved.hold.holds[0].id == "hold" &&
		saved.scroll.regions[0].id == "list",
	)
	destroy_reader(
		&saved,
	); testing.expect(t, tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
}

@(test)
runtime_destroy_closes_the_single_device_owner :: proc(t: ^testing.T) {
	r: Runtime; init(&r); destroy(&r)
	testing.expect(t, r.device.gamepad_id == 0 && r.device.gamepad == nil)
}
