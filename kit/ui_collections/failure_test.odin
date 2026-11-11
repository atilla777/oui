package ui_collections

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
@(test)
all_prepare_materialize_and_reader_allocations_roll_back_without_leaks :: proc(t: ^testing.T) {
	d := fixture_description(
		[]Collection_Item {
			{"a", "Я", true, true, ""},
			{"b", "B", true, false, "locked"},
			{"c", "C", true, true, ""},
		},
	)
	d.mode, d.card_width = .Grid, 40
	source, se := prepare_collection(d, {w = 100, h = 20}, 0); defer destroy_frame(&source)
	if !testing.expect(t, se.code == .None) {return}
	for phase in 0 ..< 3 {
		succeeded := false
		for refuse := 1; refuse < 256; refuse += 1 {
			tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator)
			fault := Fault {
				backing = mem.tracking_allocator(&tracking),
				refuse  = refuse,
			}
			a := mem.Allocator{fault_allocator, &fault}
			if phase == 0 {
				f, e := prepare_collection(d, {w = 100, h = 20}, 0, a)
				succeeded = e.code == .None
				if !succeeded {testing.expect(t, e.code == .Allocation && len(f.nodes) == 0)}
				destroy_frame(&f)
			} else if phase == 1 {
				f, ok := try_copy_frame(&source, a); succeeded = ok
				if !ok {testing.expect(t, len(f.nodes) == 0)}
				destroy_frame(&f)
			} else {
				nodes, e := materialize(&source, a); succeeded = e.code == .None
				if !succeeded {testing.expect(t, e.code == .Allocation && nodes == nil)}
				destroy_nodes(nodes, a)
			}
			testing.expect(
				t,
				tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0,
			)
			mem.tracking_allocator_destroy(&tracking)
			if succeeded {break}
		}
		testing.expect(t, succeeded)
	}
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
fixture_description :: proc(items: []Collection_Item) -> Collection_Description {return {
		id = "list",
		scroll_id = "scroll",
		content_id = "content",
		height = 10,
		gap = 2,
		items = items,
	}}
@(test)
binding_failure_never_publishes_partial_clones_or_mutates_state :: proc(t: ^testing.T) {
	for refuse := 1; refuse < 64; refuse += 1 {
		tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator)
		fault := Fault {
			backing = mem.tracking_allocator(&tracking),
		}
		a := mem.Allocator{fault_allocator, &fault}
		p, _ := base.create(context.allocator)
		s := create(a); stamp, _ := base.begin_attempt(&p, 1)
		c, e := prepare(
			&s,
			stamp,
			fixture_description(
				[]Collection_Item{{"a", "A", true, true, ""}, {"b", "B", true, true, ""}},
			),
			{w = 100, h = 20},
			0,
			a,
		)
		if !testing.expect(
			t,
			e.code == .None,
		) {destroy_candidate(&c); destroy(&s); base.destroy(&p); mem.tracking_allocator_destroy(&tracking); return}
		g, i, made := bind_fixture(t, &c, false)
		if !testing.expect(
			t,
			made,
		) {destroy_candidate(&c); destroy(&s); base.destroy(&p); mem.tracking_allocator_destroy(&tracking); return}
		fault.requests, fault.refuse = 0, refuse
		be := bind_candidate(&c, &g, &i)
		succeeded := be.code == .None
		if !succeeded {testing.expect(t, be.code == .Allocation && !validate_candidate(&p, &s, &c))}
		testing.expect(t, len(s.frame.collections) == 0 && !p.ready && p.sequence == 0)
		layout.destroy_frame(
			&g,
		); interaction.destroy_frame(&i); destroy_candidate(&c); destroy(&s); base.destroy(&p)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0,
		)
		mem.tracking_allocator_destroy(&tracking)
		if succeeded {return}
	}
	testing.expect(t, false)
}
@(test)
allocation_refusal_is_not_partial_success :: proc(t: ^testing.T) {
	fault := Fault {
		backing = context.allocator,
		refuse  = 2,
	}
	f, e := prepare_collection(
		fixture_description(
			[]Collection_Item{{"a", "Я", true, true, ""}, {"b", "B", true, false, "locked"}},
		),
		{w = 100, h = 20},
		0,
		mem.Allocator{fault_allocator, &fault},
	)
	defer destroy_frame(&f)
	testing.expect(t, e.code == .Allocation && len(f.nodes) == 0 && len(f.collections) == 0)
}
