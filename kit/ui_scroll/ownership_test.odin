package ui_scroll

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:testing"

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
				   .Resize_Non_Zeroed) {f.requests += 1; if f.requests == f.refuse {return nil, .Out_Of_Memory}}
	return f.backing.procedure(f.backing.data, mode, size, alignment, old, old_size, loc)
}

@(test)
reader_owns_all_ids_and_retains_stamp_after_every_source_is_destroyed :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator)
	g, i := fixture(t, &p, context.allocator)
	s := create(context.allocator)
	ds := [1]Description{{"scroll", "content"}}
	c, e := prepare(&s, &g, &i, ds[:], context.allocator)
	if !testing.expect(
		t,
		e.code == .None,
	) {interaction.destroy_frame(&i); layout.destroy_frame(&g); destroy(&s); base.destroy(&p); return}
	reader, ok := try_copy_frame(&c.frame, context.allocator); defer destroy_frame(&reader)
	testing.expect(t, ok && raw_data(reader.regions[0].id) != raw_data(c.frame.regions[0].id))
	destroy_candidate(
		&c,
	); destroy(&s); interaction.destroy_frame(&i); layout.destroy_frame(&g); base.destroy(&p)
	if !ok {return}
	testing.expect(
		t,
		reader.regions[0].id == "scroll" &&
		reader.regions[0].items[2].id == "c" &&
		reader.regions[0].anchor_id == "a",
	)
	testing.expect(t, reader.stamp.lifetime != nil && !reader.stamp.lifetime.alive)
}

@(test)
every_prepare_and_copy_allocation_refusal_has_zero_partial_live_owners :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	g, i := fixture(
		t,
		&p,
		context.allocator,
	); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&i)
	s := create(context.allocator); defer destroy(&s)
	ds := [1]Description{{"scroll", "content"}}
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	tracking.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	f := Fault {
		backing = mem.tracking_allocator(&tracking),
	}; a := mem.Allocator{fault_allocator, &f}
	refs := p.lifetime.references
	c, e := prepare(&s, &g, &i, ds[:], a); if !testing.expect(t, e.code == .None) {return}
	count := f.requests; destroy_candidate(&c)
	for position in 1 ..= count {
		f.requests, f.refuse = 0, position
		c, e = prepare(
			&s,
			&g,
			&i,
			ds[:],
			a,
		); testing.expect(t, e.code == .Allocation && c.geometry.nodes == nil, fmt.tprintf("prepare refusal %d", position)); destroy_candidate(&c)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 &&
			len(tracking.bad_free_array) == 0 &&
			p.lifetime.references == refs,
		)
	}
	c, e = prepare(
		&s,
		&g,
		&i,
		ds[:],
		context.allocator,
	); if !testing.expect(t, e.code == .None) {return}; defer destroy_candidate(&c)
	refs = p.lifetime.references; f.requests, f.refuse = 0, 0
	reader, ok := try_copy_frame(
		&c.frame,
		a,
	); testing.expect(t, ok); copies := f.requests; destroy_frame(&reader)
	for position in 1 ..= copies {
		f.requests, f.refuse = 0, position
		reader, ok = try_copy_frame(
			&c.frame,
			a,
		); testing.expect(t, !ok && reader.regions == nil, fmt.tprintf("copy refusal %d", position)); destroy_frame(&reader)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 &&
			len(tracking.bad_free_array) == 0 &&
			p.lifetime.references == refs,
		)
	}
	fmt.printf(
		"scroll prepare-positions=%d copy-positions=%d peak=%d live=%d State=%d Frame=%d Candidate=%d handlers=0 backend-resources=0\n",
		count,
		copies,
		tracking.peak_memory_allocated,
		tracking.current_memory_allocated,
		size_of(State),
		size_of(Frame),
		size_of(Candidate),
	)
}

@(test)
addressed_error_copy_survives_borrowed_id :: proc(t: ^testing.T) {
	id := strings.clone("temporary")
	e := describe_error({.Invalid_Scroll, id})
	owned, ok := base.try_copy_error(
		e,
		context.allocator,
	); delete(id); defer base.destroy_error(&owned)
	testing.expect(
		t,
		ok &&
		owned.family == .Scroll &&
		owned.stage == .Prepare &&
		owned.id == "temporary" &&
		owned.code == u32(Error_Code.Invalid_Scroll),
	)
}
