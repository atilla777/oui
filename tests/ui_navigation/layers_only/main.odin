package main

import "core:fmt"
import "core:mem"
import base "ui:ui_base"
import interaction "ui:ui_interaction"
import layers "ui:ui_layers"
import layout "ui:ui_layout"

Reader :: struct {
	geometry:    layout.Frame,
	interaction: interaction.Frame,
	layers:      layers.Frame,
}
destroy_reader :: proc(r: ^Reader) {layout.destroy_frame(&r.geometry); interaction.destroy_frame(
		&r.interaction,
	)
	layers.destroy_frame(&r.layers)
	r^ = {}}
copy_reader :: proc(g: ^layout.Frame, c: ^layers.Candidate, a: mem.Allocator) -> (Reader, bool) {
	r: Reader; complete := false; defer {if !complete {destroy_reader(&r)}}
	ok: bool; r.geometry, ok = layout.try_copy_frame(g, a); if !ok {return {}, false}
	r.interaction, ok = interaction.try_copy_frame(&c.interaction, a); if !ok {return {}, false}
	r.layers, ok = layers.try_copy_frame(&c.frame, a); if !ok {return {}, false}
	complete = true; return r, true
}
publish :: proc(
	p: ^base.Publication,
	ctx: ^interaction.Context,
	s: ^layers.State,
	reader: ^Reader,
	depth: int,
) {
	stamp, error := base.begin_attempt(p, u64(depth)); assert(error == .None)
	nodes := make([dynamic]layout.Node); defer delete(nodes)
	targets := make([dynamic]interaction.Target); defer delete(targets)
	append(
		&nodes,
		layout.Node {
			id = "root",
			role = .Absolute,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 100},
			},
		},
	)
	ms := [2]layers.Modal{{"a", "ab", true}, {"b", "bb", true}}
	ps := [1]layers.Popup{{"pop", "a", "ab"}}; ts := [1]layers.Tooltip{{"tip", "a"}}
	plan := layers.Layers {
		base_root_id = "base",
		modals       = ms[:depth],
	}
	if depth > 0 {plan.popups = ps[:]; plan.tooltips = ts[:]}
	for id in ([]string{"base", "a", "b", "pop", "tip"}) {
		if id == "a" &&
		   depth <
			   1 {continue}; if id == "b" && depth < 2 {continue}; if (id == "pop" || id == "tip") && depth == 0 {continue}
		append(
			&nodes,
			layout.Node {
				id = id,
				parent = "root",
				role = .Stack,
				enabled = true,
				visible = true,
				layout = layout.Layout {
					x = {mode = .Fixed, value = 100},
					y = {mode = .Fixed, value = 100},
				},
			},
		)
		child := "open"; switch id {case "a":
			child = "ab"; case "b":
			child = "bb"; case "pop":
			child = "pb"; case "tip":
			child = "label"}
		append(
			&nodes,
			layout.Node {
				id = child,
				parent = id,
				role = .Box,
				enabled = true,
				visible = true,
				layout = layout.Layout {
					x = {mode = .Fixed, value = 40},
					y = {mode = .Fixed, value = 40},
				},
			},
		)
		if id != "tip" {append(&targets, interaction.Target{child, "button", true, true})}
	}
	g, ge := layout.prepare(
		nodes[:],
		{drawable = {200, 200}, ui_scale = 2},
		{},
		context.allocator,
		stamp,
	); assert(ge.code == .None); defer layout.destroy_frame(&g)
	c, le := layers.prepare(
		s,
		ctx,
		&g,
		targets[:],
		nil,
		plan,
		context.allocator,
	); assert(le.code == .None); defer layers.destroy_candidate(&c)
	next, ok := copy_reader(&g, &c, context.allocator); assert(ok)
	assert(layers.validate_candidate(p, &c)); assert(base.enter_commit(p, stamp) == .None)
	layers.commit(s, ctx, &c); old := reader^; reader^ = next; base.finish_commit(p, stamp)
	interaction.reconcile_registrations(ctx); destroy_reader(&old)
}
Observer :: struct {
	s:     ^layers.State,
	ctx:   ^interaction.Context,
	calls: int,
}
on_activation :: proc(d: interaction.Delivery, user: rawptr) -> interaction.Propagation {
	o := cast(^Observer)user; o.calls += 1
	assert(d.target_id == "open" && d.current_id == "open" && d.sequence == 1)
	assert(
		layers.dispatch(o.s, o.ctx, {kind = .Cancel, source = .Agent}).dispatch.code == .Not_Ready,
	)
	return .Continue
}
main :: proc() {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	previous :=
		context.allocator; context.allocator = mem.tracking_allocator(&tracking); defer {context.allocator = previous}
	p, e := base.create(context.allocator); assert(e == .None)
	ctx := interaction.create(
		context.allocator,
		&p,
	); s := layers.create(context.allocator); reader: Reader
	publish(&p, &ctx, &s, &reader, 0)
	o := Observer {
		&s,
		&ctx,
		0,
	}; _, code := interaction.register_handler(&ctx, "open", on_activation, &o); assert(code == .Applied)
	effects := u64(0)
	r := layers.dispatch(
		&s,
		&ctx,
		{kind = .Activate, id = "open", source = .Agent},
	); assert(r.dispatch.has_event && o.calls == 1); effects += 1
	publish(&p, &ctx, &s, &reader, 1)
	n, hit := layers.hit_test(
		&s.frame,
		&reader.geometry,
		&ctx.frame,
		20,
		20,
	); assert(hit == .Applied && n.description.id == "pb")
	n, hit = layers.hit_test(
		&s.frame,
		&reader.geometry,
		&ctx.frame,
		100,
		100,
	); assert(hit == .Not_Found && n == nil)
	assert(
		layers.dispatch(&s, &ctx, {kind = .Activate, id = "open", source = .Keyboard}).dispatch.code ==
		.Blocked_By_Modal,
	)
	publish(&p, &ctx, &s, &reader, 2); assert(ctx.focus_id == "bb")
	for depth := 2; depth > 0; depth -= 1 {
		r = layers.dispatch(
			&s,
			&ctx,
			{kind = .Cancel, source = .Agent},
		); assert(r.cancel != nil && r.cancel.?.sequence == effects + 1); effects += 1
		publish(&p, &ctx, &s, &reader, depth - 1)
	}
	assert(ctx.focus_id == "open" && effects == 3 && p.sequence == 3 && o.calls == 1)
	live := tracking.current_memory_allocated
	for _ in 0 ..< 64 {publish(&p, &ctx, &s, &reader, 0); assert(tracking.current_memory_allocated == live && p.sequence == 3)}
	fmt.printf(
		"layers State=%d Frame=%d Candidate=%d allocations=%d bytes=%d live=%d peak=%d effects=%d handlers=%d scale=2 backend-resources=0\n",
		size_of(layers.State),
		size_of(layers.Frame),
		size_of(layers.Candidate),
		tracking.total_allocation_count,
		tracking.total_memory_allocated,
		tracking.current_memory_allocated,
		tracking.peak_memory_allocated,
		effects,
		len(ctx.registrations),
	)
	layers.destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	assert(
		reader.layers.layers.base_root_id == "base" &&
		reader.geometry.nodes[0].description.id == "root" &&
		!reader.layers.stamp.lifetime.alive,
	)
	destroy_reader(&reader)
	fmt.printf(
		"destroy live=%d bad-frees=%d\n",
		tracking.current_memory_allocated,
		len(tracking.bad_free_array),
	)
	assert(tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
}
