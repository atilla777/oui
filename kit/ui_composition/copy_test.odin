package ui_composition

import layout "../ui_layout"
import style "../ui_style"
import "base:runtime"
import "core:mem"
import "core:strings"
import "core:testing"

@(test)
reader_survives_source_and_borrowed_descriptions :: proc(t: ^testing.T) {
	bytes := [3]u8{'o', 'n', 'e'}
	decl := [1]style.Declaration{{.Font, style.Font_ID{"font"}}}
	tracks := [1]layout.Track{{mode = .Fixed, value = 13}}
	nodes := [1]Node {
		{
			node = {
				id = string(bytes[:]),
				role = .Grid,
				layout = layout.Layout{columns = tracks[:]},
			},
		},
	}
	nodes[0].appearance.local.states[.Normal] = decl[:]
	c, e := compose_panel("a", "", {}, {}, []Slot{{name = "content", nodes = nodes[:]}})
	if !testing.expect(t, e == .None) {return}
	bytes[0] = 'X'; tracks[0].value = 99; decl[0].value = style.Font_ID{"wrong"}
	r, re := try_copy(&c)
	destroy(&c)
	defer destroy(&r)
	if !testing.expect(t, re == .None) {return}
	testing.expect(t, r.nodes[3].node.id == "node:1:a7:content3:one")
	testing.expect(t, r.nodes[3].node.layout.?.columns[0].value == 13)
	testing.expect(
		t,
		r.nodes[3].appearance.local.states[.Normal][0].value.(style.Font_ID).id == "font",
	)
}

Fault :: struct {
	backing:          mem.Allocator,
	requests, refuse: int,
}

@(test)
all_prepare_and_copy_allocation_refusals_clean :: proc(t: ^testing.T) {
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
	// More than a rollback block: both upstream blocks and bookkeeping are fallible.
	large := make([]Node, 40); defer delete(large)
	for &n, index in large {id := [1]u8{u8(index + 33)}; n.node.id = string(id[:]); n.node.id = strings.clone(n.node.id); n.appearance.style_id = "selected"}
	defer {for n in large {delete(n.node.id)}}
	slots := []Slot{{name = "content", nodes = large}}
	c, e := compose_panel("n", "host", {}, {}, slots, a)
	if !testing.expect(t, e == .None) {return}
	prepare_count := fault.requests
	destroy(&c)
	for position in 1 ..= prepare_count {
		fault.requests, fault.refuse = 0, position
		c, e = compose_panel("n", "host", {}, {}, slots, a)
		testing.expect(t, e == .Allocation && c.nodes == nil)
		destroy(&c)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0,
		)
	}
	source, se := compose_panel("n", "host", {}, {}, slots)
	defer destroy(&source)
	if !testing.expect(t, se == .None) {return}
	fault.requests, fault.refuse = 0, 0
	r, re := try_copy(&source, a)
	if !testing.expect(t, re == .None) {return}
	copy_count := fault.requests; destroy(&r)
	for position in 1 ..= copy_count {
		fault.requests, fault.refuse = 0, position
		r, re = try_copy(&source, a)
		testing.expect(t, re == .Allocation && r.nodes == nil)
		destroy(&r)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0,
		)
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
	   mode == .Alloc_Non_Zeroed {
		f.requests += 1
		if f.requests == f.refuse {return nil, .Out_Of_Memory}
	}
	return f.backing.procedure(f.backing.data, mode, size, alignment, old, old_size, location)
}
