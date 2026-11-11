package main
import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:testing"
import fonts "ui:ui_sdl_text"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"
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
every_selected_precommit_allocation_failure_keeps_old_reader_and_recovers :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	surface := sdl.CreateSurface(
		800,
		600,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
	data, de := os.read_entire_file(
		"resources/font.ttf",
		context.allocator,
	); if !testing.expect(t, de == nil) {return}; defer delete(data)
	g, ge := fonts.create_generation(
		renderer,
		"font-v1",
		[]fonts.Font_Source{{"font", 16, data}},
		1,
		context.allocator,
	); if !testing.expect(t, ge.code == .None) {return}; defer fonts.release_generation(&g)
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	tracking.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	fault := Fault {
		backing = mem.tracking_allocator(&tracking),
	}; a := mem.Allocator{fault_allocator, &fault}
	r: Runtime; if !testing.expect(t, init(&r, g, {800, 600}, a)) {return}
	if !testing.expect(t, rebuild(&r)) {destroy(&r); return}
	fault.requests = 0
	if !testing.expect(t, rebuild(&r)) {destroy(&r); return}
	positions :=
		fault.requests; live := tracking.current_memory_allocated; stamp := r.reader.editor.stamp; refs := g.readers
	for position in 1 ..= positions {
		fault.requests, fault.refuse = 0, position
		ok := rebuild(&r)
		if !testing.expect(
			t,
			!ok &&
			!r.publication.ready &&
			r.reader.editor.stamp == stamp &&
			r.effects == 0 &&
			tracking.current_memory_allocated == live &&
			len(tracking.bad_free_array) == 0 &&
			g.readers == refs,
			fmt.tprintf("selected refusal %d/%d", position, positions),
		) {break}
	}
	fault.requests, fault.refuse = 0, 0
	testing.expect(t, rebuild(&r) && r.publication.ready && r.effects == 0)
	fmt.printf(
		"selected precommit positions=%d alloc=%d bytes=%d live=%d peak=%d\n",
		positions,
		tracking.total_allocation_count,
		tracking.total_memory_allocated,
		tracking.current_memory_allocated,
		tracking.peak_memory_allocated,
	)
	destroy(&r)
	testing.expect(t, tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
}
