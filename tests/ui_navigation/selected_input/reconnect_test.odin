package main

import "core:testing"
import base "ui:ui_base"
import controls "ui:ui_controls"
import sdl "vendor:sdl3"

@(test)
directional_reconnect_reaches_slider_and_list_once_after_new_selection :: proc(t: ^testing.T) {
	for direction in ([]sdl.GamepadButton{.DPAD_UP, .DPAD_DOWN, .DPAD_LEFT, .DPAD_RIGHT}) {for blocked in ([]bool{false, true}) {
			r: Runtime; init(&r); testing.expect(t, publish(&r))
			slider := direction == .DPAD_LEFT || direction == .DPAD_RIGHT
			id := "4:list1:b"; if slider {id = "slider"}
			controls.dispatch(
				&r.controls,
				&r.ctx,
				{kind = .Focus, id = id, source = .Agent},
				&r.layers,
				&r.scroll,
			); testing.expect(t, publish(&r))
			e: sdl.Event; e.gbutton = {
				type   = .GAMEPAD_BUTTON_DOWN,
				which  = 9,
				button = u8(direction),
			}
			a := input(&r, e)
			if slider {if testing.expect(t, a.control.event != nil) {r.value = a.control.event.?.value}} else {testing.expect(t, r.scroll.has_pending)}
			testing.expect(t, publish(&r))
			e.window = {
				type     = .WINDOW_FOCUS_LOST,
				windowID = 1,
			}; input(&r, e)
			e.window.type = .WINDOW_FOCUS_GAINED; input(&r, e)
			testing.expect(t, publish(&r))
			e.gbutton = {
				type   = .GAMEPAD_BUTTON_DOWN,
				which  = 9,
				button = u8(direction),
			}
			a = input(&r, e)
			testing.expect(t, a.control.event == nil && !r.scroll.has_pending && r.p.ready)
			if blocked {base.invalidate(&r.p)}
			e.gdevice = {
				type  = .GAMEPAD_REMOVED,
				which = 9,
			}; input(&r, e)
			r.device.gamepad_id = 10; testing.expect(t, publish(&r))
			e.gbutton = {
				type   = .GAMEPAD_BUTTON_DOWN,
				which  = 10,
				button = u8(direction),
			}; a = input(&r, e)
			if slider {want := i64(70); if direction == .DPAD_LEFT {want = 30}; testing.expect(t, a.control.event != nil && a.control.event.?.value == want && r.p.sequence == 2)
			} else {testing.expect(
					t,
					r.scroll.has_pending &&
					a.control.dispatch.code == .Applied &&
					!r.p.ready &&
					r.p.sequence == 0,
				)}
			testing.expect(t, publish(&r)); a = input(&r, e)
			testing.expect(
				t,
				a.control.event == nil && !r.scroll.has_pending && r.p.ready,
				"repeat of the new-device direction is still one shared edge",
			)
			destroy(&r)
		}}
}
