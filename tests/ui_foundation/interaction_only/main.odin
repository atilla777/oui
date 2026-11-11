package main

import "core:fmt"
import "core:mem"
import base "ui:ui_base"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"

main :: proc() {
	live: mem.Tracking_Allocator
	mem.tracking_allocator_init(&live, context.allocator)
	defer mem.tracking_allocator_destroy(&live)
	backing := context.allocator
	context.allocator = mem.tracking_allocator(&live)
	defer {context.allocator = backing}
	p, e := base.create(context.allocator); assert(e == .None); defer base.destroy(&p)
	fmt.printf(
		"common-init allocations=%d bytes=%d live=%d peak=%d handlers=0 backend-resources=0\n",
		live.total_allocation_count,
		live.total_memory_allocated,
		live.current_memory_allocated,
		live.peak_memory_allocated,
	)
	s, _ := base.begin_attempt(&p, 1)
	nodes := [1]layout.Node {
		{
			id = "button",
			role = .Box,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 40},
				y = {mode = .Fixed, value = 20},
			},
			enabled = true,
			visible = true,
		},
	}
	g, error := layout.prepare(
		nodes[:],
		{drawable = {100, 60}, ui_scale = 1},
		{},
		context.allocator,
		s,
	)
	assert(error.code == .None); defer layout.destroy_frame(&g)
	targets := [1]interaction.Target{{"button", "button", true, true}}
	c, code := interaction.prepare(
		&g,
		targets[:],
		nil,
		context.allocator,
	); assert(code == .Applied); defer interaction.destroy_candidate(&c)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	assert(base.enter_commit(&p, c.stamp) == .None)
	interaction.commit(&ctx, &c); base.finish_commit(&p, s)
	layout.destroy_frame(&g)
	fmt.printf(
		"interaction-published allocations=%d bytes=%d live=%d peak=%d Context=%d Frame=%d handlers=%d backend-resources=0\n",
		live.total_allocation_count,
		live.total_memory_allocated,
		live.current_memory_allocated,
		live.peak_memory_allocated,
		size_of(interaction.Context),
		size_of(interaction.Frame),
		len(ctx.registrations),
	)
	r := interaction.dispatch(&ctx, {.Activate, "button", .Agent, false})
	assert(r.has_event && r.event.sequence == 1 && r.event.id == "button")
	assert(interaction.dispatch(&ctx, {.Activate, "button", .Agent, false}).code == .Not_Ready)
	interaction.destroy(&ctx); base.destroy(&p)
	fmt.printf(
		"destroy allocations=%d bytes=%d live=%d peak=%d\n",
		live.total_allocation_count,
		live.total_memory_allocated,
		live.current_memory_allocated,
		live.peak_memory_allocated,
	)
	assert(live.current_memory_allocated == 0 && len(live.bad_free_array) == 0)
}
