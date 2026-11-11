package main

import "core:os"
import "core:testing"
import base "ui:ui_base"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

@(test)
menu_first_direction_after_selected_device_removal_is_not_swallowed :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	surface := sdl.CreateSurface(
		480,
		320,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
	data, error := os.read_entire_file(
		"resources/font.ttf",
		context.allocator,
	); if !testing.expect(t, error == nil) {return}; defer delete(data)
	for direction in ([]sdl.GamepadButton{.DPAD_UP, .DPAD_DOWN, .DPAD_LEFT, .DPAD_RIGHT}) {for blocked in ([]bool{false, true}) {
			r: Runtime; if !testing.expect(t, init(&r, renderer, data, 1, context.allocator)) {return}
			r.drawable = {
				480,
				320,
			}; r.input.window_id = 1; r.input.gamepad_id = 9; testing.expect(t, rebuild(&r))
			e: sdl.Event; e.gbutton = {
				type   = .GAMEPAD_BUTTON_DOWN,
				which  = 9,
				button = u8(direction),
			}; testing.expect(t, handle_input(&r, e, {480, 320}))
			testing.expect(t, r.interaction.focus_id == "open")
			e.window = {
				type     = .WINDOW_FOCUS_LOST,
				windowID = 1,
			}; handle_input(&r, e, {480, 320})
			e.window.type = .WINDOW_FOCUS_GAINED; handle_input(&r, e, {480, 320})
			e.gbutton = {
				type   = .GAMEPAD_BUTTON_DOWN,
				which  = 9,
				button = u8(direction),
			}
			handle_input(&r, e, {480, 320})
			testing.expect(t, r.interaction.focus_id == "open" && r.model.effects == 0)
			if blocked {base.invalidate(&r.publication)}
			e.gdevice = {
				type  = .GAMEPAD_REMOVED,
				which = 9,
			}; handle_input(&r, e, {480, 320})
			r.input.gamepad_id = 10; testing.expect(t, rebuild(&r))
			e.gbutton = {
				type   = .GAMEPAD_BUTTON_DOWN,
				which  = 10,
				button = u8(direction),
			}; testing.expect(t, handle_input(&r, e, {480, 320}))
			testing.expect(
				t,
				r.interaction.focus_id == "action" &&
				r.publication.sequence == 0 &&
				r.model.effects == 0,
				"new-device direction reaches ordinary menu navigation",
			)
			testing.expect(
				t,
				handle_input(&r, e, {480, 320}),
			); testing.expect(t, r.interaction.focus_id == "action" && r.publication.ready && r.model.effects == 0)
			destroy(&r)
		}}
}
