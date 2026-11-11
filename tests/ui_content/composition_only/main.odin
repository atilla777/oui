package main

import "core:fmt"
import "core:mem"
import composition "ui:ui_composition"

main :: proc() {
	tracking: mem.Tracking_Allocator
	mem.tracking_allocator_init(
		&tracking,
		context.allocator,
	); defer mem.tracking_allocator_destroy(&tracking)
	a := mem.tracking_allocator(&tracking)
	c, e := composition.compose_panel(
		"menu",
		"",
		{},
		{},
		[]composition.Slot {
			{
				name = "content",
				nodes = []composition.Node{{node = {id = "go", enabled = true, visible = true}}},
			},
		},
		a,
	)
	assert(e == .None && len(c.nodes) == 5)
	r, re := composition.try_copy(&c, a); assert(re == .None)
	composition.destroy(&c)
	assert(r.nodes[3].node.id == "node:4:menu7:content2:go")
	fmt.printf(
		"composition-only owner=%d alloc=%d bytes=%d live=%d peak=%d handlers=0 backend=0\n",
		size_of(composition.Composition),
		tracking.total_allocation_count,
		tracking.total_memory_allocated,
		tracking.current_memory_allocated,
		tracking.peak_memory_allocated,
	)
	composition.destroy(&r)
	assert(tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
}
