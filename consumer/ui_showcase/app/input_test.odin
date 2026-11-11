package app

import model "../model"
import "core:os"
import "core:testing"
import controls "ui:ui_controls"
import layout "ui:ui_layout"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

@(test)
one_owner_held_input_values_and_navigation :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	surface := sdl.CreateSurface(
		800,
		600,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
	data, e := os.read_entire_file(
		"resources/font.ttf",
		context.allocator,
	); if !testing.expect(t, e == nil) {return}; defer delete(data)
	s := Shell {
		model     = model.initial(),
		font_data = data,
		renderer  = renderer,
		allocator = context.allocator,
		drawable  = {800, 600},
	}
	s.input.window_id = 17; s.input.gamepad_id = 9
	if !testing.expect(t, enter(&s)) {return}; defer destroy_shell(&s)
	testing.expect(t, dispatch(&s, {.Activate, "shell/controls", .Agent, false}))
	testing.expect(
		t,
		s.model.page == .Controls && s.runtime.interaction.focus_id == "controls/checkbox",
	)
	event: sdl.Event; event.key = {
		type     = .KEY_DOWN,
		windowID = 17,
		key      = sdl.K_RETURN,
	}
	testing.expect(t, handle_input(&s, event, {800, 600}) && s.model.checkbox)
	count := s.model.effects
	testing.expect(t, handle_input(&s, event, {800, 600}) && s.model.effects == count)
	testing.expect(t, dispatch(&s, {.Activate, "shell/layout", .Agent, false}))
	testing.expect(t, s.runtime.interaction.focus_id == "shell/controls")
	testing.expect(t, handle_input(&s, event, {800, 600}) && s.model.page == .Layout)
	event.key.type = .KEY_UP; handle_input(&s, event, {800, 600})
	event.key.type = .KEY_DOWN; handle_input(&s, event, {800, 600})
	testing.expect(
		t,
		s.model.page == .Controls &&
		s.model.checkbox &&
		s.runtime.interaction.focus_id == "controls/checkbox",
	)
	testing.expect(t, dispatch(&s, {.Focus, "controls/slider", .Agent, false}))
	event.key.key = sdl.K_END; handle_input(&s, event, {800, 600})
	testing.expect(t, s.model.slider == 100)
	event.key.type = .KEY_UP; handle_input(&s, event, {800, 600}); event.key.type = .KEY_DOWN; event.key.key = sdl.K_HOME
	handle_input(&s, event, {800, 600}); testing.expect(t, s.model.slider == 0)
	testing.expect(
		t,
		dispatch(&s, {.Activate, "shell/language", .Agent, false}) && s.model.locale == .English,
	)
	testing.expect(t, dispatch(&s, {.Activate, "shell/catalogue", .Agent, false}))
	testing.expect(t, dispatch(&s, {.Activate, "shell/controls", .Agent, false}))
	testing.expect(
		t,
		s.model.slider == 0 &&
		s.model.checkbox &&
		s.model.locale == .English &&
		s.runtime.interaction.focus_id == "controls/checkbox",
	)
	// One native track press and drag, without label-width substitution or a second normalizer.
	track, found := layout.find(
		&s.runtime.live.geometry,
		s.runtime.controls.frame.controls[2].track_id,
	)
	if !testing.expect(t, found) {return}
	x, y := f32(track.bounds.x + track.bounds.w / 4), f32(track.bounds.y + track.bounds.h / 2)
	event = {}; event.button = {
		type     = .MOUSE_BUTTON_DOWN,
		windowID = 17,
		button   = 1,
		x        = x,
		y        = y,
	}
	testing.expect(t, handle_input(&s, event, {800, 600}) && s.model.slider == 25)
	count =
		s.model.effects; handle_input(&s, event, {800, 600}); testing.expect(t, s.model.effects == count)
	event = {}; event.motion = {
		type     = .MOUSE_MOTION,
		windowID = 17,
		x        = x + 300,
		y        = y,
	}
	handle_input(&s, event, {800, 600}); testing.expect(t, s.model.slider == 100)
	testing.expect(
		t,
		dispatch(&s, {.Activate, "shell/layout", .Agent, false}) && s.input.mouse_down,
	)
	testing.expect(t, s.runtime.adapter.capture_id == "" && s.runtime.interaction.pressed_id == "")
	count = s.model.effects
	event = {}; event.button = {
		type     = .MOUSE_BUTTON_DOWN,
		windowID = 17,
		button   = 1,
		x        = 400,
		y        = 40,
	}
	handle_input(&s, event, {800, 600}); testing.expect(t, s.model.effects == count)
	event.button.type = .MOUSE_BUTTON_UP; handle_input(&s, event, {800, 600})
	testing.expect(t, dispatch(&s, {.Activate, "shell/controls", .Agent, false}))
	// Native gamepad fronts and semantic proposals share the checked reducer boundary.
	event = {}; event.gbutton = {
		type   = .GAMEPAD_BUTTON_DOWN,
		which  = 9,
		button = u8(sdl.GamepadButton.SOUTH),
	}
	before_bool :=
		s.model.checkbox; handle_input(&s, event, {800, 600}); testing.expect(t, s.model.checkbox != before_bool)
	count =
		s.model.effects; handle_input(&s, event, {800, 600}); testing.expect(t, s.model.effects == count)
	testing.expect(t, dispatch(&s, {.Activate, "shell/layout", .Agent, false}))
	handle_input(&s, event, {800, 600}); testing.expect(t, s.model.page == .Layout)
	event.gbutton.type = .GAMEPAD_BUTTON_UP; handle_input(&s, event, {800, 600})
	event.gbutton.type = .GAMEPAD_BUTTON_DOWN; handle_input(&s, event, {800, 600}); testing.expect(t, s.model.page == .Controls)
	testing.expect(t, dispatch(&s, {.Focus, "controls/slider", .Agent, false}))
	event.gbutton.button = u8(
		sdl.GamepadButton.DPAD_LEFT,
	); handle_input(&s, event, {800, 600}); testing.expect(t, s.model.slider == 99)
	count =
		s.model.effects; handle_input(&s, event, {800, 600}); testing.expect(t, s.model.effects == count)
	r := &s.runtime; stamp := r.live.text.stamp
	proposal := controls.dispatch(
		&r.controls,
		&r.interaction,
		{kind = .Set_Value, id = "controls/slider", source = .Agent, value = 37},
	)
	value, has := proposal.event.?; if !testing.expect(t, has) {return}
	testing.expect(
		t,
		s.model.slider == 99 && accept_control(r, stamp, value) && s.model.slider == 37,
	)
	testing.expect(t, !accept_control(r, stamp, value) && rebuild(r))
	testing.expect(t, !accept_control(r, stamp, value))
	count = s.model.effects
	invalid := controls.dispatch(
		&r.controls,
		&r.interaction,
		{kind = .Set_Value, id = "controls/slider", source = .Agent, value = 101},
	)
	testing.expect(t, invalid.dispatch.code == .Invalid_Action && s.model.effects == count)
	when TEST {
		s.fail_entry = true
		testing.expect(
			t,
			!dispatch(&s, {.Activate, "shell/layout", .Agent, false}) &&
			s.model.page == .Layout &&
			!s.runtime.publication.ready,
		)
		count = s.model.effects
		event = {}; event.gbutton = {
			type   = .GAMEPAD_BUTTON_UP,
			which  = 9,
			button = u8(sdl.GamepadButton.SOUTH),
		}
		handle_input(&s, event, {800, 600})
		testing.expect(
			t,
			!s.input.south_down &&
			recover(&s) &&
			s.model.effects == count &&
			s.runtime.interaction.focus_id == "shell/controls",
		)
	}
	// A mixed reader must not mint even a UI proposal, and ordinary input cannot recover it.
	r = &s.runtime
	old_stamp := r.live.text.stamp; sequence := r.publication.sequence; count = s.model.effects
	r.live.text.stamp.model_revision += 1
	event = {}; event.key = {
		type     = .KEY_UP,
		windowID = 17,
		key      = sdl.K_RETURN,
	}; handle_input(&s, event, {800, 600})
	event.key.type = .KEY_DOWN; handle_input(&s, event, {800, 600})
	testing.expect(
		t,
		r.publication.sequence == sequence && s.model.effects == count && !r.publication.ready,
	)
	r.live.text.stamp = old_stamp
	event = {}; event.window = {
		type     = .WINDOW_FOCUS_LOST,
		windowID = 17,
	}; handle_input(&s, event, {800, 600})
	testing.expect(
		t,
		s.input.suspended && r.adapter.capture_id == "" && r.interaction.pressed_id == "",
	)
	event = {}; event.key = {
		type     = .KEY_UP,
		windowID = 17,
		key      = sdl.K_RETURN,
	}; handle_input(&s, event, {800, 600})
	event = {}; event.window = {
		type     = .WINDOW_FOCUS_GAINED,
		windowID = 17,
	}; handle_input(&s, event, {800, 600})
	testing.expect(
		t,
		!s.input.suspended && !r.publication.ready && recover(&s) && s.model.effects == count,
	)
}
