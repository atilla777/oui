package main

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:testing"

Fault :: struct {
	backing:       mem.Allocator,
	count, refuse: int,
}
fault_allocator :: proc(
	data: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old: rawptr,
	old_size: int,
	loc: runtime.Source_Code_Location,
) -> (
	[]u8,
	mem.Allocator_Error,
) {
	f := cast(^Fault)data
	if size > 0 &&
	   (mode == .Alloc ||
			   mode == .Alloc_Non_Zeroed ||
			   mode == .Resize ||
			   mode ==
				   .Resize_Non_Zeroed) {f.count += 1; if f.count == f.refuse {return nil, .Out_Of_Memory}}
	return f.backing.procedure(f.backing.data, mode, size, alignment, old, old_size, loc)
}
@(test)
every_publisher_allocation_failure_preserves_all_owners_readers_and_no_effect_replay :: proc(
	t: ^testing.T,
) {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	tracking.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	backing := mem.tracking_allocator(
		&tracking,
	); previous := context.allocator; context.allocator = backing; defer {context.allocator = previous}
	fault := Fault {
		backing = backing,
	}; a := mem.Allocator{fault_allocator, &fault}
	r: Runtime; init(&r); testing.expect(t, publish(&r))
	context.allocator =
		a; testing.expect(t, publish(&r)); count := fault.count; context.allocator = backing; destroy(&r)
	for pos in 1 ..= count {
		init(
			&r,
		); testing.expect(t, publish(&r)); live := tracking.current_memory_allocated; refs := r.p.lifetime.references; stamp := r.ctx.frame.stamp
		fault.count, fault.refuse = 0, pos; context.allocator = a
		ok := publish(&r); context.allocator = backing
		testing.expect(
			t,
			!ok &&
			!r.p.ready &&
			r.ctx.frame.stamp == stamp &&
			r.layers.frame.stamp == stamp &&
			r.scroll.frame.stamp == stamp &&
			r.hold.frame.stamp == stamp &&
			r.controls.frame.stamp == stamp &&
			r.reader.geometry.stamp == stamp,
			fmt.tprintf("publisher refusal %d", pos),
		)
		testing.expect(
			t,
			tracking.current_memory_allocated == live &&
			len(tracking.bad_free_array) == 0 &&
			r.p.lifetime.references == refs,
			fmt.tprintf("cleanup refusal %d", pos),
		)
		destroy(&r); testing.expect(t, tracking.current_memory_allocated == 0)
	}
	fmt.printf(
		"selected-input publisher-refusals=%d peak=%d live=%d\n",
		count,
		tracking.peak_memory_allocated,
		tracking.current_memory_allocated,
	)
}
