package ui_editor
import base "../ui_base"
import interaction "../ui_interaction"
import "base:runtime"
import "core:mem"
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
copy_and_dispatch_allocation_refusal_are_atomic :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(); defer destroy(&s)
	if !publish(t, &p, &ctx, &s, description()) {return}
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	tracking.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	fault := Fault {
		backing = mem.tracking_allocator(&tracking),
	}; a := mem.Allocator{fault_allocator, &fault}
	refs := p.lifetime.references
	f, ok := try_copy_frame(
		&s.frame,
		a,
	); testing.expect(t, ok); count := fault.requests; destroy_frame(&f)
	for position in 1 ..= count {
		fault.requests, fault.refuse = 0, position
		f, ok = try_copy_frame(&s.frame, a); destroy_frame(&f)
		testing.expect(
			t,
			!ok &&
			tracking.current_memory_allocated == 0 &&
			p.lifetime.references == refs &&
			len(tracking.bad_free_array) == 0,
		)
	}
	s.allocator = a
	fault.requests, fault.refuse = 0, 0
	r := dispatch(&s, &ctx, {id = "name", kind = .Insert, text = "x"}, metrics())
	testing.expect(t, r.proposal != nil); count = fault.requests; destroy_result(&r)
	// Restore only via the normal explicit rejection/rebuild path, not test mutation.
	d := description(); d.resolution = {
		kind     = .Rejected,
		sequence = p.sequence,
	}
	if !publish(t, &p, &ctx, &s, d) {return}
	for position in 1 ..= count {
		fault.requests, fault.refuse = 0, position
		before, version := p.sequence, s.version
		r = dispatch(&s, &ctx, {id = "name", kind = .Insert, text = "x"}, metrics())
		destroy_result(&r)
		testing.expect(
			t,
			p.ready &&
			s.pending == nil &&
			p.sequence == before &&
			s.version == version &&
			tracking.current_memory_allocated == 0 &&
			len(tracking.bad_free_array) == 0,
		)
	}
}
@(test)
common_guards_precede_editor_value_validation :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(); defer destroy(&s)
	if !publish(t, &p, &ctx, &s, description()) {return}
	for refusal in ([4]interaction.Code{.Disabled, .Not_Visible, .Blocked_By_Modal, .Non_Interactive_Overlay}) {
		ctx.frame.targets[0].availability = refusal
		r := dispatch(&s, &ctx, {id = "name", kind = .Insert, text = "\xff"}, metrics())
		testing.expect(t, r.code == refusal && r.rejection == .None && p.sequence == 0 && p.ready)
	}
	base.invalidate(&p)
	testing.expect(
		t,
		dispatch(&s, &ctx, {id = "missing", source = interaction.Source(99)}, metrics()).code ==
		.Not_Ready,
	)
}
