package app

import model "../model"
import "core:fmt"
import "core:mem"
import "core:os"
import backend "ui:ui_sdl"
import fonts "ui:ui_sdl_text"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

// Borrowed session exists only for the synchronous main-loop invocation. The
// ordinary loop has no service callback; optional entrypoints own their loop.
Session :: struct {
	shell:    ^Shell,
	tracking: ^mem.Tracking_Allocator,
	options:  Options,
}
Main_Loop :: #type proc(_: Session) -> bool
Tick_Result :: enum {
	Continue,
	Success,
	Failed,
}
test_resize_extent :: proc(page: model.Page, current: i32) -> (i32, i32) {
	if page == .Diagnostics_Performance {
		// Retain G21's inherited small-viewport resize fixture as well as its
		// separate readable 1280/1200 baseline pair.
		if current == 800 {return 960, 720}
		if current == 960 {return 800, 600}
	}
	// G18's assessment fixture needs room for seven full-size controls and C08.
	// Its tight-viewport refusal is checked separately; do not shrink its text.
	if page == .Accessibility || page == .World || page == .Diagnostics_Performance {
		if current == 1280 {return 1200, 900}
		return 1280, 960
	}
	if lab_menu(page) || page == .Lab_Hud || page == .Lab_Inventory {
		if current == 1280 {return 960, 720}
		return 1280, 960
	}
	if current == 800 {return 960, 720}
	return 800, 600
}
run :: proc(args: []string, main_loop: Main_Loop = ordinary_loop) -> bool {
	o, valid := parse_options(args)
	if !valid {
		fmt.eprintln(
			"Usage: ui_showcase --font FILE [--fallback-font FILE] [--assets MANIFEST --alternate-assets MANIFEST] [--section catalogue|FROZEN_ID] [--locale ru|en] [--size WIDTHxHEIGHT] [--scale 1|1.5|2] [--pixel-perfect]; duplicate/unknown options and fractional Pixel_Perfect are errors",
		)
		for section in model.SECTIONS {fmt.eprintf("%s [%s] %s\n", section.id, section.status, section.limitations)}
		for section in model.LAB_SECTIONS {fmt.eprintf("%s [Lab] %s\n", section.id, section.limitations)}
		return false
	}
	data, read := os.read_entire_file(o.font, context.allocator)
	if read != nil {fmt.eprintln("Font read:", o.font, read); return false}; defer delete(data)
	fallback: []u8
	if o.fallback_font !=
	   "" {bytes, e := os.read_entire_file(o.fallback_font, context.allocator); if e != nil {fmt.eprintln("Fallback font read:", o.fallback_font, e); return false}; fallback = bytes}
	defer delete(fallback)
	if !sdl.Init(
		{.VIDEO, .GAMEPAD},
	) {fmt.eprintln("SDL init:", sdl.GetError()); return false}; defer sdl.Quit()
	if !ttf.Init() {fmt.eprintln("TTF init:", sdl.GetError()); return false}; defer ttf.Quit()
	window := sdl.CreateWindow(
		"UI Showcase",
		o.width,
		o.height,
		{.HIDDEN, .RESIZABLE, .HIGH_PIXEL_DENSITY},
	)
	if window ==
	   nil {fmt.eprintln("Window:", sdl.GetError()); return false}; defer sdl.DestroyWindow(window)
	renderer := sdl.CreateRenderer(window, nil)
	if renderer ==
	   nil {fmt.eprintln("Renderer:", sdl.GetError()); return false}; defer sdl.DestroyRenderer(renderer)
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	ledger: backend.Resource_Ledger
	s := Shell {
		model = model.initial(),
		renderer = renderer,
		window = window,
		font_data = data,
		allocator = mem.tracking_allocator(&tracking),
		ledger = &ledger,
		sources = {fallback = fallback, assets = o.assets, alternate_assets = o.alternate_assets},
	}
	s.model.page, s.model.locale, s.model.scale, s.model.pixel_perfect =
		o.page, o.locale, o.scale, o.pixel_perfect
	s.input.window_id = sdl.GetWindowID(window)
	defer {
		destroy_shell(&s)
		fmt.printf(
			"destroy live=%d bad-frees=%d native-live=%d acquired=%d released=%d peak=%d\n",
			tracking.current_memory_allocated,
			len(tracking.bad_free_array),
			ledger.live,
			ledger.created,
			ledger.destroyed,
			ledger.peak,
		)
	}
	if !resize(&s) ||
	   !enter(
			   &s,
		   ) {fmt.eprintln("Initial page/font/resource prepare:", s.runtime.error, o.font, sdl.GetError()); return false}
	// Validate both languages and all values before exposing any input.
	metrics := fonts.metrics(s.runtime.fonts)
	for locale in model.Locale {for page in model.Page {
			m := s.model; m.locale, m.page = locale, page
			c: Page_Composition; defer destroy_composition(&c)
			if !compose_page(
				&c,
				m,
				s.allocator,
				table_metrics = metrics,
				table_width = s.drawable.w / s.model.scale,
			) {fmt.eprintln("Font validation composition allocation"); return false}
			for b in c.texts[:c.nt] {
				e, offset := metrics.validate_text(b.text, "own", 14, metrics.user)
				if e !=
				   .None {fmt.eprintln("Font glyph validation:", e, offset, b.text); return false}
			}
		}}
	if !sdl.ShowWindow(window) {fmt.eprintln("Show:", sdl.GetError()); return false}
	log_state(&s, &tracking)
	return main_loop({&s, &tracking, o})
}
ordinary_loop :: proc(session: Session) -> bool {
	for {switch host_tick(session) {case .Success:
			return true; case .Failed:
			return false; case .Continue:
			sdl.Delay(10)}}
}
host_tick :: proc(session: Session) -> Tick_Result {
	s := session.shell; tracking := session.tracking; o := session.options; window := s.window
	_ = o
	event: sdl.Event
	for sdl.PollEvent(&event) {
		if event.type == .QUIT ||
		   (event.type == .WINDOW_CLOSE_REQUESTED && event.window.windowID == s.input.window_id) {
			if request_exit(s) {return .Success}
			fmt.eprintln(
				"Text input close failed; R explicitly retries shutdown",
			); log_state(s, tracking); continue
		}
		// SDL can change output before its queued resize notification, with pointer
		// events interleaved. Rebuild a previously ready page before those actions.
		// A pre-existing failure remains blocked; this is not arbitrary-input recovery.
		if !refresh_drawable(s) {log_state(s, tracking)}
		if event.type == .KEY_DOWN &&
		   event.key.windowID == s.input.window_id &&
		   !event.key.repeat {
			if recovery_key(event) {
				if s.exit_pending {if request_exit(s) {return .Success}} else {recover(s)}
				log_state(s, tracking); continue
			}
			when TEST {if o.test_controls {
					if event.key.key ==
					   sdl.K_F12 {if request_exit(s) {return .Success}; log_state(s, tracking); continue}
					if event.key.key == sdl.K_F10 {
						current: i32; sdl.GetWindowSize(window, &current, nil)
						w, h := test_resize_extent(s.model.page, current)
						if !sdl.SetWindowSize(
							window,
							w,
							h,
						) {fmt.eprintln("Resize:", sdl.GetError()); return .Failed}; continue
					}
					if event.key.key >= sdl.K_F1 && event.key.key <= sdl.K_F8 {
						if event.key.key ==
						   sdl.K_F1 {s.fail_entry = true} else {s.runtime.fault = Fault(u32(event.key.key - sdl.K_F1) + 1)}
						continue
					}
				}}
		}
		if (event.type == .WINDOW_PIXEL_SIZE_CHANGED || event.type == .WINDOW_RESIZED) &&
		   event.window.windowID == s.input.window_id {
			log_state(s, tracking); continue
		}
		w, h: i32; if !sdl.GetWindowSize(window, &w, &h) {fmt.eprintln("Window size:", sdl.GetError()); return .Failed}
		old := s.runtime.publication.attempt; before := s.model.revision
		handle_input(s, event, {f64(w), f64(h)})
		if old != s.runtime.publication.attempt ||
		   before != s.model.revision {log_state(s, tracking)}
	}
	clock_attempt := s.runtime.publication.attempt
	if s.runtime.publication.ready &&
	   !step_session_clock(
			   session,
			   i64(sdl.GetTicks()),
		   ) {fmt.eprintln("Clock/publication failure")}
	if s.runtime.publication.attempt != clock_attempt {log_state(s, tracking)}
	if s.runtime.publication.ready &&
	   !present(
			   &s.runtime,
		   ) {fmt.eprintln("Render/readback/present failed:", s.runtime.error, sdl.GetError(), "; R retries accepted model without replay"); log_state(s, tracking)}
	return .Continue
}
resize :: proc(s: ^Shell) -> bool {
	w, h: i32
	if !sdl.GetRenderOutputSize(s.renderer, &w, &h) ||
	   w <= 0 ||
	   h <= 0 {fmt.eprintln("Drawable size:", sdl.GetError()); return false}
	s.drawable = {f64(w), f64(h)}; s.runtime.drawable = s.drawable; return true
}
recovery_key :: proc(event: sdl.Event) -> bool {return(
		event.key.key == sdl.K_R ||
		event.key.scancode == .R \
	)}
refresh_drawable :: proc(s: ^Shell) -> bool {
	previous := s.drawable; ready := s.runtime.publication.ready
	if !resize(s) {if s.runtime.model != nil {block(&s.runtime)}; return false}
	if previous != s.drawable && ready {return rebuild(&s.runtime) && sync_name(s)}
	return true
}
log_state :: proc(s: ^Shell, tracking: ^mem.Tracking_Allocator) {
	log_interaction(s)
	log_lab(s)
	fmt.printf(
		"state page=%v locale=%v scale=%g pixel=%t checkbox=%t toggle=%t slider=%d effects=%d revision=%d attempt=%d ready=%t focus=%s error=%v live=%d peak=%d native=%d\n",
		s.model.page,
		s.model.locale,
		s.model.scale,
		s.model.pixel_perfect,
		s.model.checkbox,
		s.model.toggle,
		s.model.slider,
		s.model.effects,
		s.model.revision,
		s.runtime.publication.attempt,
		s.runtime.publication.ready,
		s.runtime.interaction.focus_id,
		s.runtime.error,
		tracking.current_memory_allocated,
		tracking.peak_memory_allocated,
		s.ledger.live,
	)
	fmt.printf(
		"gallery profile=%s dialog=%v draft_help=%t applied_help=%t draft_mode=%s atlas_count=%d atlas_dark=%t atlas_B=%t text_short=%t text_case=%d rich_limit=%t\n",
		s.model.profiles.selected_id,
		s.model.profiles.dialog,
		s.model.profiles.draft.show_help,
		s.model.profiles.applied[0].show_help,
		s.model.profiles.draft.mode,
		s.model.atlas.count,
		s.model.atlas.dark,
		s.model.atlas.alternate,
		s.model.text.short,
		s.model.text.limit_fixture,
		s.model.rich.ellipsis,
	)
}
