package main

import "core:fmt"
import "core:mem"
import "core:os"
import controls "ui:ui_controls"
import sdl "vendor:sdl3"

// Deterministic native-event fixture: no SDL window/device/renderer is opened.
main :: proc() {
	if len(os.args) == 4 &&
	   os.args[1] ==
		   "--software-render" {if !software_render_main(os.args[2], os.args[3]) {os.exit(1)}; return}
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	previous :=
		context.allocator; context.allocator = mem.tracking_allocator(&tracking); defer {context.allocator = previous}
	r: Runtime; init(&r); assert(publish(&r))
	e: sdl.Event; e.key = {
		type     = .KEY_DOWN,
		windowID = 1,
		key      = sdl.K_RETURN,
	}
	a := input(
		&r,
		e,
	); assert(a.control.event != nil && a.control.event.?.checked); effects := 1; r.checked = true; assert(publish(&r))
	e.key.type = .KEY_UP; input(&r, e)
	e.wheel = {
		type     = .MOUSE_WHEEL,
		windowID = 1,
		mouse_x  = 10,
		mouse_y  = 140,
		y        = -1,
	}; a = input(&r, e); assert(a.scroll.code == .Applied); assert(publish(&r))
	controls.dispatch(
		&r.controls,
		&r.ctx,
		{kind = .Focus, id = "hold", source = .Agent},
		&r.layers,
		&r.scroll,
	); assert(publish(&r))
	e.key = {
		type     = .KEY_DOWN,
		windowID = 1,
		key      = sdl.K_SPACE,
	}; a = input(&r, e); assert(a.hold.count == 1); assert(publish(&r))
	hold_step(
		&r,
		0,
	); a.hold = hold_step(&r, 500); assert(a.hold.dispatch.has_event); effects += 1; assert(publish(&r))
	e.key.type = .KEY_UP; input(&r, e); assert(publish(&r))
	r.modal = true; assert(publish(&r)); e.key = {
		type     = .KEY_DOWN,
		windowID = 1,
		key      = sdl.K_ESCAPE,
	}; a = input(
		&r,
		e,
	); assert(a.control.event != nil && a.control.cancel != nil); effects += 1; r.modal = false; assert(publish(&r))
	live := tracking.current_memory_allocated
	for _ in 0 ..< 64 {assert(publish(&r)); assert(tracking.current_memory_allocated == live)}
	fmt.printf(
		"selected-input effects=%d sequence=%d Runtime=%d Reader=%d allocations=%d bytes=%d live=%d peak=%d backend-resources=0\n",
		effects,
		r.p.sequence,
		size_of(Runtime),
		size_of(Reader),
		tracking.total_allocation_count,
		tracking.total_memory_allocated,
		tracking.current_memory_allocated,
		tracking.peak_memory_allocated,
	)
	saved :=
		r.reader; r.reader = {}; destroy(&r); assert(!saved.layers.stamp.lifetime.alive && saved.controls.controls[0].checked); destroy_reader(&saved)
	fmt.printf(
		"destroy live=%d bad-frees=%d\n",
		tracking.current_memory_allocated,
		len(tracking.bad_free_array),
	); assert(tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
}
