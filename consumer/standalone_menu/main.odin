package main

import "core:fmt"
import "core:mem"
import "core:os"
import base "ui:ui_base"
import fonts "ui:ui_sdl_text"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

main :: proc() {if !run() {os.exit(1)}}
run :: proc() -> bool {
	o, valid := parse_options(os.args[1:])
	if !valid {fmt.eprintln("Usage: standalone_menu --font FILE [--locale ru|en] [--size 800x600|480x320] [--scale 1|1.5|2] [--window-check]"); return false}
	if !sdl.Init(
		{.VIDEO, .GAMEPAD},
	) {fmt.eprintln("SDL init:", sdl.GetError()); return false}; defer sdl.Quit()
	if !ttf.Init() {fmt.eprintln("TTF init:", sdl.GetError()); return false}; defer ttf.Quit()
	window := sdl.CreateWindow(
		"Standalone Menu",
		o.width,
		o.height,
		{.HIDDEN, .RESIZABLE, .HIGH_PIXEL_DENSITY},
	)
	if window ==
	   nil {fmt.eprintln("Window:", sdl.GetError()); return false}; defer sdl.DestroyWindow(window)
	renderer := sdl.CreateRenderer(window, nil)
	if renderer ==
	   nil {fmt.eprintln("Renderer:", sdl.GetError()); return false}; defer sdl.DestroyRenderer(renderer)
	tracking: mem.Tracking_Allocator
	mem.tracking_allocator_init(
		&tracking,
		context.allocator,
	); defer mem.tracking_allocator_destroy(&tracking)
	a := mem.tracking_allocator(&tracking)
	data, read := os.read_entire_file(o.font, context.allocator)
	if read != nil {fmt.eprintln("Font read:", o.font, read); return false}
	r: Runtime
	initialized := init(&r, renderer, data, o.scale, a); delete(data)
	if !initialized {fmt.eprintln("Font/resources init:", o.font, sdl.GetError()); return false}
	defer {
		destroy(&r)
		fmt.printf(
			"destroy allocations=%d bytes=%d live=%d peak=%d backend-resources=0 handlers=0\n",
			tracking.total_allocation_count,
			tracking.total_memory_allocated,
			tracking.current_memory_allocated,
			tracking.peak_memory_allocated,
		)
	}
	fmt.printf(
		"init allocations=%d bytes=%d live=%d peak=%d Runtime=%d Publication=%d Interaction=%d Reader=%d ImageGeneration=%d FontGeneration=%d fonts=%d images=0 handlers=0\n",
		tracking.total_allocation_count,
		tracking.total_memory_allocated,
		tracking.current_memory_allocated,
		tracking.peak_memory_allocated,
		size_of(Runtime),
		size_of(base.Publication),
		size_of(r.interaction),
		size_of(Reader),
		size_of(r.images^),
		size_of(r.fonts^),
		len(r.fonts.fonts),
	)
	metrics := fonts.metrics(r.fonts)
	for words in ([2]Strings{EN, RU}) {
		for value in ([8]string{words.main, words.submenu, words.action, words.open, words.language, words.back, words.counter, words.failed}) {
			error, offset := metrics.validate_text(value, "own", 16, metrics.user)
			if error !=
			   .None {fmt.eprintln("Font glyph validation:", error, offset, value); return false}
		}
	}
	r.model.locale = o.locale; r.input.window_id = sdl.GetWindowID(window)
	if !resize(&r) || !rebuild(&r) {fmt.eprintln("Initial prepare:", r.error); return false}
	log_state(&r, &tracking)
	if !sdl.ShowWindow(window) {fmt.eprintln("Show:", sdl.GetError()); return false}
	frames := 0
	for {
		event: sdl.Event
		for sdl.PollEvent(&event) {
			if event.type == .QUIT {return true}
			if event.type == .WINDOW_CLOSE_REQUESTED &&
			   event.window.windowID == r.input.window_id {return true}
			if event.type == .KEY_DOWN &&
			   event.key.windowID == r.input.window_id &&
			   !event.key.repeat {
				if event.key.key == sdl.K_R {rebuild(&r); log_state(&r, &tracking); continue}
				when TEST {
					if o.test_controls {
						if event.key.key == sdl.K_F12 {return true}
						if event.key.key == sdl.K_F10 {
							w, h := i32(480), i32(320); current: i32
							sdl.GetWindowSize(window, &current, nil)
							if current == 480 {w, h = 800, 600}
							if !sdl.SetWindowSize(window, w, h) {return false}; continue
						}
						if event.key.key >= sdl.K_F2 && event.key.key <= sdl.K_F8 {
							r.fault = Fault(u32(event.key.key - sdl.K_F2) + 1)
							fmt.printf("test next-fault=%v\n", r.fault); continue
						}
					}
				}
			}
			if (event.type == .WINDOW_PIXEL_SIZE_CHANGED || event.type == .WINDOW_RESIZED) &&
			   event.window.windowID == r.input.window_id {
				if !resize(&r) {base.invalidate(&r.publication); continue}
				if r.publication.ready {rebuild(&r)} 	// Resize never recovers an earlier failed update.
				log_state(&r, &tracking); continue
			}
			w, h: i32
			if !sdl.GetWindowSize(window, &w, &h) {return false}
			old_attempt := r.publication.attempt
			handle_input(&r, event, {f64(w), f64(h)})
			if old_attempt != r.publication.attempt {log_state(&r, &tracking)}
		}
		if r.publication.ready {
			if !present(
				&r,
			) {fmt.eprintln("Render/readback/present failed:", r.error, sdl.GetError(), "; press R to rebuild current model"); log_state(&r, &tracking); if o.window_check {return false}}
			frames += 1
		}
		if o.window_check && frames >= 4 {
			if !sdl.HideWindow(window) || !sdl.ShowWindow(window) {return false}
			fmt.println("window-check=ok render/readback/present"); return true
		}
		sdl.Delay(10)
	}
}
resize :: proc(r: ^Runtime) -> bool {
	w, h: i32
	if !sdl.GetRenderOutputSize(r.renderer, &w, &h) || w <= 0 || h <= 0 {return false}
	r.drawable = {f64(w), f64(h)}; return true
}
log_state :: proc(r: ^Runtime, tracking: ^mem.Tracking_Allocator) {
	fmt.printf(
		"state page=%v locale=%v count=%d effects=%d model=%d rebuilds=%d attempt=%d ready=%t focus=%s error=%v allocations=%d bytes=%d live=%d peak=%d\n",
		r.model.page,
		r.model.locale,
		r.model.count,
		r.model.effects,
		r.model.revision,
		r.rebuilds,
		r.publication.attempt,
		r.publication.ready,
		r.interaction.focus_id,
		r.error,
		tracking.total_allocation_count,
		tracking.total_memory_allocated,
		tracking.current_memory_allocated,
		tracking.peak_memory_allocated,
	)
}
