package ui_rich_sdl

import "base:runtime"
import "core:mem"
import "core:os"
import "core:testing"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"
Font_Fault :: struct {
	backing:          mem.Allocator,
	requests, refuse: int,
}
font_fault_allocator :: proc(
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
	f := cast(^Font_Fault)data
	if mode == .Alloc ||
	   mode == .Resize ||
	   mode == .Resize_Non_Zeroed ||
	   mode ==
		   .Alloc_Non_Zeroed {f.requests += 1; if f.requests == f.refuse {return nil, .Out_Of_Memory}}
	return f.backing.procedure(f.backing.data, mode, size, alignment, old, old_size, location)
}
@(test)
native_generation_allocator_refusal_is_addressed_as_allocation :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	surface := sdl.CreateSurface(
		40,
		40,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	r := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, r != nil) {return}; defer sdl.DestroyRenderer(r)
	data, read := os.read_entire_file(
		"resources/font.ttf",
		context.allocator,
	); if !testing.expect(t, read == nil) {return}; defer delete(data)
	for refuse := 1; refuse < 256; refuse += 1 {
		tracking: mem.Tracking_Allocator
		mem.tracking_allocator_init(&tracking, context.allocator)
		fault := Font_Fault {
			backing = mem.tracking_allocator(&tracking),
			refuse  = refuse,
		}
		native := sdl.GetNumAllocations()
		g, e := create_generation(
			r,
			"v1",
			nil,
			[]Rich_Font_Source{{"body", data}},
			[]Rich_Font_Chain{{"body", nil}},
			[]Rich_Font_Request{{"body", 16, false, false, false}},
			1,
			mem.Allocator{font_fault_allocator, &fault},
		)
		success := e.code == .None
		if !success {testing.expect(t, g == nil && e.code == .Allocation)}
		release_generation(&g)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0,
		)
		testing.expect(t, sdl.GetNumAllocations() == native)
		mem.tracking_allocator_destroy(&tracking)
		if success {return}
	}
	testing.expect(t, false, "allocation walk never reached success")
}
