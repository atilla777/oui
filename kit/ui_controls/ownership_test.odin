package ui_controls

import base "../ui_base"
import interaction "../ui_interaction"
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
owning_frame_copy_survives_all_sources_and_publication :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator)
	f := make_fixture(t, &p, .Select)
	ds := [1]Description{f.recipe.control}
	c, e := prepare(&f.interaction, f.layer.frame.layers, ds[:], context.allocator, &f.geometry)
	if !testing.expect(t, e.code == .None) {destroy_fixture(&f); base.destroy(&p); return}
	reader, ok := try_copy_frame(&c, context.allocator)
	testing.expect(t, ok)
	destroy_candidate(&c); destroy_fixture(&f); base.destroy(&p)
	defer destroy_frame(&reader)
	if !ok {return}
	testing.expect(
		t,
		reader.controls[0].label == "Выбор / Choice" &&
		reader.controls[0].items[0].label == "Один" &&
		reader.controls[0].items[1].id == "two" &&
		len(reader.gates) == 1,
	)
	testing.expect(t, !reader.stamp.lifetime.alive)
}

@(test)
every_recipe_prepare_and_copy_allocation_refusal_cleans_partial_owners :: proc(t: ^testing.T) {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	tracking.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	fault := Fault {
		backing = mem.tracking_allocator(&tracking),
	}; a := mem.Allocator{fault_allocator, &fault}
	recipe_positions := 0
	for kind in Kind {
		d := Description {
			id       = "choice",
			kind     = kind,
			label    = "Choice",
			body     = "Body",
			on_text  = "On",
			off_text = "Off",
		}
		if kind == .Slider {d.maximum = 100; d.step = 10; d.value = 50}
		if kind == .Tabs ||
		   kind == .List ||
		   kind == .Select ||
		   kind ==
			   .Dialog {d.items = []Item{{id = "one", label = "One"}, {id = "two", label = "Two"}}}
		if kind == .Select || kind == .Dialog {d.open = true}
		if kind == .Dialog {d.cancel_id = "two"}
		if kind == .Tooltip {d.trigger_id = "trigger"}
		fault.requests, fault.refuse = 0, 0
		r, e := compose_control(
			d,
			"base",
			"root",
			a,
		); testing.expect(t, e.code == .None); count := fault.requests; destroy_composition(&r); recipe_positions += count
		for position in 1 ..= count {
			fault.requests, fault.refuse = 0, position
			r, e = compose_control(d, "base", "root", a)
			testing.expect(
				t,
				e.code == .Allocation && len(r.nodes) == 0,
				fmt.tprintf("recipe kind=%v refusal=%d", kind, position),
			); destroy_composition(&r)
			testing.expect(
				t,
				tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0,
				fmt.tprintf("recipe cleanup kind=%v refusal=%d", kind, position),
			)
		}
	}
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	f := make_fixture(t, &p, .Dialog); defer destroy_fixture(&f)
	ds := [1]Description{f.recipe.control}; refs := p.lifetime.references
	fault.requests, fault.refuse = 0, 0
	c, e := prepare(
		&f.interaction,
		f.layer.frame.layers,
		ds[:],
		a,
		&f.geometry,
	); testing.expect(t, e.code == .None); prepares := fault.requests; destroy_candidate(&c)
	for position in 1 ..= prepares {
		fault.requests, fault.refuse = 0, position
		c, e = prepare(&f.interaction, f.layer.frame.layers, ds[:], a, &f.geometry)
		testing.expect(t, e.code == .Allocation && c.controls == nil); destroy_candidate(&c)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 &&
			len(tracking.bad_free_array) == 0 &&
			p.lifetime.references == refs,
			fmt.tprintf("prepare cleanup %d", position),
		)
	}
	c, e = prepare(
		&f.interaction,
		f.layer.frame.layers,
		ds[:],
		context.allocator,
		&f.geometry,
	); testing.expect(t, e.code == .None); defer destroy_candidate(&c)
	refs = p.lifetime.references; fault.requests, fault.refuse = 0, 0
	reader, ok := try_copy_frame(
		&c,
		a,
	); testing.expect(t, ok); copies := fault.requests; destroy_frame(&reader)
	for position in 1 ..= copies {
		fault.requests, fault.refuse = 0, position
		reader, ok = try_copy_frame(
			&c,
			a,
		); testing.expect(t, !ok && reader.controls == nil); destroy_frame(&reader)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 &&
			len(tracking.bad_free_array) == 0 &&
			p.lifetime.references == refs,
		)
	}
	fmt.printf(
		"controls recipe-positions=%d prepare-positions=%d copy-positions=%d peak=%d live=%d State=%d Frame=%d handlers=0 backend-resources=0\n",
		recipe_positions,
		prepares,
		copies,
		tracking.peak_memory_allocated,
		tracking.current_memory_allocated,
		size_of(State),
		size_of(Frame),
	)
}

@(test)
errors_are_addressed_and_copyable_before_borrowed_id_is_freed :: proc(t: ^testing.T) {
	id := strings.clone("invalid-control")
	v := describe_error({code = .Invalid_Item, control_id = "owner", node_id = id})
	e, ok := base.try_copy_error(v, context.allocator); delete(id); defer base.destroy_error(&e)
	testing.expect(
		t,
		ok &&
		e.family == .Controls &&
		e.stage == .Prepare &&
		e.id == "invalid-control" &&
		e.code == u32(Error_Code.Invalid_Item),
	)
}

@(test)
candidate_and_dispatch_reject_mixed_geometry_or_stale_family :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	f := make_fixture(t, &p, .Checkbox); defer destroy_fixture(&f)
	ds := [1]Description{f.recipe.control}
	c, e := prepare(
		&f.interaction,
		f.layer.frame.layers,
		ds[:],
		context.allocator,
		&f.geometry,
	); defer destroy_candidate(&c)
	if !testing.expect(t, e.code == .None && validate_candidate(&p, &c)) {return}
	other, _ := base.create(context.allocator); defer base.destroy(&other)
	testing.expect(t, !validate_candidate(&other, &c))
	g := f.geometry; g.stamp.attempt += 1
	bad, error := prepare(
		&f.interaction,
		f.layer.frame.layers,
		ds[:],
		context.allocator,
		&g,
	); destroy_candidate(&bad); testing.expect(t, error.code == .Stale)
	s := create(); commit(&s, &c); defer destroy(&s)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	base.enter_commit(
		&p,
		f.interaction.stamp,
	); interaction.commit(&ctx, &f.interaction); base.finish_commit(&p, ctx.frame.stamp)
	s.frame.stamp.attempt += 1
	r := dispatch(&s, &ctx, {kind = .Activate, id = ds[0].node_id, source = .Agent})
	testing.expect(t, r.dispatch.code == .Not_Ready && !r.dispatch.has_event && p.ready)
}
