package main

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import backend "ui:ui_sdl"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

// Software PNGs are deterministic renderer evidence, NOT display/ISD snapshots.
// The caller provides an existing output directory and explicit licensed font.
software_render_main :: proc(font_path, output_directory: string) -> bool {
	if !ttf.Init() {return false}; defer ttf.Quit()
	surface := sdl.CreateSurface(
		400,
		300,
		.RGBA32,
	); if surface == nil {return false}; defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(
		surface,
	); if renderer == nil {return false}; defer sdl.DestroyRenderer(renderer)
	data, error := os.read_entire_file(
		font_path,
		context.allocator,
	); if error != nil {fmt.eprintf("font read failed: %s\n", font_path); return false}; defer delete(data)
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	previous :=
		context.allocator; context.allocator = mem.tracking_allocator(&tracking); defer {context.allocator = previous}
	font_ledger, image_ledger: backend.Resource_Ledger
	r: Runtime; init(&r); defer destroy(&r)
	r.render = {
		renderer       = renderer,
		font_data      = data,
		font_revision  = "font-1",
		image_revision = "image-1",
		font_ledger    = &font_ledger,
		image_ledger   = &image_ledger,
	}
	for state in 0 ..< 3 {for ru in ([]bool{false, true}) {
			r.modal = state == 2; r.popup = state == 1; r.render.russian = ru
			if !publish(&r) {fmt.eprintf("software render prepare failed\n"); return false}
			png, ok := readback_current(&r); if !ok {return false}
			lang := "en"; if ru {lang = "ru"}; names := [3]string{"base", "popup", "modal"}; name := names[state]
			path := fmt.aprintf("%s/%s-%s.png", output_directory, lang, name)
			cpath, ce := strings.clone_to_cstring(path); delete(path)
			if ce != nil {sdl.DestroySurface(png); return false}
			saved := sdl.SavePNG(
				png,
				cpath,
			); delete(cpath); sdl.DestroySurface(png); if !saved {return false}
		}}
	live := tracking.current_memory_allocated
	for _ in 0 ..< 64 {if !publish(&r) || !render_current(&r) || tracking.current_memory_allocated != live {return false}}
	fmt.printf(
		"selected-render Runtime=%d Reader=%d allocations=%d bytes=%d live=%d peak=%d fonts=%d/%d/%d images=%d/%d/%d\n",
		size_of(Runtime),
		size_of(Reader),
		tracking.total_allocation_count,
		tracking.total_memory_allocated,
		tracking.current_memory_allocated,
		tracking.peak_memory_allocated,
		font_ledger.created,
		font_ledger.destroyed,
		font_ledger.live,
		image_ledger.created,
		image_ledger.destroyed,
		image_ledger.live,
	)
	saved := r.reader; r.reader = {}; destroy(&r)
	if font_ledger.live != 1 ||
	   image_ledger.live != 1 ||
	   saved.render.text.text_blocks[0].node_id == "" {destroy_reader(&saved); return false}
	destroy_reader(&saved)
	fmt.printf(
		"destroy live=%d bad-frees=%d fonts=%d/%d images=%d/%d\n",
		tracking.current_memory_allocated,
		len(tracking.bad_free_array),
		font_ledger.created,
		font_ledger.destroyed,
		image_ledger.created,
		image_ledger.destroyed,
	)
	return(
		tracking.current_memory_allocated == 0 &&
		len(tracking.bad_free_array) == 0 &&
		font_ledger.live == 0 &&
		image_ledger.live == 0 \
	)
}
