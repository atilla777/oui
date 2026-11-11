package main

import "core:fmt"
import "core:mem"
import base "ui:ui_base"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"
import scroll "ui:ui_scroll"

report :: proc(name: string, a: ^mem.Tracking_Allocator) {
	fmt.printf(
		"%s allocations=%d bytes=%d live=%d peak=%d handlers=0 backend-resources=0\n",
		name,
		a.total_allocation_count,
		a.total_memory_allocated,
		a.current_memory_allocated,
		a.peak_memory_allocated,
	)
}
main :: proc() {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	previous :=
		context.allocator; context.allocator = mem.tracking_allocator(&tracking); defer {context.allocator = previous}
	p, pe := base.create(context.allocator); assert(pe == .None)
	ctx := interaction.create(context.allocator, &p)
	s := scroll.create(context.allocator)
	report("common-init", &tracking)
	nodes := [4]layout.Node {
		{
			id = "scroll",
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 20},
			},
		},
		{
			id = "content",
			parent = "scroll",
			role = .Column,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fixed, value = 100}, y = {mode = .Content}},
		},
		{
			id = "a",
			parent = "content",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 20},
			},
		},
		{
			id = "b",
			parent = "content",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 20},
			},
		},
	}
	targets := [2]interaction.Target{{"a", "button", true, true}, {"b", "button", true, true}}
	ds := [1]scroll.Description{{"scroll", "content"}}
	for stage in 0 ..< 2 {
		stamp, e := base.begin_attempt(&p, u64(stage)); assert(e == .None)
		g, ge := layout.prepare(
			nodes[:],
			{drawable = {100, 40}, ui_scale = 1},
			{},
			context.allocator,
			stamp,
		); assert(ge.code == .None)
		i, ic := interaction.prepare(
			&g,
			targets[:],
			nil,
			context.allocator,
		); assert(ic == .Applied)
		c, ce := scroll.prepare(
			&s,
			&g,
			&i,
			ds[:],
			context.allocator,
			ctx.focus_id,
		); assert(ce.code == .None && scroll.validate_candidate(&p, &s, &c))
		final, fc := interaction.prepare(
			&c.geometry,
			targets[:],
			nil,
			context.allocator,
		); assert(fc == .Applied)
		assert(base.enter_commit(&p, stamp) == .None)
		interaction.commit(&ctx, &final, "a")
		if c.has_focus {ctx.focus_id = interaction.retained_id(&ctx.frame, c.focus_id)}
		scroll.commit(
			&s,
			&c,
		); base.finish_commit(&p, stamp); interaction.reconcile_registrations(&ctx)
		layout.destroy_frame(&g); interaction.destroy_frame(&i)
		if stage ==
		   0 {report("scroll-published", &tracking); r := scroll.dispatch(&s, &ctx, {kind = .Move_Item, source = .Agent}); assert(r.code == .Applied)}
	}
	assert(ctx.focus_id == "b" && s.frame.regions[0].offset == 20)
	reader, ok := scroll.try_copy_frame(&s.frame, context.allocator); assert(ok)
	report("rebuilt-plus-reader", &tracking)
	fmt.printf(
		"State=%d Frame=%d Candidate=%d Publication=%d Context=%d nodes=%d scale=1 locale=none\n",
		size_of(scroll.State),
		size_of(scroll.Frame),
		size_of(scroll.Candidate),
		size_of(base.Publication),
		size_of(interaction.Context),
		len(nodes),
	)
	scroll.destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	assert(reader.regions[0].anchor_id == "b" && !reader.stamp.lifetime.alive)
	scroll.destroy_frame(&reader)
	report("destroy", &tracking)
	assert(tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
}
