package ui_gestures_sdl
import fixture "../../../tests/ui_editing/gesture_fixture"
import backend "../../ui_sdl"
import "core:testing"
import sdl "vendor:sdl3"
@(test)
keyboard_gamepad_drag_selects_targets_without_ordinary_navigation :: proc(t: ^testing.T) {
	for gamepad in ([2]bool{false, true}) {
		r: fixture.Runtime; if !testing.expect(t, fixture.init(&r)) {return}; defer fixture.destroy(&r)
		if !testing.expect(t, fixture.publish(&r)) {return}
		a: Adapter; input := backend.Input {
			window_id  = 5,
			gamepad_id = 9,
		}
		e: sdl.Event
		if gamepad {e.gbutton = {
				type   = .GAMEPAD_BUTTON_DOWN,
				which  = 9,
				button = u8(sdl.GamepadButton.SOUTH),
			}} else {e.key = {
				type     = .KEY_DOWN,
				windowID = 5,
				key      = sdl.K_RETURN,
			}}
		x := event(
			&a,
			&input,
			&r.interaction,
			&r.gestures,
			&r.scroll,
			backend.normalize_event(&input, &r.interaction, e, {300, 100}),
		)
		if !testing.expect(
			t,
			x.consumed &&
			x.has_gesture &&
			x.gesture.code == .Applied &&
			r.gestures.live.phase == .Active,
		) {return}
		if gamepad {e.gbutton.type = .GAMEPAD_BUTTON_UP} else {e.key.type = .KEY_UP}
		x = event(
			&a,
			&input,
			&r.interaction,
			&r.gestures,
			&r.scroll,
			backend.normalize_event(&input, &r.interaction, e, {300, 100}),
		)
		testing.expect(t, x.consumed && !x.has_gesture && a.pending == nil)
		if !testing.expect(t, fixture.publish(&r)) {return}
		if gamepad {e.gbutton = {
				type   = .GAMEPAD_BUTTON_DOWN,
				which  = 9,
				button = u8(sdl.GamepadButton.DPAD_RIGHT),
			}} else {e.key = {
				type     = .KEY_DOWN,
				windowID = 5,
				key      = sdl.K_TAB,
			}}
		x = event(
			&a,
			&input,
			&r.interaction,
			&r.gestures,
			&r.scroll,
			backend.normalize_event(&input, &r.interaction, e, {300, 100}),
		)
		if !testing.expect(
			t,
			x.consumed &&
			x.has_gesture &&
			x.gesture.code == .Applied &&
			r.gestures.live.target_id == "drop" &&
			r.interaction.focus_id == "source",
		) {return}
		if !testing.expect(t, fixture.publish(&r)) {return}
		if gamepad {e.gbutton = {
				type   = .GAMEPAD_BUTTON_DOWN,
				which  = 9,
				button = u8(sdl.GamepadButton.SOUTH),
			}} else {e.key = {
				type     = .KEY_DOWN,
				windowID = 5,
				key      = sdl.K_RETURN,
			}}
		x = event(
			&a,
			&input,
			&r.interaction,
			&r.gestures,
			&r.scroll,
			backend.normalize_event(&input, &r.interaction, e, {300, 100}),
		)
		testing.expect(
			t,
			x.consumed && x.has_gesture && x.gesture.has_proposal && r.publication.sequence == 1,
		)
	}
}
