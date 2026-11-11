package ui_sdl

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:testing"
import sdl "vendor:sdl3"

@(test)
keyboard_common_dispatch_and_loss :: proc(t: ^testing.T) {
	p, e := base.create(context.allocator); testing.expect(t, e == .None); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s, _ := base.begin_attempt(&p, 0)
	nodes := [1]layout.Node {
		{
			id = "action",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 50},
			},
		},
	}
	g, ge := layout.prepare(
		nodes[:],
		{drawable = {800, 600}, ui_scale = 1},
		{},
		context.allocator,
		s,
	)
	testing.expect(t, ge.code == .None); defer layout.destroy_frame(&g)
	targets := [1]interaction.Target{{"action", "button", true, true}}
	c, ce := interaction.prepare(&g, targets[:], nil, context.allocator)
	testing.expect(t, ce == .Applied)
	testing.expect(
		t,
		base.enter_commit(&p, s) == .None,
	); interaction.commit(&ctx, &c, "action"); base.finish_commit(&p, s)
	testing.expect(t, ctx.focus_id == "action")
	i := Input {
		window_id = 5,
	}
	testing.expect(t, interaction.begin_pointer_press(&ctx, "action") == .Applied)
	testing.expect(t, ctx.focus_id == "action" && ctx.pressed_id == "action" && !p.ready)
	interaction.cancel_press(&ctx)
	base.finish_commit(&p, s)
	event: sdl.Event
	event.key = {
		type     = .KEY_DOWN,
		windowID = 5,
		key      = sdl.K_RETURN,
	}
	r := input_event(&i, &ctx, event, {800, 600})
	testing.expect(t, r.dispatch.has_event && r.dispatch.event.id == "action" && p.sequence == 1)
	testing.expect(t, !input_event(&i, &ctx, event, {800, 600}).dispatch.has_event)
	base.finish_commit(&p, s)
	testing.expect(
		t,
		interaction.observe_pointer(&ctx, 10, 10) == .Applied && ctx.hover_id == "action",
	)
	event.window = {
		type     = .WINDOW_FOCUS_LOST,
		windowID = 5,
	}
	input_event(&i, &ctx, event, {800, 600})
	testing.expect(t, i.suspended)
	testing.expect(t, ctx.hover_id == "" && ctx.pressed_id == "")
	i.suspended = false
	base.finish_commit(&p, s)
	event.button = {
		type     = .MOUSE_BUTTON_DOWN,
		windowID = 5,
		button   = 1,
		x        = 10,
		y        = 10,
	}
	input_event(&i, &ctx, event, {800, 600})
	testing.expect(t, ctx.pressed_id == "action" && !p.ready)
	base.finish_commit(&p, s)
	event.button.type = .MOUSE_BUTTON_UP
	testing.expect(t, input_event(&i, &ctx, event, {800, 600}).dispatch.has_event)
	testing.expect(t, !input_event(&i, &ctx, event, {800, 600}).dispatch.has_event)
	base.finish_commit(&p, s)
	i.gamepad_id = 9
	event.gbutton = {
		type   = .GAMEPAD_BUTTON_DOWN,
		which  = 9,
		button = u8(sdl.GamepadButton.SOUTH),
	}
	testing.expect(t, input_event(&i, &ctx, event, {800, 600}).dispatch.has_event)
	base.finish_commit(&p, s)
	testing.expect(t, !input_event(&i, &ctx, event, {800, 600}).dispatch.has_event)
	event.gbutton.type = .GAMEPAD_BUTTON_UP
	input_event(&i, &ctx, event, {800, 600})
	event.gbutton.type = .GAMEPAD_BUTTON_DOWN
	testing.expect(t, input_event(&i, &ctx, event, {800, 600}).dispatch.has_event)
}
