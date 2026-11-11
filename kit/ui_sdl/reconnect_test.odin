package ui_sdl

import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"
import sdl "vendor:sdl3"

@(test)
selected_device_removal_resets_each_direction_without_resetting_other_physical_latches :: proc(
	t: ^testing.T,
) {
	for direction in ([]sdl.GamepadButton{.DPAD_UP, .DPAD_DOWN, .DPAD_LEFT, .DPAD_RIGHT}) {for blocked in ([]bool{false, true}) {
			p, _ := base.create(
				context.allocator,
			); ctx := interaction.create(context.allocator, &p); publish_input_fixture(t, &p, &ctx)
			i := Input {
				window_id  = 5,
				gamepad_id = 9,
				keys_down  = {.Return},
				mouse_down = true,
			}
			e: sdl.Event; e.gbutton = {
				type   = .GAMEPAD_BUTTON_DOWN,
				which  = 9,
				button = u8(direction),
			}
			n := normalize_event(
				&i,
				&ctx,
				e,
				{800, 600},
			); testing.expect(t, n.front && n.has_action)
			if blocked {base.invalidate(&p)}
			e.gdevice = {
				type  = .GAMEPAD_REMOVED,
				which = 99,
			}; n = normalize_event(
				&i,
				&ctx,
				e,
				{800, 600},
			); testing.expect(t, !n.accepted && !n.loss && i.gamepad_id == 9)
			e.gdevice.which = 9; n = normalize_event(&i, &ctx, e, {800, 600})
			testing.expect(
				t,
				n.loss && i.gamepad_id == 0 && i.directions_down == ([4]bool{}),
				"selected removal clears every device-owned direction even while unavailable",
			)
			testing.expect(
				t,
				.Return in i.keys_down &&
				i.mouse_down &&
				!i.hidden &&
				!i.unfocused &&
				!i.suspended,
			)
			// Model only successful new-device selection, not actual hardware opening.
			i.gamepad_id = 10; e.gbutton = {
				type   = .GAMEPAD_BUTTON_DOWN,
				which  = 9,
				button = u8(direction),
			}
			n = normalize_event(&i, &ctx, e, {800, 600}); testing.expect(t, !n.accepted)
			e.gbutton.which = 10; n = normalize_event(&i, &ctx, e, {800, 600}); testing.expect(t, n.front && n.has_action, "first genuine new-device direction must not inherit the removed device's latch")
			r := dispatch_input(&ctx, n)
			if blocked {testing.expect(t, r.dispatch.code == .Not_Ready && r.consumed)} else {testing.expect(t, r.dispatch.code == .Applied && r.consumed && !p.ready)}
			publish_input_fixture(t, &p, &ctx)
			n = normalize_event(
				&i,
				&ctx,
				e,
				{800, 600},
			); testing.expect(t, !n.front && !n.has_action); dispatch_input(&ctx, n); testing.expect(t, p.ready && p.sequence == 0)
			e.gbutton.type = .GAMEPAD_BUTTON_UP; normalize_event(&i, &ctx, e, {800, 600}); e.gbutton.type = .GAMEPAD_BUTTON_DOWN
			n = normalize_event(
				&i,
				&ctx,
				e,
				{800, 600},
			); r = dispatch_input(&ctx, n); testing.expect(t, n.front && r.consumed && r.dispatch.code == .Applied && !p.ready && p.sequence == 0)
			close_input(
				&i,
			); testing.expect(t, i.directions_down == ([4]bool{}) && .Return in i.keys_down && i.mouse_down)
			interaction.destroy(&ctx); base.destroy(&p)
		}}
}

@(test)
window_loss_does_not_rearm_the_same_pad_or_held_keyboard_and_mouse :: proc(t: ^testing.T) {
	for direction in ([]sdl.GamepadButton{.DPAD_UP, .DPAD_DOWN, .DPAD_LEFT, .DPAD_RIGHT}) {for hidden in ([]bool{false, true}) {
			p, _ := base.create(
				context.allocator,
			); ctx := interaction.create(context.allocator, &p); publish_input_fixture(t, &p, &ctx)
			i := Input {
				window_id  = 5,
				gamepad_id = 9,
				keys_down  = {.Return},
				mouse_down = true,
			}
			e: sdl.Event; e.gbutton = {
				type   = .GAMEPAD_BUTTON_DOWN,
				which  = 9,
				button = u8(direction),
			}; normalize_event(&i, &ctx, e, {800, 600})
			e.window = {
				type     = .WINDOW_FOCUS_LOST,
				windowID = 5,
			}; if hidden {e.window.type = .WINDOW_HIDDEN}; normalize_event(&i, &ctx, e, {800, 600})
			testing.expect(t, i.suspended)
			e.window.type = .WINDOW_FOCUS_GAINED; if hidden {e.window.type = .WINDOW_SHOWN}; normalize_event(&i, &ctx, e, {800, 600})
			e.gbutton = {
				type   = .GAMEPAD_BUTTON_DOWN,
				which  = 9,
				button = u8(direction),
			}; n := normalize_event(
				&i,
				&ctx,
				e,
				{800, 600},
			); testing.expect(t, !n.front && !n.has_action)
			e.key = {
				type     = .KEY_DOWN,
				windowID = 5,
				key      = sdl.K_RETURN,
			}; n = normalize_event(
				&i,
				&ctx,
				e,
				{800, 600},
			); testing.expect(t, !n.front && !n.has_action)
			e.button = {
				type     = .MOUSE_BUTTON_DOWN,
				windowID = 5,
				button   = 1,
				x        = 10,
				y        = 10,
			}; n = normalize_event(
				&i,
				&ctx,
				e,
				{800, 600},
			); testing.expect(t, !n.front && p.sequence == 0)
			close_input(&i); interaction.destroy(&ctx); base.destroy(&p)
		}}
}
