package main

import "core:fmt"
import "core:mem"
import base "ui:ui_base"
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
	s, se := base.begin_attempt(&p, 1); assert(se == .None)
	nodes := [2]layout.Node {
		{
			id = "root",
			role = .Row,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}, gap = 10},
			enabled = true,
			visible = true,
		},
		{
			id = "box",
			parent = "root",
			role = .Box,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 20},
				y = {mode = .Fixed, value = 15},
			},
			enabled = true,
			visible = true,
		},
	}
	f, error := layout.prepare(
		nodes[:],
		{drawable = {100, 60}, ui_scale = 1},
		{},
		context.allocator,
		s,
	)
	assert(error.code == .None); defer layout.destroy_frame(&f)
	fmt.printf(
		"layout-prepare allocations=%d bytes=%d live=%d peak=%d Publication=%d Lifetime=%d Frame=%d Node=%d handlers=0 backend-resources=0\n",
		live.total_allocation_count,
		live.total_memory_allocated,
		live.current_memory_allocated,
		live.peak_memory_allocated,
		size_of(base.Publication),
		size_of(base.Lifetime),
		size_of(layout.Frame),
		size_of(layout.Node),
	)
	n, found := layout.find(&f, "box"); assert(found && n.bounds == (base.Rect{0, 0, 20, 15}))
	reader, copied := layout.try_copy_frame(
		&f,
		context.allocator,
	); assert(copied); defer layout.destroy_frame(&reader)
	layout.destroy_frame(&f); base.destroy(&p)
	n, found = layout.find(&reader, "box"); assert(found && n.bounds.w == 20)
	layout.destroy_frame(&reader)
	fmt.printf(
		"destroy allocations=%d bytes=%d live=%d peak=%d\n",
		live.total_allocation_count,
		live.total_memory_allocated,
		live.current_memory_allocated,
		live.peak_memory_allocated,
	)
	assert(live.current_memory_allocated == 0 && len(live.bad_free_array) == 0)
}
