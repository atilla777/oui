package ui_hold_sdl

import hold ".."
import base "../../ui_base"
import interaction "../../ui_interaction"
import layout "../../ui_layout"
import backend "../../ui_sdl"
import "core:testing"
import sdl "vendor:sdl3"

rebuild :: proc(t: ^testing.T, p: ^base.Publication, ctx: ^interaction.Context, s: ^hold.State) {
	stamp, _ := base.begin_attempt(p, 1)
	nodes := [1]layout.Node {
		{
			id = "hold",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 40},
			},
		},
	}
	g, e := layout.prepare(
		nodes[:],
		{drawable = {100, 40}, ui_scale = 1},
		{},
		context.allocator,
		stamp,
	); testing.expect(t, e.code == .None); defer layout.destroy_frame(&g)
	targets := [1]interaction.Target{{"hold", "button", true, true}}
	i, code := interaction.prepare(
		&g,
		targets[:],
		nil,
		context.allocator,
	); testing.expect(t, code == .Applied); defer interaction.destroy_frame(&i)
	ds := [1]hold.Description{{"hold", 500}}
	c, he := hold.prepare(
		s,
		ctx,
		&g,
		&i,
		nil,
		ds[:],
		context.allocator,
	); testing.expect(t, he.code == .None); defer hold.destroy_candidate(&c)
	base.enter_commit(
		p,
		stamp,
	); interaction.commit(ctx, &i, "hold"); hold.commit(s, &c); base.finish_commit(p, stamp)
}
@(test)
native_hold_shared_front_pending_release_and_explicit_clock :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := hold.create(context.allocator); defer hold.destroy(&s)
	rebuild(t, &p, &ctx, &s)
	device := backend.Input {
		window_id = 1,
	}; a: Adapter
	e: sdl.Event; e.key = {
		type     = .KEY_DOWN,
		windowID = 1,
		key      = sdl.K_SPACE,
	}
	n := backend.normalize_event(&device, &ctx, e, {100, 40})
	r := handle(&a, &s, &ctx, n)
	if !testing.expect(t, r.consumed && s.live.phase == .Holding && s.live.cycle == 1) {return}
	rebuild(t, &p, &ctx, &s)
	n = backend.normalize_event(&device, &ctx, e, {100, 40}); handle(&a, &s, &ctx, n)
	testing.expect(t, s.live.cycle == 1)
	step(&a, &s, &ctx, 0)
	r.result = step(
		&a,
		&s,
		&ctx,
		499,
	); testing.expect(t, !r.result.dispatch.has_event && s.live.elapsed_ms == 499)
	// Physical up is maintained even while the publication is not ready.
	e.key.type = .KEY_UP; n = backend.normalize_event(&device, &ctx, e, {100, 40}); handle(&a, &s, &ctx, n)
	rebuild(t, &p, &ctx, &s)
	step(&a, &s, &ctx, 900000)
	testing.expect(
		t,
		s.live.phase == .Idle && p.sequence == 0,
		"pending release must win over elapsed wall time",
	)
}

@(test)
mouse_hold_and_gamepad_loss_share_normalized_edges :: proc(t: ^testing.T) {
	for source in ([]interaction.Source{.Mouse, .Gamepad}) {
		p, _ := base.create(context.allocator)
		ctx := interaction.create(context.allocator, &p)
		s := hold.create(context.allocator)
		rebuild(t, &p, &ctx, &s)
		device := backend.Input {
			window_id  = 1,
			gamepad_id = 9,
		}; a: Adapter
		e: sdl.Event
		if source == .Mouse {e.button = {
				type     = .MOUSE_BUTTON_DOWN,
				windowID = 1,
				button   = 1,
				x        = 10,
				y        = 10,
			}
		} else {e.gbutton = {
				type   = .GAMEPAD_BUTTON_DOWN,
				which  = 9,
				button = u8(sdl.GamepadButton.SOUTH),
			}}
		n := backend.normalize_event(&device, &ctx, e, {100, 40}); r := handle(&a, &s, &ctx, n)
		if testing.expect(t, r.consumed && s.live.phase == .Holding && s.live.source == source) {
			rebuild(t, &p, &ctx, &s)
			if source == .Mouse {e.motion = {
					type     = .MOUSE_MOTION,
					windowID = 1,
					x        = 150,
					y        = 10,
				}
			} else {e.gdevice = {
					type  = .GAMEPAD_REMOVED,
					which = 9,
				}}
			n = backend.normalize_event(&device, &ctx, e, {100, 40}); r = handle(&a, &s, &ctx, n)
			if !interaction.ready(
				&ctx,
			) {rebuild(t, &p, &ctx, &s); r.result = step(&a, &s, &ctx, 900000)}
			testing.expect(
				t,
				s.live.phase == .Idle && p.sequence == 0,
				"loss/motion cannot finish a hold",
			)
		}
		hold.destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	}
}

@(test)
failed_rebuild_rebases_clock_even_before_not_ready_is_observed :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := hold.create(context.allocator); defer hold.destroy(&s)
	rebuild(t, &p, &ctx, &s)
	hold.dispatch(
		&s,
		&ctx,
		{kind = .Begin, id = "hold", source = .Agent},
	); rebuild(t, &p, &ctx, &s)
	a: Adapter
	step(&a, &s, &ctx, 0); step(&a, &s, &ctx, 400); rebuild(t, &p, &ctx, &s)
	block(&a, &ctx)
	rebuild(t, &p, &ctx, &s)
	r := step(&a, &s, &ctx, 900000)
	testing.expect(
		t,
		!r.dispatch.has_event && s.live.elapsed_ms == 400 && s.live.phase == .Holding,
	)
}
