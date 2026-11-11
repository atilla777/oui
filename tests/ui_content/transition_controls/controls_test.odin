package transition_controls

import "core:testing"
import base "ui:ui_base"
import controls "ui:ui_controls"
import adapter "ui:ui_controls/sdl"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"
import backend "ui:ui_sdl"
import transitions "ui:ui_transitions"
import sdl "vendor:sdl3"

// D1 §4: a frozen +50 visual offset must not change the logical slider value.
// This is a numerical input test, not a graphical/window run.
@(test)
frozen_visual_track_uses_inverse_mapping_without_rewriting_layout :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := controls.create(); defer controls.destroy(&s)
	ts := transitions.create(); defer transitions.destroy(&ts)
	a := adapter.create(context.allocator); defer adapter.destroy(&a)
	stamp, _ := base.begin_attempt(&p, 1)
	nodes := []layout.Node {
		{
			id = "slider",
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 300},
				y = {mode = .Fixed, value = 40},
			},
		},
		{
			id = "track",
			parent = "slider",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 20},
			},
		},
	}
	g, ge := layout.prepare(
		nodes,
		{drawable = {400, 40}, ui_scale = 1},
		{},
		context.allocator,
		stamp,
	)
	defer layout.destroy_frame(&g)
	if !testing.expect(t, ge.code == .None) {return}
	i, ie := interaction.prepare(
		&g,
		[]interaction.Target{{"slider", "button", true, true}},
		nil,
		context.allocator,
	)
	defer interaction.destroy_frame(&i)
	if !testing.expect(t, ie == .Applied) {return}
	c, ce := controls.prepare(
		&i,
		{},
		[]controls.Description {
			{
				id = "level",
				node_id = "slider",
				track_id = "track",
				kind = .Slider,
				maximum = 100,
				step = 10,
				value = 50,
			},
		},
		context.allocator,
		&g,
	)
	defer controls.destroy_candidate(&c)
	if !testing.expect(t, ce.code == .None) {return}
	// The real selected transitions owner projects both target and track before
	// the shared publication; original layout stays x=0.
	tc, te := transitions.prepare(
		&ts,
		stamp,
		[]transitions.Description {
			{
				node_id = "slider",
				tracks = []transitions.Track{{property = .Offset, target = [2]f64{50, 0}}},
			},
		},
		{},
		false,
	)
	defer transitions.destroy_candidate(&tc)
	if !testing.expect(
		t,
		te.code == .None &&
		transitions.bind_geometry(&tc, &g, &i).code == .None &&
		transitions.sample_interaction(&tc.frame, &i) &&
		transitions.validate_candidate(&p, &ts, &tc),
	) {return}
	base.enter_commit(&p, stamp)
	interaction.commit(
		&ctx,
		&i,
		"slider",
	); controls.commit(&s, &c); transitions.commit(&ts, &tc); base.finish_commit(&p, stamp)
	device := backend.Input {
		window_id = 1,
	}
	event: sdl.Event
	event.button = {
		type     = .MOUSE_BUTTON_DOWN,
		windowID = 1,
		button   = 1,
		x        = 70,
		y        = 10,
	}
	r := adapter.handle(
		&a,
		&s,
		&ctx,
		&g,
		backend.normalize_event(&device, &ctx, event, {400, 40}),
		transitions.geometry_view(&ts.frame),
	)
	if !testing.expect(t, r.consumed && r.result.event != nil) {return}
	testing.expect_value(t, r.result.event.?.value, i64(20))
	track, _ := layout.find(&g, "track")
	testing.expect(t, track.bounds.x == 0 && track.bounds.w == 100)
}
