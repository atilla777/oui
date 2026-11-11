package ui_gestures
import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import scroll "../ui_scroll"
import "core:testing"

scroll_descriptions :: proc() -> [2]Description {return {
		{
			id = "repeat",
			node_id = "source",
			kind = .Repeat_Scroll,
			scroll_id = "viewport",
			step = 24,
			delay_ms = 300,
			interval_ms = 100,
		},
		{id = "pan", node_id = "viewport", kind = .Pan_Scroll, scroll_id = "viewport"},
	}}
publish_scroll :: proc(
	t: ^testing.T,
	p: ^base.Publication,
	ctx: ^interaction.Context,
	s: ^State,
	ss: ^scroll.State,
	ds: []Description,
	height: f64 = 100,
	scale: f64 = 1,
	viewport_enabled: bool = true,
) -> bool {
	stamp, _ := base.begin_attempt(p, 7)
	nodes := [6]layout.Node {
		{
			id = "root",
			role = .Row,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 200},
				y = {mode = .Fixed, value = height},
			},
		},
		{
			id = "source",
			parent = "root",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 20},
				y = {mode = .Fixed, value = height},
			},
		},
		{
			id = "viewport",
			parent = "root",
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = height},
			},
		},
		{
			id = "content",
			parent = "viewport",
			role = .Column,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fixed, value = 100}, y = {mode = .Content}},
		},
		{
			id = "one",
			parent = "content",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 150},
			},
		},
		{
			id = "two",
			parent = "content",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 150},
			},
		},
	}
	nodes[2].enabled = viewport_enabled
	g, ge := layout.prepare(
		nodes[:],
		{drawable = {200 * scale, height * scale}, ui_scale = scale},
		{},
		context.allocator,
		stamp,
	)
	if !testing.expect(t, ge.code == .None) {return false}; defer layout.destroy_frame(&g)
	targets := [4]interaction.Target {
		{"source", "button", true, true},
		{"viewport", "scroll", true, true},
		{"one", "button", true, true},
		{"two", "button", true, true},
	}
	i, ie := interaction.prepare(&g, targets[:], nil, context.allocator)
	if !testing.expect(t, ie == .Applied) {return false}; defer interaction.destroy_frame(&i)
	sc, se := scroll.prepare(
		ss,
		&g,
		&i,
		[]scroll.Description{{"viewport", "content"}},
		context.allocator,
	)
	if !testing.expect(t, se.code == .None) {return false}; defer scroll.destroy_candidate(&sc)
	interaction.destroy_frame(&i)
	i, ie = interaction.prepare(
		&sc.geometry,
		targets[:],
		[]interaction.Capture_Claim{{"source", "gestures"}, {"viewport", "gestures"}},
		context.allocator,
	)
	if !testing.expect(t, ie == .Applied) {return false}
	c, ce := prepare(s, &sc.geometry, &i, &sc.frame, ds, 7); defer destroy_candidate(&c)
	if !testing.expect(
		t,
		ce.code == .None && validate_candidate(p, s, &c) && scroll.validate_candidate(p, ss, &sc),
	) {return false}
	if !testing.expect(t, base.enter_commit(p, stamp) == .None) {return false}
	interaction.commit(
		ctx,
		&i,
		"source",
	); scroll.commit(ss, &sc); commit(s, &c); base.finish_commit(p, stamp)
	return true
}
@(test)
repeat_initial_step_delay_and_explicit_clock_have_no_release_step :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create()
	defer destroy(&s)
	ss := scroll.create(context.allocator)
	defer scroll.destroy(&ss)
	ds := scroll_descriptions()
	if !publish_scroll(t, &p, &ctx, &s, &ss, ds[:]) {return}
	r := dispatch(&s, &ctx, &ss, {kind = .Begin, id = "repeat", source = .Agent})
	if !testing.expect(
		t,
		r.code == .Applied && r.phase == .Active && ss.has_pending && p.sequence == 0,
	) {return}
	if !publish_scroll(t, &p, &ctx, &s, &ss, ds[:]) {return}
	testing.expect(t, ss.frame.regions[0].offset == 24)
	for duration, index in ([3]i64{299, 1, 200}) {
		expected := [3]f64{24, 48, 96}
		r = dispatch(
			&s,
			&ctx,
			&ss,
			{kind = .Advance, source = .Agent, cycle = 1, duration_ms = duration},
		)
		if !testing.expect(t, r.code == .Applied) {return}
		if !publish_scroll(t, &p, &ctx, &s, &ss, ds[:]) {return}
		testing.expect(t, ss.frame.regions[0].offset == expected[index])
	}
	r = dispatch(&s, &ctx, &ss, {kind = .End, source = .Agent, cycle = 1})
	testing.expect(t, r.code == .Applied && !r.has_proposal)
	if !publish_scroll(t, &p, &ctx, &s, &ss, ds[:]) {return}
	testing.expect(t, ss.frame.regions[0].offset == 96 && p.sequence == 0)
}
