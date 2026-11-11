package ui_rich

import base "../ui_base"
import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:testing"
Rich_Fault :: struct {
	backing:          mem.Allocator,
	requests, refuse: int,
}
rich_fault_allocator :: proc(
	data: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old: rawptr,
	old_size: int,
	loc: runtime.Source_Code_Location = #caller_location,
) -> (
	[]u8,
	mem.Allocator_Error,
) {
	f := cast(^Rich_Fault)data
	if mode == .Alloc ||
	   mode == .Alloc_Non_Zeroed ||
	   mode == .Resize ||
	   mode ==
		   .Resize_Non_Zeroed {f.requests += 1; if f.requests == f.refuse {return nil, .Out_Of_Memory}}
	return f.backing.procedure(f.backing.data, mode, size, alignment, old, old_size, loc)
}
@(test)
every_pipeline_and_reader_allocation_refusal_is_atomic :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	stamp, _ := base.begin_attempt(&p, 1)
	source, se := pipeline_fixture(
		stamp,
		context.allocator,
		{measure = rich_fake_measure, image = rich_fake_image},
	); defer destroy_candidate(&source)
	if !testing.expect(t, se.code == .None) {return}
	for phase in 0 ..< 2 {
		succeeded := false
		for refuse := 1; refuse < 1024; refuse += 1 {
			tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator)
			fault := Rich_Fault {
				backing = mem.tracking_allocator(&tracking),
				refuse  = refuse,
			}
			a := mem.Allocator{rich_fault_allocator, &fault}
			if phase == 0 {
				c, e := pipeline_fixture(
					stamp,
					a,
					{measure = rich_fake_measure, image = rich_fake_image},
				)
				succeeded = e.code == .None
				if !succeeded {testing.expect(t, (e.code == .Allocation || (e.code == .Existing && e.existing.code == .Allocation)) && len(c.frame.rich_blocks) == 0)}
				destroy_candidate(&c)
			} else {
				reader, copied := try_copy_frame(&source.frame, a); succeeded = copied
				if !copied {testing.expect(t, len(reader.rich_blocks) == 0)}
				destroy_frame(&reader)
			}
			testing.expect(
				t,
				tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0,
			)
			if succeeded {fmt.printf("rich phase=%d allocations=%d bytes=%d peak=%d live=%d Frame=%d Candidate=%d handlers=0 backend=0; prepare includes common layout, reader excludes it\n", phase, fault.requests, tracking.total_memory_allocated, tracking.peak_memory_allocated, tracking.current_memory_allocated, size_of(Frame), size_of(Candidate))}
			mem.tracking_allocator_destroy(&tracking)
			if succeeded {break}
		}
		testing.expect(t, succeeded)
	}
}
