package main

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:testing"
import base "ui:ui_base"
import backend "ui:ui_sdl"
import fonts "ui:ui_sdl_text"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

Allocator_Fault :: struct {
	backing:          mem.Allocator,
	requests, refuse: int,
}
fail_allocation :: proc(
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
	f := (^Allocator_Fault)(data)
	if size > 0 &&
	   (mode == .Alloc ||
			   mode == .Alloc_Non_Zeroed ||
			   mode == .Resize ||
			   mode == .Resize_Non_Zeroed) {
		f.requests += 1; if f.requests == f.refuse {return nil, .Out_Of_Memory}
	}
	return f.backing.procedure(f.backing.data, mode, size, alignment, old, old_size, loc)
}
Allocation_Operation :: enum {
	Init,
	Rebuild,
	Reader,
	Scale,
	Image,
	Font,
}
exercise_allocation :: proc(
	t: ^testing.T,
	op: Allocation_Operation,
	refuse: int,
	renderer: ^sdl.Renderer,
	data: []u8,
) -> int {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	a := mem.tracking_allocator(&tracking)
	fault := Allocator_Fault {
		backing = a,
		refuse  = refuse,
	}
	fa := mem.Allocator{fail_allocation, &fault}
	r: Runtime
	ledger: backend.Resource_Ledger
	ok := false
	if op == .Init {
		ok = init(&r, renderer, data, 1, fa); destroy(&r)
	} else if op == .Image {
		pixels := [4]u8 {
			255,
			0,
			0,
			255,
		}; images := [2]backend.RGBA_Image{{"owned", 1, 1, pixels[:]}, {"second", 1, 1, pixels[:]}}
		g, e := backend.create_generation(renderer, "fixture", images[:], fa, &ledger)
		ok = e.code == .None
		if !ok {testing.expect(t, e.code == .Allocation && g == nil)}
		backend.release_generation(&g)
	} else if op == .Font {
		sources := [2]fonts.Font_Source{{"owned", 16, data}, {"second", 16, data}}
		g, e := fonts.create_generation(renderer, "fixture", sources[:], 1, fa, &ledger)
		ok = e.code == .None
		if !ok {testing.expect(t, e.code == .Allocation && g == nil)}
		fonts.release_generation(&g)
	} else {
		if !testing.expect(t, init(&r, renderer, data, 1, a)) {return 0}
		r.drawable = {480, 320}; if !testing.expect(t, rebuild(&r)) {destroy(&r); return 0}
		before := tracking.current_memory_allocated
		stamp := r.live.text.stamp
		r.allocator = fa
		if op == .Reader {
			reader, copied := copy_reader(&r.live, fa); ok = copied; destroy_reader(&reader)
			if !ok {testing.expect(t, base.is_current(&r.publication, stamp))}
		} else {
			if op == .Scale {r.scale = 1.5}
			ok = rebuild(&r)
			if !ok {testing.expect(t, !r.publication.ready && r.live.text.stamp == stamp && r.model.effects == 0)}
		}
		if !ok {testing.expect(t, tracking.current_memory_allocated == before)}
		destroy(&r)
	}
	testing.expect(t, ok == (refuse == 0))
	testing.expect(t, ledger.live == 0 && ledger.created == ledger.destroyed)
	testing.expect(t, tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
	return fault.requests
}
@(test)
every_owning_allocation_refusal :: proc(t: ^testing.T) {
	testing.expect(t, ttf.Init()); defer ttf.Quit()
	surface := sdl.CreateSurface(
		480,
		320,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
	data, e := os.read_entire_file(
		"resources/font.ttf",
		context.allocator,
	); if !testing.expect(t, e == nil) {return}; defer delete(data)
	for op in Allocation_Operation {
		requests := exercise_allocation(t, op, 0, renderer, data)
		testing.expect(t, requests > 0)
		for refusal in 1 ..= requests {exercise_allocation(t, op, refusal, renderer, data)}
		fmt.printf("allocation-refusal operation=%v positions=%d\n", op, requests)
	}
	ledger: backend.Resource_Ledger
	invalid := [3]u8{1, 2, 3}
	sources := [2]fonts.Font_Source{{"valid", 16, data}, {"bad", 16, invalid[:]}}
	g, error := fonts.create_generation(
		renderer,
		"partial-failure",
		sources[:],
		1,
		context.allocator,
		&ledger,
	)
	testing.expect(t, g == nil && error.code == .Resource && error.id == "bad")
	testing.expect(t, ledger.created == 1 && ledger.destroyed == 1 && ledger.live == 0)
	pixels := [4]u8{255, 0, 0, 255}
	images := [2]backend.RGBA_Image{{"valid", 1, 1, pixels[:]}, {"bad", 2, 1, pixels[:]}}
	ig, ie := backend.create_generation(
		renderer,
		"partial-failure",
		images[:],
		context.allocator,
		&ledger,
	)
	testing.expect(t, ig == nil && ie.code == .Invalid && ie.id == "bad")
	testing.expect(t, ledger.created == 2 && ledger.destroyed == 2 && ledger.live == 0)
}
