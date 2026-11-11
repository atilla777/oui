package ui_rich

import base "../ui_base"
import "base:runtime"
import "core:mem"
import "core:testing"

@(test)
every_owning_pipeline_and_reader_allocation_refuses_without_leak :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	stamp, _ := base.begin_attempt(&p, 1)
	refs := p.lifetime.references
	tracking: mem.Tracking_Allocator
	mem.tracking_allocator_init(
		&tracking,
		context.allocator,
	); defer mem.tracking_allocator_destroy(&tracking)
	tracking.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	fault := Fault {
		backing = mem.tracking_allocator(&tracking),
	}
	a := mem.Allocator{fault_allocator, &fault}
	ids := [2]string{"body", "fallback"}
	m := Rich_Text_Metrics {
		measure    = rich_fake_measure,
		image      = rich_fake_image,
		coverage   = coverage,
		font_chain = chain,
		user       = &ids,
	}
	c, e := pipeline_fixture(stamp, a, m)
	if !testing.expect(t, e.code == .None) {destroy_candidate(&c); return}
	count := fault.requests; destroy_candidate(&c)
	for position in 1 ..= count {
		fault.requests, fault.refuse = 0, position
		c, e = pipeline_fixture(stamp, a, m)
		testing.expect(
			t,
			(e.code == .Allocation || (e.code == .Existing && e.existing.code == .Allocation)) &&
			c.frame.rich_blocks == nil,
		)
		destroy_candidate(&c)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 &&
			len(tracking.bad_free_array) == 0 &&
			p.lifetime.references == refs,
		)
	}
	source, se := pipeline_fixture(stamp, context.allocator, m); defer destroy_candidate(&source)
	if !testing.expect(t, se.code == .None) {return}
	fault.requests, fault.refuse = 0, 0
	r, copied := try_copy_frame(&source.frame, a)
	if !testing.expect(t, copied) {destroy_frame(&r); return}
	count = fault.requests; destroy_frame(&r)
	for position in 1 ..= count {
		fault.requests, fault.refuse = 0, position
		r, copied = try_copy_frame(&source.frame, a)
		testing.expect(t, !copied && r.rich_blocks == nil)
		destroy_frame(&r)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 &&
			len(tracking.bad_free_array) == 0 &&
			p.lifetime.references == refs + 2,
		)
	}
}
Fault :: struct {
	backing:          mem.Allocator,
	requests, refuse: int,
}
fault_allocator :: proc(
	data: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old: rawptr,
	old_size: int,
	location: runtime.Source_Code_Location = #caller_location,
) -> (
	[]u8,
	mem.Allocator_Error,
) {
	f := cast(^Fault)data
	if mode == .Alloc ||
	   mode == .Resize ||
	   mode == .Resize_Non_Zeroed ||
	   mode ==
		   .Alloc_Non_Zeroed {f.requests += 1; if f.requests == f.refuse {return nil, .Out_Of_Memory}}
	return f.backing.procedure(f.backing.data, mode, size, alignment, old, old_size, location)
}
@(test)
parser_allocation_refusal_is_typed :: proc(t: ^testing.T) {
	fault := Fault {
		backing = context.allocator,
		refuse  = 1,
	}
	d, e := parse_rich_text(
		"Я[b]b[/b]",
		{font_id = "body", size = 16},
		mem.Allocator{fault_allocator, &fault},
	)
	defer destroy_rich_document(&d)
	testing.expect(t, e.code == .Allocation && d.source == "")
}
