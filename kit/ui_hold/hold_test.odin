package ui_hold

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:mem"
import "core:strings"

@(test)
prepare_projects_unavailability_without_mutating_live_cycle :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	s.live = {
		id           = strings.clone("confirm"),
		phase        = .Holding,
		cycle        = 4,
		threshold_ms = 500,
		elapsed_ms   = 100,
	}
	g, targets := geometry(
		t,
		&p,
	); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&targets)
	n, _ := interaction.find(&targets, "confirm"); n.availability = .Disabled
	holds := [1]Description{{"confirm", 500}}
	c, e := prepare(
		&s,
		&ctx,
		&g,
		&targets,
		nil,
		holds[:],
		context.allocator,
	); defer destroy_candidate(&c)
	if !testing.expect(t, e.code == .None) {return}
	testing.expect(
		t,
		c.frame.hold.phase == .Idle &&
		c.frame.result.count == 1 &&
		c.frame.result.signals[0].reason == .Unavailable,
	)
	testing.expect(t, s.live.phase == .Holding && s.live.elapsed_ms == 100 && s.live.cycle == 4)
}
import "core:testing"

@(test)
commit_moves_allocator_and_keeps_result_on_live_owner :: proc(t: ^testing.T) {
	first, second: mem.Tracking_Allocator
	mem.tracking_allocator_init(&first, context.allocator)
	mem.tracking_allocator_init(&second, context.allocator)
	defer mem.tracking_allocator_destroy(&first)
	defer mem.tracking_allocator_destroy(&second)
	a, b := mem.tracking_allocator(&first), mem.tracking_allocator(&second)
	s := create(a)
	s.live.id = strings.clone("old", a)
	c := Candidate {
		frame = {allocator = b},
	}
	c.frame.hold.id = strings.clone("hold", b)
	c.live_id = strings.clone("hold", b)
	c.frame.result.count = 1
	c.frame.result.signals[0].id = c.frame.hold.id
	c.frame.result.dispatch = {
		has_event = true,
		event = {id = c.frame.hold.id},
	}
	commit(&s, &c)
	testing.expect(t, s.allocator == b, "committed live ID must retain its actual allocator")
	testing.expect(
		t,
		raw_data(s.last_result.signals[0].id) == raw_data(s.live.id),
		"live signals must not borrow the independently destroyable frame",
	)
	testing.expect(
		t,
		raw_data(s.last_result.dispatch.event.id) == raw_data(s.live.id),
		"live dispatch must borrow the live ID, not frame storage",
	)
	// Cleanup remains safe even when either assertion exposes the original bug.
	s.allocator = b
	destroy_frame(&s.frame)
	delete(s.live.id, b)
	s = {}
	testing.expect(t, first.current_memory_allocated == 0 && second.current_memory_allocated == 0)
	testing.expect(t, len(first.bad_free_array) == 0 && len(second.bad_free_array) == 0)
}

@(private)
geometry :: proc(t: ^testing.T, p: ^base.Publication) -> (layout.Frame, interaction.Frame) {
	s, _ := base.begin_attempt(p, 1)
	nodes := [3]layout.Node {
		{
			id = "root",
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 50},
			},
		},
		{
			id = "confirm",
			parent = "root",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 20},
			},
		},
		{
			id = "bar",
			parent = "root",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 10},
			},
		},
	}
	g, e := layout.prepare(
		nodes[:],
		{drawable = {100, 50}, ui_scale = 1},
		{},
		context.allocator,
		s,
	); testing.expect(t, e.code == .None)
	targets := [1]interaction.Target{{"confirm", "button", true, true}}
	f, code := interaction.prepare(
		&g,
		targets[:],
		nil,
		context.allocator,
	); testing.expect(t, code == .Applied)
	return g, f
}
@(test)
prepare_owns_descriptions_and_progress_geometry :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	g, targets := geometry(
		t,
		&p,
	); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&targets)
	progress := [1]Progress_Description{{"bar", 25, 100}}
	holds := [1]Description{{"confirm", 500}}
	c, e := prepare(
		&s,
		&ctx,
		&g,
		&targets,
		progress[:],
		holds[:],
		context.allocator,
	); defer destroy_candidate(&c)
	if !testing.expect(t, e.code == .None, "valid hold/progress preparation must succeed") {return}
	progress[0].value = 99; holds[0].threshold_ms = 1
	testing.expect(
		t,
		c.frame.progress[0].fill.w == 25 &&
		c.frame.progress[0].value == 25 &&
		c.frame.holds[0].threshold_ms == 500,
	)
	testing.expect(t, validate_candidate(&p, &c))
	base.begin_attempt(&p, 2); testing.expect(t, !validate_candidate(&p, &c))
}

@(test)
hold_cycle_completes_once_and_plain_activation_is_refused :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	g, targets := geometry(t, &p); defer layout.destroy_frame(&g)
	holds := [1]Description{{"confirm", 500}}
	c, e := prepare(&s, &ctx, &g, &targets, nil, holds[:], context.allocator)
	defer destroy_candidate(&c)
	if !testing.expect(t, e.code == .None) {interaction.destroy_frame(&targets); return}
	stamp := g.stamp
	base.enter_commit(&p, stamp)
	interaction.commit(&ctx, &targets, "confirm"); commit(&s, &c); base.finish_commit(&p, stamp)
	testing.expect(
		t,
		interaction.dispatch(&ctx, {.Activate, "confirm", .Agent, false}).code ==
		.Activation_Required,
	)
	r := dispatch(&s, &ctx, {kind = .Begin, id = "confirm", source = .Agent})
	if !testing.expect(
		t,
		r.code == .Applied && r.count == 1 && s.live.phase == .Holding && s.live.cycle == 1,
	) {return}
	base.finish_commit(&p, stamp)
	testing.expect(
		t,
		dispatch(&s, &ctx, {kind = .Advance, duration_ms = -1}).code == .Invalid_Action &&
		s.live.elapsed_ms == 0 &&
		p.ready,
	)
	r = dispatch(&s, &ctx, {kind = .Advance, duration_ms = 499})
	testing.expect(t, !r.dispatch.has_event && s.live.elapsed_ms == 499)
	base.finish_commit(&p, stamp)
	r = dispatch(&s, &ctx, {kind = .Advance, duration_ms = 1})
	testing.expect(
		t,
		r.count == 2 && r.signals[1].kind == .Completed && r.dispatch.has_event && p.sequence == 1,
	)
	// Restore current association for the release latch, not another activation.
	ctx.frame.stamp.sequence = p.sequence; stamp = ctx.frame.stamp; base.finish_commit(&p, stamp)
	s.frame.stamp = stamp // This fixture explicitly re-associates both immutable projections.
	testing.expect(
		t,
		!dispatch(&s, &ctx, {kind = .Begin, id = "confirm", source = .Agent}).dispatch.has_event &&
		s.live.cycle == 1,
	)
	base.finish_commit(&p, stamp)
	dispatch(&s, &ctx, {kind = .Release, source = .Agent})
	testing.expect(t, s.live.phase == .Idle)
}
