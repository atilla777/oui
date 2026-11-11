package ui_sdl

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:testing"
import sdl "vendor:sdl3"

@(test)
physical_latches_survive_loss_and_specialization_precedes_hover :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	publish_input_fixture(t, &p, &ctx)
	i := Input {
		window_id  = 5,
		gamepad_id = 9,
	}
	e: sdl.Event; e.motion = {
		type     = .MOUSE_MOTION,
		windowID = 5,
		x        = 10,
		y        = 10,
	}
	n := normalize_event(&i, &ctx, e, {800, 600})
	testing.expect(
		t,
		p.ready && ctx.hover_id == "",
		"normalization must not select ordinary hover before layer specialization",
	)
	dispatch_input(&ctx, n)
	testing.expect(t, ctx.hover_id == "action")
	publish_input_fixture(t, &p, &ctx)
	e.key = {
		type     = .KEY_DOWN,
		windowID = 5,
		key      = sdl.K_RETURN,
	}
	n = normalize_event(&i, &ctx, e, {800, 600}); testing.expect(t, n.front)
	e.window = {
		type     = .WINDOW_FOCUS_LOST,
		windowID = 5,
	}; normalize_event(&i, &ctx, e, {800, 600})
	e.window.type = .WINDOW_FOCUS_GAINED; normalize_event(&i, &ctx, e, {800, 600})
	e.key = {
		type     = .KEY_DOWN,
		windowID = 5,
		key      = sdl.K_RETURN,
	}
	n = normalize_event(
		&i,
		&ctx,
		e,
		{800, 600},
	); testing.expect(t, !n.front && !n.has_action, "lost focus must not rearm a still-held confirmation")
	e.key.type = .KEY_UP; normalize_event(&i, &ctx, e, {800, 600})
	e.key.type = .KEY_DOWN; n = normalize_event(&i, &ctx, e, {800, 600}); testing.expect(t, n.front)
	e.window = {
		type     = .WINDOW_HIDDEN,
		windowID = 5,
	}; normalize_event(&i, &ctx, e, {800, 600})
	e.window.type = .WINDOW_FOCUS_GAINED; normalize_event(&i, &ctx, e, {800, 600})
	testing.expect(t, i.suspended, "focus gain cannot override a hidden window")
	e.window.type = .WINDOW_SHOWN; normalize_event(&i, &ctx, e, {800, 600})
	e.gbutton = {
		type   = .GAMEPAD_BUTTON_DOWN,
		which  = 9,
		button = u8(sdl.GamepadButton.DPAD_RIGHT),
	}
	n = normalize_event(&i, &ctx, e, {800, 600}); testing.expect(t, n.front && n.has_action)
	n = normalize_event(
		&i,
		&ctx,
		e,
		{800, 600},
	); testing.expect(t, !n.front && !n.has_action, "DPAD is one shared front edge")
}

@(private)
publish_input_fixture :: proc(t: ^testing.T, p: ^base.Publication, ctx: ^interaction.Context) {
	s, error := base.begin_attempt(p, 0)
	testing.expect(t, error == .None)
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
	testing.expect(t, base.enter_commit(p, s) == .None)
	interaction.commit(ctx, &c, "action"); base.finish_commit(p, s)
}

@(test)
normalization_can_be_consumed_before_base_activation :: proc(t: ^testing.T) {
	p, error := base.create(
		context.allocator,
	); testing.expect(t, error == .None); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	publish_input_fixture(t, &p, &ctx)
	i := Input {
		window_id = 5,
	}
	e: sdl.Event
	e.key = {
		type     = .KEY_DOWN,
		windowID = 5,
		key      = sdl.K_RETURN,
	}
	n := normalize_event(&i, &ctx, e, {800, 600})
	testing.expect(t, n.accepted && n.front && n.has_action)
	// A selected hold family may consume this value: no eager base activation.
	testing.expect(t, p.ready && p.sequence == 0 && ctx.pressed_id == "")
	r := dispatch_input(&ctx, n)
	testing.expect(t, r.consumed && r.dispatch.has_event && p.sequence == 1)
	testing.expect(t, !dispatch_input(&ctx, n).dispatch.has_event)

	publish_input_fixture(t, &p, &ctx)
	e.button = {
		type     = .MOUSE_BUTTON_DOWN,
		windowID = 5,
		button   = 1,
		x        = 10,
		y        = 10,
	}
	n = normalize_event(&i, &ctx, e, {800, 600})
	testing.expect(t, n.pointer_button && n.down && p.ready && ctx.pressed_id == "")
	dispatch_input(&ctx, n)
	testing.expect(t, !p.ready && ctx.pressed_id == "action")
	// Lost edges are maintained during normalization, even if a family consumes
	// the event and current dispatch is already unavailable.
	e.window = {
		type     = .WINDOW_FOCUS_LOST,
		windowID = 5,
	}
	n = normalize_event(&i, &ctx, e, {800, 600})
	testing.expect(t, n.loss && i.suspended && ctx.pressed_id == "" && !p.ready)
}

@(test)
shared_normalizer_emits_one_keyboard_and_pointer_front :: proc(t: ^testing.T) {
	p, error := base.create(
		context.allocator,
	); testing.expect(t, error == .None); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	publish_input_fixture(t, &p, &ctx)
	i := Input {
		window_id = 5,
	}
	e: sdl.Event
	e.key = {
		type     = .KEY_DOWN,
		windowID = 5,
		key      = sdl.K_SPACE,
	}
	first := normalize_event(&i, &ctx, e, {800, 600})
	repeated := normalize_event(&i, &ctx, e, {800, 600})
	testing.expect(
		t,
		first.front && !repeated.front,
		"held key must not begin two family captures",
	)
	testing.expect(t, p.ready && p.sequence == 0)
	e.key.type = .KEY_UP
	release := normalize_event(&i, &ctx, e, {800, 600})
	testing.expect(t, release.accepted && !release.down && !release.front)
	e.key.type = .KEY_DOWN
	testing.expect(t, normalize_event(&i, &ctx, e, {800, 600}).front)
	e.button = {
		type     = .MOUSE_BUTTON_DOWN,
		windowID = 5,
		button   = 1,
		x        = 10,
		y        = 10,
	}
	first = normalize_event(&i, &ctx, e, {800, 600})
	repeated = normalize_event(&i, &ctx, e, {800, 600})
	testing.expect(
		t,
		first.front && !repeated.front,
		"held pointer must not begin two family captures",
	)
	base.invalidate(&p)
	e.button.type = .MOUSE_BUTTON_UP
	release = normalize_event(&i, &ctx, e, {800, 600})
	testing.expect(t, release.accepted && !release.down)
	e.button.type = .MOUSE_BUTTON_DOWN
	testing.expect(t, normalize_event(&i, &ctx, e, {800, 600}).front)
}

@(test)
normalization_projects_motion_and_wheel_to_drawable_once :: proc(t: ^testing.T) {
	p, error := base.create(
		context.allocator,
	); testing.expect(t, error == .None); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	publish_input_fixture(t, &p, &ctx)
	i := Input {
		window_id = 5,
	}
	e: sdl.Event
	e.motion = {
		type     = .MOUSE_MOTION,
		windowID = 5,
		x        = 10,
		y        = 12,
	}
	n := normalize_event(&i, &ctx, e, {400, 300})
	testing.expect(t, n.accepted && n.x == 20 && n.y == 24)
	e.wheel = {
		type     = .MOUSE_WHEEL,
		windowID = 5,
		mouse_x  = 20,
		mouse_y  = 10,
		y        = -1,
	}
	n = normalize_event(&i, &ctx, e, {400, 300})
	testing.expect(t, n.accepted && n.x == 40 && n.y == 20 && !n.has_action)
}
