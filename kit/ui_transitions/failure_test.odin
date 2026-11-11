package ui_transitions

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:testing"

Transition_Fault :: struct {
	backing:          mem.Allocator,
	requests, refuse: int,
}
transition_fault_allocator :: proc(
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
	f := cast(^Transition_Fault)data
	if mode == .Alloc ||
	   mode == .Alloc_Non_Zeroed ||
	   mode == .Resize ||
	   mode ==
		   .Resize_Non_Zeroed {f.requests += 1; if f.requests == f.refuse {return nil, .Out_Of_Memory}}
	return f.backing.procedure(f.backing.data, mode, size, alignment, old, old_size, loc)
}
@(test)
owning_prepare_geometry_reader_refusals_and_costs :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	stamp, _ := base.begin_attempt(&p, 1)
	nodes := []layout.Resolved_Node {
		{
			description = {id = "card", enabled = true, visible = true},
			bounds = {0, 0, 40, 20},
			content = {0, 0, 40, 20},
			clip = {0, 0, 40, 20},
			paint_clip = {0, 0, 40, 20},
			enabled = true,
			visible = true,
		},
	}
	g := layout.Frame {
		nodes    = nodes,
		stamp    = stamp,
		drawable = {100, 100},
		ui_scale = 1,
	}
	i := interaction.Frame {
		stamp   = stamp,
		targets = []interaction.Target_View {
			{description = {id = "card"}, availability = .Applied},
		},
	}
	for refuse := 1; refuse < 256; refuse += 1 {
		tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator)
		fault := Transition_Fault {
			backing = mem.tracking_allocator(&tracking),
			refuse  = refuse,
		}
		a := mem.Allocator{transition_fault_allocator, &fault}; s := create(a)
		c, e := prepare(
			&s,
			stamp,
			[]Description {
				{
					node_id = "card",
					present = true,
					tracks = []Track {
						{
							property = .Opacity,
							target = f64(1),
							presence = Endpoints{enter = f64(0), exit = f64(0)},
							timing = {duration_ms = 100},
						},
					},
				},
			},
			{},
			false,
			a,
		)
		succeeded := false
		if e.code == .None {
			be := bind_geometry(&c, &g, &i)
			if be.code == .None {
				reader, copied := try_copy_frame(&c.frame, a); succeeded = copied
				destroy_candidate(&c); destroy(&s)
				if copied {testing.expect(t, reader.entries[0].id == "card")}
				destroy_frame(&reader)
			} else {testing.expect(t, be.code == .Allocation)}
		} else {testing.expect(t, e.code == .Allocation)}
		destroy_candidate(&c); destroy(&s)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0,
		)
		if succeeded {fmt.printf("transitions common layout/input borrowed; family prepare+bind+reader allocations=%d bytes=%d peak=%d live=%d State=%d Frame=%d Candidate=%d handlers=0 backend=0\n", fault.requests, tracking.total_memory_allocated, tracking.peak_memory_allocated, tracking.current_memory_allocated, size_of(State), size_of(Frame), size_of(Candidate))}
		mem.tracking_allocator_destroy(&tracking)
		if succeeded {return}
	}
	testing.expect(t, false)
}
