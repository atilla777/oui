package transition_controls

import "core:testing"
import base "ui:ui_base"
import hold "ui:ui_hold"
import adapter "ui:ui_hold/sdl"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"
import backend "ui:ui_sdl"
import transitions "ui:ui_transitions"
import sdl "vendor:sdl3"

publish_hold :: proc(
	t: ^testing.T,
	p: ^base.Publication,
	ctx: ^interaction.Context,
	ts: ^transitions.State,
	hs: ^hold.State,
	scale: f64,
) -> bool {
	stamp, _ := base.begin_attempt(p, 1)
	tc, te := transitions.prepare(
		ts,
		stamp,
		[]transitions.Description {
			{
				node_id = "confirm",
				tracks = []transitions.Track {
					{property = .Offset, target = [2]f64{50, 0}},
					{property = .Scale, target = scale},
				},
			},
		},
		{},
		false,
	)
	defer transitions.destroy_candidate(&tc)
	if !testing.expect(t, te.code == .None) {return false}
	nodes := []layout.Node {
		{
			id = "root",
			role = .Absolute,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
		},
		{
			id = "confirm",
			parent = "root",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 40},
				y = {mode = .Fixed, value = 20},
			},
		},
	}
	g, ge := layout.prepare(
		nodes,
		{drawable = {200, 40}, ui_scale = 1},
		{},
		context.allocator,
		stamp,
	); defer layout.destroy_frame(&g)
	if !testing.expect(t, ge.code == .None) {return false}
	i, ie := interaction.prepare(
		&g,
		[]interaction.Target{{"confirm", "button", true, true}},
		nil,
		context.allocator,
	); defer interaction.destroy_frame(&i)
	if !testing.expect(
		t,
		ie == .Applied &&
		transitions.bind_geometry(&tc, &g, &i).code == .None &&
		transitions.sample_interaction(&tc.frame, &i),
	) {return false}
	hc, he := hold.prepare(
		hs,
		ctx,
		&g,
		&i,
		nil,
		[]hold.Description{{"confirm", 100}},
		context.allocator,
	); defer hold.destroy_candidate(&hc)
	if !testing.expect(
		t,
		he.code == .None &&
		transitions.validate_candidate(p, ts, &tc) &&
		hold.validate_candidate(p, &hc),
	) {return false}
	base.enter_commit(
		p,
		stamp,
	); interaction.commit(ctx, &i, "confirm"); transitions.commit(ts, &tc); hold.commit(hs, &hc); base.finish_commit(p, stamp)
	return true
}
@(test)
transformed_hold_uses_frozen_target_and_zero_scale_cancels_before_completion :: proc(
	t: ^testing.T,
) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	ts := transitions.create(); defer transitions.destroy(&ts)
	hs := hold.create(context.allocator); defer hold.destroy(&hs)
	a: adapter.Adapter; device := backend.Input {
		window_id = 1,
	}
	if !publish_hold(t, &p, &ctx, &ts, &hs, 1) {return}
	e: sdl.Event; e.button = {
		type     = .MOUSE_BUTTON_DOWN,
		windowID = 1,
		button   = 1,
		x        = 60,
		y        = 10,
	}
	r := adapter.handle(&a, &hs, &ctx, backend.normalize_event(&device, &ctx, e, {200, 40}))
	if !testing.expect(
		t,
		r.consumed && r.result.code == .Applied && hs.live.phase == .Holding && !p.ready,
	) {return}
	if !publish_hold(t, &p, &ctx, &ts, &hs, 0) {return}
	testing.expect(
		t,
		hs.live.phase == .Idle &&
		hs.last_result.count == 1 &&
		hs.last_result.signals[0].reason == .Unavailable &&
		p.sequence == 0,
	)
	testing.expect(
		t,
		hold.dispatch(&hs, &ctx, {kind = .Advance, source = .Mouse, duration_ms = 100}).dispatch.has_event ==
		false,
	)
}
