package main

import "core:testing"
import base "ui:ui_base"
import sdl "vendor:sdl3"

@(test)
sampled_input_geometry_controls_hit_and_slider_fraction_not_layout_label :: proc(t: ^testing.T) {
	r: Runtime; init(&r); defer destroy(&r)
	samples := [2]base.Geometry_Entry {
		{
			id = "slider",
			input_enabled = true,
			geometry = {
				scale = 2,
				opacity = 1,
				bounds = {100, 40, 200, 30},
				clip = {100, 40, 200, 30},
			},
		},
		{
			id = "track",
			input_enabled = true,
			geometry = {
				scale = 2,
				opacity = 1,
				bounds = {100, 40, 200, 20},
				clip = {100, 40, 200, 20},
			},
		},
	}
	testing.expect(t, publish(&r, samples[:]))
	a := button(&r, 150, 50, true)
	testing.expect(
		t,
		a.control.event != nil &&
		a.control.event.?.value == 30 &&
		r.controls_input.capture_id == "level",
	)
}

@(test)
stale_reader_blocks_wall_clock_and_rebases_before_recovery :: proc(t: ^testing.T) {
	r: Runtime; init(&r); defer destroy(&r); testing.expect(t, publish(&r))
	key_event(&r, sdl.K_TAB, true); key_event(&r, sdl.K_TAB, false); testing.expect(t, publish(&r))
	key_event(
		&r,
		sdl.K_TAB,
		true,
	); key_event(&r, sdl.K_TAB, false); testing.expect(t, publish(&r)); key_event(&r, sdl.K_SPACE, true); testing.expect(t, publish(&r))
	hold_step(&r, 0); r.reader.geometry.stamp.attempt += 1
	a := hold_step(&r, 500)
	testing.expect(
		t,
		a.code == .Not_Ready &&
		r.hold.live.elapsed_ms == 0 &&
		r.p.sequence == 0 &&
		!r.p.ready &&
		!r.hold_input.has_base,
	)
}

@(test)
sampled_scroll_wheel_uses_content_clip_not_outer_bounds :: proc(t: ^testing.T) {
	r: Runtime; init(&r); defer destroy(&r)
	samples := [1]base.Geometry_Entry {
		{
			id = "list",
			input_enabled = true,
			geometry = {
				scale = 1,
				opacity = 1,
				bounds = {0, 120, 100, 60},
				clip = {0, 120, 100, 60},
				content_clip = {20, 140, 40, 20},
			},
		},
	}
	testing.expect(t, publish(&r, samples[:]))
	e: sdl.Event; e.wheel = {
		type     = .MOUSE_WHEEL,
		windowID = 1,
		mouse_x  = 10,
		mouse_y  = 145,
		y        = -1,
	}
	a := input(
		&r,
		e,
	); testing.expect(t, !r.scroll.has_pending && a.scroll.code == .Not_Found && r.p.ready)
	e.wheel.mouse_x = 30; a = input(&r, e); testing.expect(t, r.scroll.has_pending && a.scroll.code == .Applied)
}

@(test)
scope_publication_cancels_slider_capture_before_any_next_event :: proc(t: ^testing.T) {
	r: Runtime; init(&r); defer destroy(&r); testing.expect(t, publish(&r)); button(&r, 20, 50, true)
	r.modal = true; testing.expect(t, publish(&r))
	testing.expect(t, r.controls_input.capture_id == "" && r.p.sequence == 1)
}

@(test)
stale_reader_never_starts_a_native_hold :: proc(t: ^testing.T) {
	r: Runtime; init(&r); defer destroy(&r); testing.expect(t, publish(&r))
	key_event(&r, sdl.K_TAB, true); key_event(&r, sdl.K_TAB, false); testing.expect(t, publish(&r))
	key_event(
		&r,
		sdl.K_TAB,
		true,
	); key_event(&r, sdl.K_TAB, false); testing.expect(t, publish(&r)); testing.expect(t, r.ctx.focus_id == "hold")
	r.reader.geometry.stamp.attempt += 1
	a := key_event(&r, sdl.K_SPACE, true)
	testing.expect(t, a.hold.count == 0 && r.hold.live.phase == .Idle && r.p.ready)
}

@(test)
sampled_track_discontinuity_cancels_existing_slider_drag :: proc(t: ^testing.T) {
	r: Runtime; init(&r); defer destroy(&r); testing.expect(t, publish(&r))
	a := button(&r, 20, 50, true); testing.expect(t, a.control.event != nil); r.value = 20
	samples := [2]base.Geometry_Entry {
		{
			id = "slider",
			input_enabled = true,
			geometry = {
				scale = 1,
				opacity = 1,
				bounds = {200, 40, 100, 30},
				clip = {200, 40, 100, 30},
			},
		},
		{
			id = "track",
			input_enabled = true,
			geometry = {
				scale = 1,
				opacity = 1,
				bounds = {200, 40, 100, 20},
				clip = {200, 40, 100, 20},
			},
		},
	}
	testing.expect(t, publish(&r, samples[:]))
	e: sdl.Event; e.motion = {
		type     = .MOUSE_MOTION,
		windowID = 1,
		x        = 20,
		y        = 50,
	}
	a = input(
		&r,
		e,
	); testing.expect(t, r.controls_input.capture_id == "" && a.control.event == nil && r.p.sequence == 1)
}

@(test)
invalid_sample_refuses_the_whole_publisher_before_any_swap :: proc(t: ^testing.T) {
	r: Runtime; init(&r); defer destroy(&r); testing.expect(t, publish(&r)); stamp := r.ctx.frame.stamp
	samples := [1]base.Geometry_Entry {
		{
			id = "slider",
			input_enabled = true,
			geometry = {scale = transmute(f64)u64(0x7ff8000000000000), opacity = 1},
		},
	}
	testing.expect(
		t,
		!publish(&r, samples[:]) &&
		!r.p.ready &&
		r.ctx.frame.stamp == stamp &&
		r.reader.geometry.stamp == stamp,
	)
}

@(test)
sampled_geometry_move_cancels_mouse_hold_before_clock_completion :: proc(t: ^testing.T) {
	r: Runtime; init(&r); defer destroy(&r); testing.expect(t, publish(&r))
	a := button(&r, 10, 90, true); testing.expect(t, a.hold.count == 1)
	samples := [1]base.Geometry_Entry {
		{
			id = "hold",
			input_enabled = true,
			geometry = {
				scale = 1,
				opacity = 1,
				bounds = {200, 80, 100, 30},
				clip = {200, 80, 100, 30},
			},
		},
	}
	testing.expect(t, publish(&r, samples[:]))
	hold_step(&r, 0); hold_step(&r, 500)
	testing.expect(
		t,
		r.hold.live.phase == .Idle && r.p.sequence == 0,
		"sampled pointer is outside moved hold, never completion",
	)
}

@(test)
foreign_window_repeat_and_not_ready_front_never_replay_after_rebuild :: proc(t: ^testing.T) {
	r: Runtime; init(&r); defer destroy(&r); testing.expect(t, publish(&r))
	e: sdl.Event; e.key = {
		type     = .KEY_DOWN,
		windowID = 99,
		key      = sdl.K_RETURN,
	}
	a := input(&r, e); testing.expect(t, !a.consumed && r.p.sequence == 0)
	base.invalidate(
		&r.p,
	); a = key_event(&r, sdl.K_RETURN, true); testing.expect(t, a.control.event == nil && r.p.sequence == 0)
	testing.expect(
		t,
		publish(&r),
	); a = key_event(&r, sdl.K_RETURN, true); testing.expect(t, a.control.event == nil && r.p.ready)
	key_event(
		&r,
		sdl.K_RETURN,
		false,
	); a = key_event(&r, sdl.K_RETURN, true); testing.expect(t, a.control.event != nil && r.p.sequence == 1)
}
