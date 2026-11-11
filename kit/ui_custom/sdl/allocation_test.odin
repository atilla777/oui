package ui_custom_sdl

import "base:runtime"
import "core:mem"
import "core:testing"
import sdl "vendor:sdl3"
Painter_Fault :: struct {
	backing:          mem.Allocator,
	requests, refuse: int,
}
painter_fault_allocator :: proc(
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
	f := cast(^Painter_Fault)data
	if mode == .Alloc ||
	   mode == .Alloc_Non_Zeroed ||
	   mode == .Resize ||
	   mode ==
		   .Resize_Non_Zeroed {f.requests += 1; if f.requests == f.refuse {return nil, .Out_Of_Memory}}
	return f.backing.procedure(f.backing.data, mode, size, alignment, old, old_size, loc)
}
@(test)
generation_allocation_refusals_clean_partial_metadata :: proc(t: ^testing.T) {
	s := sdl.CreateSurface(
		4,
		4,
		.RGBA32,
	); if !testing.expect(t, s != nil) {return}; defer sdl.DestroySurface(s)
	r := sdl.CreateSoftwareRenderer(
		s,
	); if !testing.expect(t, r != nil) {return}; defer sdl.DestroyRenderer(r)
	for refuse := 1; refuse < 64; refuse += 1 {
		tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator)
		fault := Painter_Fault {
			backing = mem.tracking_allocator(&tracking),
			refuse  = refuse,
		}
		g, e := create_generation(
			r,
			"v1",
			[]Painter{{"circle", "1", disk}},
			mem.Allocator{painter_fault_allocator, &fault},
		)
		succeeded := e.code == .None
		if !succeeded {testing.expect(t, e.code == .Allocation && g == nil)}
		release_generation(&g)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0,
		)
		mem.tracking_allocator_destroy(&tracking)
		if succeeded {return}
	}
	testing.expect(t, false)
}
