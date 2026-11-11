package main
import "core:fmt"
import "core:mem"
import "core:os"
import base "ui:ui_base"
import editor_sdl "ui:ui_editor/sdl"
import gesture_sdl "ui:ui_gestures/sdl"
import fonts "ui:ui_sdl_text"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

TEST :: #config(STANDALONE_MENU_TEST, false)
Options :: struct {
	font:                     string,
	width, height:            i32,
	scale:                    f64,
	english, check, controls: bool,
}
options :: proc(args: []string) -> (Options, bool) {
	o := Options {
		width  = 800,
		height = 600,
		scale  = 1,
	}
	for j := 0; j < len(args); j += 1 {
		key := args[j]
		if key == "--window-check" {o.check = true; continue}
		if key ==
		   "--test-controls" {when TEST {o.controls = true; continue} else {return {}, false}}
		if j + 1 >= len(args) {return {}, false}; j += 1; value := args[j]
		switch key {
		case "--font":
			o.font = value
		case "--locale":
			if value == "en" {o.english = true} else if value != "ru" {return {}, false}
		case "--size":
			if value ==
			   "480x320" {o.width, o.height = 480, 320} else if value != "800x600" {return {}, false}
		case "--scale":
			switch value {case "1":
				o.scale = 1; case "1.5":
				o.scale = 1.5; case "2":
				o.scale = 2; case:
				return {}, false}
		case:
			return {}, false
		}
	}
	return o, o.font != ""
}
main :: proc() {if !run() {os.exit(1)}}
run :: proc() -> (ok: bool) {
	o, valid := options(
		os.args[1:],
	); if !valid {fmt.eprintln("selected editing consumer: --font FILE [--locale ru|en] [--size 800x600|480x320] [--scale 1|1.5|2] [--window-check]"); return false}
	if !sdl.Init(
		{.VIDEO, .GAMEPAD},
	) {fmt.eprintln("SDL init:", sdl.GetError()); return false}; defer sdl.Quit()
	if !ttf.Init() {fmt.eprintln("TTF init:", sdl.GetError()); return false}; defer ttf.Quit()
	// Harness title matches the existing ISD external-consumer profile; this is
	// an editing/gesture fixture, not a new standalone-menu acceptance claim.
	window := sdl.CreateWindow(
		"Standalone Menu",
		o.width,
		o.height,
		{.HIDDEN, .RESIZABLE, .HIGH_PIXEL_DENSITY},
	)
	if window ==
	   nil {fmt.eprintln("Window:", sdl.GetError()); return false}; defer sdl.DestroyWindow(window)
	renderer := sdl.CreateRenderer(
		window,
		nil,
	); if renderer == nil {fmt.eprintln("Renderer:", sdl.GetError()); return false}; defer sdl.DestroyRenderer(renderer)
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	tracking.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	a := mem.tracking_allocator(&tracking)
	data, de := os.read_entire_file(
		o.font,
		context.allocator,
	); if de != nil {fmt.eprintln("Font read:", o.font, de); return false}; defer delete(data)
	g, ge := fonts.create_generation(
		renderer,
		"selected-font-v1",
		[]fonts.Font_Source{{"font", 16, data}},
		o.scale,
		a,
	)
	if ge.code !=
	   .None {fmt.eprintln("Font generation:", ge, sdl.GetError()); return false}; defer fonts.release_generation(&g)
	w, h: i32
	if !sdl.GetRenderOutputSize(renderer, &w, &h) {return false}
	r: Runtime; if !init(&r, g, {f64(w), f64(h)}, a) {return false}
	defer {
		closed := editor_sdl.close(&r.editor_input, window)
		destroy(&r); fonts.release_generation(&g)
		fmt.printf(
			"destroy live=%d peak=%d allocations=%d bytes=%d bad-frees=%d\n",
			tracking.current_memory_allocated,
			tracking.peak_memory_allocated,
			tracking.total_allocation_count,
			tracking.total_memory_allocated,
			len(tracking.bad_free_array),
		)
		if !closed ||
		   tracking.current_memory_allocated != 0 ||
		   len(tracking.bad_free_array) != 0 {ok = false}
	}
	r.english, r.input.window_id = o.english, sdl.GetWindowID(window)
	if !rebuild(&r) {fmt.eprintln("Initial preparation refused"); return false}
	fmt.printf(
		"owners Publication=%d Interaction=%d Editor=%d Gestures=%d Scroll=%d Reader=%d Input=%d EditorAdapter=%d GestureAdapter=%d\n",
		size_of(base.Publication),
		size_of(r.interaction),
		size_of(r.editing),
		size_of(r.gestures),
		size_of(r.scroll),
		size_of(Reader),
		size_of(r.input),
		size_of(r.editor_input),
		size_of(r.gesture_input),
	)
	if !sdl.ShowWindow(window) {return false}
	frames := 0
	for {
		e: sdl.Event
		for sdl.PollEvent(&e) {
			if e.type == .QUIT ||
			   (e.type == .WINDOW_CLOSE_REQUESTED &&
					   e.window.windowID == r.input.window_id) {return true}
			if e.type == .KEY_DOWN && e.key.windowID == r.input.window_id && !e.key.repeat {
				if e.key.key == sdl.K_R {rebuild(&r); log_state(&r); continue}
				when TEST {if o.controls {
						if e.key.key == sdl.K_F12 {return true}
						if e.key.key == sdl.K_F2 {r.fail_next = true; continue}
						if e.key.key ==
						   sdl.K_F10 {nw, nh := i32(480), i32(320); if o.width == 480 {nw, nh = 800, 600}; o.width, o.height = nw, nh; if !sdl.SetWindowSize(window, nw, nh) {return false}; continue}
					}}
			}
			if (e.type == .WINDOW_PIXEL_SIZE_CHANGED || e.type == .WINDOW_RESIZED) &&
			   e.window.windowID == r.input.window_id {
				if !sdl.GetRenderOutputSize(
					renderer,
					&w,
					&h,
				) {return false}; r.drawable = {f64(w), f64(h)}
				if r.publication.ready {rebuild(&r)}
				continue
			}
			if !sdl.GetWindowSize(window, &w, &h) {return false}
			before := r.effects
			handle(&r, e, {f64(w), f64(h)})
			if r.effects != before {log_state(&r)}
		}
		if r.publication.ready {
			x := gesture_sdl.step(
				&r.gesture_input,
				&r.input,
				&r.interaction,
				&r.gestures,
				&r.scroll,
				i64(sdl.GetTicks()),
			)
			if x.has_gesture {if !accept_gesture(&r, x.gesture) {return false}; if !r.publication.ready {rebuild(&r)}}
		}
		if !editor_sdl.sync(
			&r.editor_input,
			&r.input,
			&r.interaction,
			&r.editing,
			window,
		) {block_runtime(&r); fmt.eprintln("Text lifecycle failed:", sdl.GetError())}
		if r.publication.ready {
			if !render_current(
				&r,
			) {base.invalidate(&r.publication); fmt.eprintln("Render refused:", sdl.GetError()); if o.check {return false}; continue}
			if o.check {pixels := sdl.RenderReadPixels(renderer, nil); if pixels == nil {return false}; sdl.DestroySurface(pixels)}
			if !sdl.RenderPresent(renderer) {return false}; frames += 1
		}
		if o.check &&
		   frames >= 4 {fmt.println("window-check=ok render/readback/present"); return true}
		sdl.Delay(10)
	}
}
log_state :: proc(r: ^Runtime) {fmt.printf(
		"selected ready=%t effects=%d revision=%d value_revision=%d sequence=%d value=%s dropped=%t locale-en=%t\n",
		r.publication.ready,
		r.effects,
		r.revision,
		r.value_revision,
		r.publication.sequence,
		r.value,
		r.dropped,
		r.english,
	)}
