package main

import "core:fmt"
import "core:mem"
import base "ui:ui_base"
import custom "ui:ui_custom"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"

valid :: proc(bytes: []u8) -> bool {return len(bytes) == 1 && bytes[0] == 7}
measure :: proc(bytes: []u8, constraints: custom.Constraints) -> (base.Extent, bool) {return {
			20,
			20,
		},
		true}
hit :: proc(bytes: []u8, p: [2]f64, size: base.Extent) -> bool {return(
		p[0] >= 0 &&
		p[1] >= 0 &&
		p[0] < size.w &&
		p[1] < size.h \
	)}
main :: proc() {
	tracking: mem.Tracking_Allocator
	mem.tracking_allocator_init(
		&tracking,
		context.allocator,
	); defer mem.tracking_allocator_destroy(&tracking)
	a := mem.tracking_allocator(&tracking)
	p, pe := base.create(a); assert(pe == .None)
	ctx := interaction.create(a, &p)
	s := custom.create()
	stamp, se := base.begin_attempt(&p, 1); assert(se == .None)
	d := []custom.Description {
		{
			node_id = "disk",
			type_id = "rectangle",
			revision = "1",
			payload = []u8{7},
			validate = valid,
			measure = measure,
			hit = hit,
		},
	}
	m := custom.Metrics {
		descriptions = d,
	}
	g, ge := layout.prepare(
		[]layout.Node {
			{id = "root", role = .Stack, layout = layout.Layout{}, enabled = true, visible = true},
			{
				id = "disk",
				parent = "root",
				role = .Content,
				layout = layout.Layout{},
				enabled = true,
				visible = true,
			},
		},
		{drawable = {100, 100}, ui_scale = 1},
		{intrinsic = custom.measure, user = &m},
		a,
		stamp,
	)
	if ge.code != .None {fmt.eprintf("layout: %v\n", ge); panic("layout preparation refused")}
	i, ie := interaction.prepare(
		&g,
		[]interaction.Target{{id = "disk", role = "button", enabled = true, visible = true}},
		[]interaction.Capture_Claim{{"disk", "custom"}},
		a,
	)
	assert(ie == .Applied && interaction.bind_activation_owner(&i, "disk", "custom") == .Applied)
	c, ce := custom.prepare(&g, &i, d, a); assert(ce.code == .None)
	r, copied := custom.try_copy_frame(&c, a); assert(copied)
	assert(custom.validate_candidate(&p, &c) && base.enter_commit(&p, stamp) == .None)
	interaction.commit(&ctx, &i)
	custom.commit(&s, &c)
	base.finish_commit(&p, stamp)
	assert(
		interaction.dispatch(&ctx, {.Activate, "disk", .Agent, false}).code ==
		.Activation_Required,
	)
	event := interaction.dispatch_owned(&ctx, {.Activate, "disk", .Agent, false}, "custom")
	assert(event.has_event && event.event.sequence == 1)
	assert(
		interaction.dispatch_owned(&ctx, {.Activate, "disk", .Agent, false}, "custom").code ==
		.Not_Ready,
	)
	layout.destroy_frame(&g); custom.destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	assert(custom.hit(&r, "disk", {5, 5}))
	fmt.printf(
		"custom-only State=%d Frame=%d allocations=%d bytes=%d live=%d peak=%d handlers=0 backend=0\n",
		size_of(custom.State),
		size_of(custom.Frame),
		tracking.total_allocation_count,
		tracking.total_memory_allocated,
		tracking.current_memory_allocated,
		tracking.peak_memory_allocated,
	)
	custom.destroy_frame(&r)
	assert(tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
}
