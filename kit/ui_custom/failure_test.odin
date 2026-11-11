package ui_custom

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
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
	location: runtime.Source_Code_Location = #caller_location,
) -> (
	[]u8,
	mem.Allocator_Error,
) {
	f := cast(^Fault)data
	if mode == .Alloc ||
	   mode == .Resize ||
	   mode == .Resize_Non_Zeroed ||
	   mode == .Alloc_Non_Zeroed {
		f.requests += 1
		if f.requests == f.refuse {return nil, .Out_Of_Memory}
	}
	return f.backing.procedure(f.backing.data, mode, size, alignment, old, old_size, location)
}
fixture :: proc(
	stamp: base.Frame_Stamp,
	a: mem.Allocator,
	owner := "custom",
	duplicate := false,
) -> (
	Candidate,
	Error,
) {
	nodes := [1]layout.Resolved_Node {
		{
			description = {id = "disk", role = .Content},
			bounds = {0, 0, 20, 20},
			content = {0, 0, 20, 20},
			paint_clip = {0, 0, 20, 20},
			clip = {0, 0, 20, 20},
		},
	}
	g := layout.Frame {
		nodes = nodes[:],
		stamp = stamp,
	}
	targets := [1]interaction.Target_View {
		{description = {id = "disk"}, availability = .Applied, activation_owner = owner},
	}
	i := interaction.Frame {
		targets = targets[:],
		stamp   = stamp,
	}
	d := Description {
		node_id         = "disk",
		type_id         = "circle",
		revision        = "1",
		semantic_name   = "круг",
		hit_description = "disk",
		payload         = []u8{3},
		validate        = validate_disk,
		measure         = measure_disk,
		hit             = hit_disk,
	}
	if duplicate {return prepare(&g, &i, []Description{d, d}, a)}
	return prepare(&g, &i, []Description{d}, a)
}
@(test)
owning_failure_positions_and_refusals :: proc(t: ^testing.T) {
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
	f, e := fixture(stamp, a)
	if !testing.expect(t, e.code == .None) {return}
	count := fault.requests; destroy_frame(&f)
	for position in 1 ..= count {
		fault.requests, fault.refuse = 0, position
		f, e = fixture(stamp, a)
		testing.expect(t, e.code == .Allocation && f.views == nil)
		destroy_frame(&f)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 &&
			len(tracking.bad_free_array) == 0 &&
			p.lifetime.references == refs,
		)
	}
	source, se := fixture(stamp, context.allocator); defer destroy_frame(&source)
	if !testing.expect(t, se.code == .None) {return}
	fault.requests, fault.refuse = 0, 0
	r, copied := try_copy_frame(&source, a)
	if !testing.expect(t, copied) {return}
	count = fault.requests; destroy_frame(&r)
	for position in 1 ..= count {
		fault.requests, fault.refuse = 0, position
		r, copied = try_copy_frame(&source, a)
		testing.expect(t, !copied && r.views == nil)
		destroy_frame(&r)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 &&
			len(tracking.bad_free_array) == 0 &&
			p.lifetime.references == refs + 1,
		)
	}
	for owner in ([]string{"editor", "hold", "slider", "gesture", ""}) {
		f, e = fixture(stamp, context.allocator, owner)
		testing.expect(t, e.code == .Binding && f.views == nil); destroy_frame(&f)
	}
	f, e = fixture(stamp, context.allocator, duplicate = true)
	testing.expect(t, e.code == .Descriptor); destroy_frame(&f)
	before := source.views[0].geometry
	entries := []base.Geometry_Entry {
		{id = "disk", input_enabled = true, geometry = before},
		{id = "disk", geometry = before},
	}
	testing.expect(
		t,
		!sample_candidate(&source, {stamp, entries}) && source.views[0].geometry == before,
	)
	wrong := stamp; wrong.attempt += 1
	testing.expect(t, !sample_candidate(&source, {wrong, entries[:1]}))
	entries[0].geometry.scale = -1
	testing.expect(t, !sample_candidate(&source, {stamp, entries[:1]}))
	entries[0].geometry = before; entries[0].input_enabled = false
	testing.expect(
		t,
		sample_candidate(&source, {stamp, entries[:1]}) && !hit(&source, "disk", {10, 10}),
	)
}
