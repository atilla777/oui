package main

import "core:fmt"
import "core:mem"
import base "ui:ui_base"
import hold "ui:ui_hold"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"

publish :: proc(p: ^base.Publication, ctx: ^interaction.Context, s: ^hold.State) {
	stamp, error := base.begin_attempt(p, 1); assert(error == .None)
	nodes := [3]layout.Node {
		{
			id = "root",
			role = .Column,
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
			id = "progress",
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
	g, ge := layout.prepare(
		nodes[:],
		{drawable = {100, 50}, ui_scale = 1},
		{},
		context.allocator,
		stamp,
	); assert(ge.code == .None); defer layout.destroy_frame(&g)
	targets := [1]interaction.Target{{"confirm", "button", true, true}}
	claims := [1]interaction.Capture_Claim{{"confirm", "hold"}}
	i, ie := interaction.prepare(
		&g,
		targets[:],
		claims[:],
		context.allocator,
	); assert(ie == .Applied); defer interaction.destroy_frame(&i)
	hs := [1]hold.Description{{"confirm", 500}}
	ps := [1]hold.Progress_Description{{"progress", f64(s.live.elapsed_ms), 500}}
	c, he := hold.prepare(
		s,
		ctx,
		&g,
		&i,
		ps[:],
		hs[:],
		context.allocator,
	); assert(he.code == .None); defer hold.destroy_candidate(&c)
	assert(hold.validate_candidate(p, &c) && base.validate(p, i.stamp) == .None)
	assert(base.enter_commit(p, stamp) == .None)
	interaction.commit(
		ctx,
		&i,
		"confirm",
	); hold.commit(s, &c); base.finish_commit(p, stamp); interaction.reconcile_registrations(ctx)
}
Observer :: struct {
	s:       ^hold.State,
	ctx:     ^interaction.Context,
	effects: u64,
}
handle :: proc(d: interaction.Delivery, user: rawptr) -> interaction.Propagation {
	o := cast(^Observer)user
	assert(
		d.target_id == "confirm" &&
		d.sequence == 1 &&
		o.s.live.phase == .Completed_Waiting_Release,
	)
	assert(hold.dispatch(o.s, o.ctx, {kind = .Advance, duration_ms = 500}).code == .Not_Ready)
	o.effects += 1; return .Continue
}
main :: proc() {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	previous :=
		context.allocator; context.allocator = mem.tracking_allocator(&tracking); defer {context.allocator = previous}
	p, e := base.create(context.allocator); assert(e == .None)
	ctx := interaction.create(context.allocator, &p); s := hold.create(context.allocator)
	publish(&p, &ctx, &s)
	o := Observer {
		&s,
		&ctx,
		0,
	}; _, code := interaction.register_handler(&ctx, "confirm", handle, &o); assert(code == .Applied)
	assert(
		interaction.dispatch_routed(&ctx, {.Activate, "confirm", .Agent, false}).code ==
		.Activation_Required,
	)
	hold.dispatch(
		&s,
		&ctx,
		{kind = .Begin, id = "confirm", source = .Agent},
	); publish(&p, &ctx, &s)
	hold.dispatch(&s, &ctx, {kind = .Advance, duration_ms = 499}); publish(&p, &ctx, &s)
	r := hold.dispatch(
		&s,
		&ctx,
		{kind = .Advance, duration_ms = 1},
	); assert(r.dispatch.has_event && o.effects == 1 && p.sequence == 1)
	publish(&p, &ctx, &s)
	reader, ok := hold.try_copy_frame(&s.frame, context.allocator); assert(ok)
	live := tracking.current_memory_allocated
	for _ in 0 ..< 64 {publish(&p, &ctx, &s); assert(tracking.current_memory_allocated == live && o.effects == 1)}
	fmt.printf(
		"hold State=%d Frame=%d allocations=%d bytes=%d live=%d peak=%d effects=%d handlers=%d backend-resources=0\n",
		size_of(hold.State),
		size_of(hold.Frame),
		tracking.total_allocation_count,
		tracking.total_memory_allocated,
		tracking.current_memory_allocated,
		tracking.peak_memory_allocated,
		o.effects,
		len(ctx.registrations),
	)
	hold.destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	assert(
		reader.hold.phase == .Completed_Waiting_Release &&
		reader.result.dispatch.event.id == "confirm" &&
		!reader.stamp.lifetime.alive,
	)
	hold.destroy_frame(&reader)
	fmt.printf(
		"destroy live=%d bad-frees=%d\n",
		tracking.current_memory_allocated,
		len(tracking.bad_free_array),
	)
	assert(tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
}
