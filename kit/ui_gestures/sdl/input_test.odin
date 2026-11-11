package ui_gestures_sdl
import fixture "../../../tests/ui_editing/gesture_fixture"
import backend "../../ui_sdl"
import "core:testing"
import sdl "vendor:sdl3"
@(test)
pointer_release_before_rebuild_flushes_move_then_one_drop :: proc(t: ^testing.T) {
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
	n := backend.normalize_event(&input, &r.interaction, e, {300, 100})
	x := event(&a, &input, &r.interaction, &r.gestures, &r.scroll, n)
	if !testing.expect(
		t,
		x.consumed &&
		x.has_gesture &&
		x.gesture.code == .Applied &&
		r.gestures.live.phase == .Armed,
	) {return}
	e.button = {
		type     = .MOUSE_BUTTON_UP,
		windowID = 5,
		button   = 1,
		x        = 75,
		y        = 10,
	}
	x = event(
		&a,
		&input,
		&r.interaction,
		&r.gestures,
		&r.scroll,
		backend.normalize_event(&input, &r.interaction, e, {300, 100}),
	)
	testing.expect(t, x.consumed && !x.has_gesture && a.pending != nil && a.pending_point != nil)
	if !testing.expect(t, fixture.publish(&r)) {return}
	x = step(&a, &input, &r.interaction, &r.gestures, &r.scroll, 0)
	if !testing.expect(
		t,
		x.has_gesture && x.gesture.code == .Applied && r.gestures.live.target_id == "drop",
	) {return}
	if !testing.expect(t, fixture.publish(&r)) {return}
	x = step(&a, &input, &r.interaction, &r.gestures, &r.scroll, 0)
	testing.expect(
		t,
		x.has_gesture && x.gesture.has_proposal && r.publication.sequence == 1 && a.pending == nil,
	)
}
