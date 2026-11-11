package ui_gestures_sdl
import fixture "../../../tests/ui_editing/gesture_fixture"
import backend "../../ui_sdl"
import "core:testing"
import sdl "vendor:sdl3"
@(test)
release_outside_window_cancels_instead_of_reusing_a_stale_drop_target :: proc(t: ^testing.T) {
	r: fixture.Runtime; if !testing.expect(t, fixture.init(&r)) {return}; defer fixture.destroy(&r)
	if !testing.expect(t, fixture.publish(&r)) {return}
	a: Adapter; input := backend.Input {
		window_id = 5,
	}
	e: sdl.Event; e.button = {
		type     = .MOUSE_BUTTON_DOWN,
		windowID = 5,
		button   = 1,
		x        = 10,
		y        = 10,
	}
	event(
		&a,
		&input,
		&r.interaction,
		&r.gestures,
		&r.scroll,
		backend.normalize_event(&input, &r.interaction, e, {300, 100}),
	)
	e.button = {
		type     = .MOUSE_BUTTON_UP,
		windowID = 5,
		button   = 1,
		x        = -1,
		y        = 10,
	}
	x := event(
		&a,
		&input,
		&r.interaction,
		&r.gestures,
		&r.scroll,
		backend.normalize_event(&input, &r.interaction, e, {300, 100}),
	)
	testing.expect(
		t,
		x.consumed &&
		r.gestures.live.phase == .Idle &&
		r.gestures.live.reason == .Pointer_Left &&
		a.pending == nil &&
		r.publication.sequence == 0,
	)
}
@(test)
matching_loss_cancels_even_not_ready_without_activating_historical_frame :: proc(t: ^testing.T) {
	for kind in ([3]sdl.EventType{.WINDOW_FOCUS_LOST, .WINDOW_HIDDEN, .WINDOW_MOUSE_LEAVE}) {
		r: fixture.Runtime; if !testing.expect(t, fixture.init(&r)) {return}; defer fixture.destroy(&r)
		if !testing.expect(t, fixture.publish(&r)) {return}
		a: Adapter; input := backend.Input {
			window_id = 5,
		}
		e: sdl.Event; e.button = {
			type     = .MOUSE_BUTTON_DOWN,
			windowID = 5,
			button   = 1,
			x        = 10,
			y        = 10,
		}
		event(
			&a,
			&input,
			&r.interaction,
			&r.gestures,
			&r.scroll,
			backend.normalize_event(&input, &r.interaction, e, {300, 100}),
		)
		e.window = {
			type     = kind,
			windowID = 5,
		}
		x := event(
			&a,
			&input,
			&r.interaction,
			&r.gestures,
			&r.scroll,
			backend.normalize_event(&input, &r.interaction, e, {300, 100}),
		)
		testing.expect(
			t,
			x.consumed &&
			x.gesture.count == 1 &&
			x.gesture.signals[0].kind == .Cancelled &&
			r.gestures.live.phase == .Idle &&
			r.gestures.live.reason != .None &&
			r.publication.sequence == 0 &&
			a.pending == nil &&
			!r.publication.ready,
		)
	}
}
