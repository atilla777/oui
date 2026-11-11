package ui_gestures_sdl
import fixture "../../../tests/ui_editing/gesture_fixture"
import base "../../ui_base"
import backend "../../ui_sdl"
import "core:testing"
import sdl "vendor:sdl3"
@(test)
repeat_clock_has_explicit_baselines_and_never_charges_failed_interval :: proc(t: ^testing.T) {
	r: fixture.Runtime; if !testing.expect(t, fixture.init(&r)) {return}; defer fixture.destroy(&r)
	if !testing.expect(t, fixture.publish(&r, "repeat")) {return}
	a: Adapter; input := backend.Input {
		window_id = 5,
	}
	e: sdl.Event; e.key = {
		type     = .KEY_DOWN,
		windowID = 5,
		key      = sdl.K_RETURN,
	}
	x := event(
		&a,
		&input,
		&r.interaction,
		&r.gestures,
		&r.scroll,
		backend.normalize_event(&input, &r.interaction, e, {300, 100}),
	)
	if !testing.expect(t, x.has_gesture && x.gesture.code == .Applied) {return}
	if !testing.expect(t, fixture.publish(&r, "repeat")) {return}
	testing.expect(t, r.scroll.frame.regions[0].offset == 24)
	x = step(&a, &input, &r.interaction, &r.gestures, &r.scroll, 1000)
	testing.expect(t, !x.has_gesture && a.clock.has_base)
	x = step(&a, &input, &r.interaction, &r.gestures, &r.scroll, 1300)
	if !testing.expect(t, x.has_gesture && x.gesture.code == .Applied) {return}
	if !testing.expect(t, fixture.publish(&r, "repeat")) {return}
	testing.expect(t, r.scroll.frame.regions[0].offset == 48)
	base.invalidate(&r.publication)
	step(&a, &input, &r.interaction, &r.gestures, &r.scroll, 100000)
	testing.expect(t, !a.clock.has_base)
	if !testing.expect(t, fixture.publish(&r, "repeat")) {return}
	x = step(&a, &input, &r.interaction, &r.gestures, &r.scroll, 100100)
	testing.expect(t, !x.has_gesture)
	x = step(&a, &input, &r.interaction, &r.gestures, &r.scroll, 100200)
	if !testing.expect(t, x.has_gesture) {return}
	if !testing.expect(t, fixture.publish(&r, "repeat")) {return}
	testing.expect(t, r.scroll.frame.regions[0].offset == 72)
	a.clock.deterministic = true
	x = step(&a, &input, &r.interaction, &r.gestures, &r.scroll, 999999)
	testing.expect(t, !x.has_gesture && !a.clock.has_base && r.gestures.live.elapsed_ms == 400)
	a.clock.deterministic = false
	step(&a, &input, &r.interaction, &r.gestures, &r.scroll, 100300)
	stamp := r.gestures.frame.stamp; r.gestures.frame.stamp.attempt -= 1
	x = step(&a, &input, &r.interaction, &r.gestures, &r.scroll, 200000)
	testing.expect(t, !x.has_gesture && !a.clock.has_base && r.gestures.live.elapsed_ms == 400)
	r.gestures.frame.stamp = stamp
	x = step(&a, &input, &r.interaction, &r.gestures, &r.scroll, 200100)
	testing.expect(t, !x.has_gesture && r.gestures.live.elapsed_ms == 400)
}
