package ui_hold

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:testing"

Fault :: struct {
	backing:       mem.Allocator,
	count, refuse: int,
}
fault_alloc :: proc(
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
owning_copy_retains_signals_descriptions_and_progress_after_all_sources_die :: proc(
	t: ^testing.T,
) {
	p, _ := base.create(
		context.allocator,
	); ctx := interaction.create(context.allocator, &p); s := create(context.allocator)
	publish(
		t,
		&p,
		&ctx,
		&s,
	); dispatch(&s, &ctx, {kind = .Begin, id = "confirm", source = .Agent}); publish(t, &p, &ctx, &s)
	r, ok := try_copy_frame(&s.frame, context.allocator)
	destroy(&s); interaction.destroy(&ctx); base.destroy(&p); defer destroy_frame(&r)
	if !testing.expect(t, ok) {return}
	testing.expect(
		t,
		r.holds[0].id == "confirm" &&
		r.hold.id == "confirm" &&
		r.result.signals[0].id == "confirm" &&
		!r.stamp.lifetime.alive,
	)
	testing.expect(t, raw_data(r.result.signals[0].id) == raw_data(r.hold.id))
}

@(test)
prepare_and_copy_refusal_preserve_targets_and_release_all_partial_owners :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	publish(
		t,
		&p,
		&ctx,
		&s,
	); dispatch(&s, &ctx, {kind = .Begin, id = "confirm", source = .Agent}); publish(t, &p, &ctx, &s)
	g, i := geometry(t, &p); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&i)
	hs := [1]Description{{"confirm", 500}}; ps := [1]Progress_Description{{"bar", 25, 100}}
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	tracking.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	fault := Fault {
		backing = mem.tracking_allocator(&tracking),
	}; a := mem.Allocator{fault_alloc, &fault}
	refs := p.lifetime.references
	c, e := prepare(
		&s,
		&ctx,
		&g,
		&i,
		ps[:],
		hs[:],
		a,
	); testing.expect(t, e.code == .None); count := fault.count; destroy_candidate(&c)
	for pos in 1 ..= count {
		n, _ := interaction.find(
			&i,
			"confirm",
		); delete(n.activation_owner, i.allocator); n.activation_owner = ""
		fault.count, fault.refuse = 0, pos
		c, e = prepare(&s, &ctx, &g, &i, ps[:], hs[:], a)
		testing.expect(t, e.code == .Allocation && c.frame.holds == nil); destroy_candidate(&c)
		testing.expect(
			t,
			n.activation_owner == "",
			"failed metadata preparation cannot bind candidate interaction",
		)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 &&
			len(tracking.bad_free_array) == 0 &&
			p.lifetime.references == refs,
		)
	}
	fault.count, fault.refuse = 0, 0
	c, e = prepare(
		&s,
		&ctx,
		&g,
		&i,
		ps[:],
		hs[:],
		context.allocator,
	); testing.expect(t, e.code == .None); defer destroy_candidate(&c)
	refs = p.lifetime.references
	r, ok := try_copy_frame(
		&c.frame,
		a,
	); testing.expect(t, ok); copies := fault.count; destroy_frame(&r)
	for pos in 1 ..= copies {fault.count, fault.refuse = 0, pos; r, ok = try_copy_frame(&c.frame, a); testing.expect(t, !ok && r.holds == nil); destroy_frame(&r); testing.expect(t, tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0 && p.lifetime.references == refs)}
	fmt.printf(
		"hold prepare-refusals=%d copy-refusals=%d peak=%d live=%d State=%d Frame=%d\n",
		count,
		copies,
		tracking.peak_memory_allocated,
		tracking.current_memory_allocated,
		size_of(State),
		size_of(Frame),
	)
}
