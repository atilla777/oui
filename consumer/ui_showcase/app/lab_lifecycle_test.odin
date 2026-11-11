package app

import model "../model"
import "core:os"
import "core:testing"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

@(test)
lab_every_backing_entry_rebuild_reader_allocation :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	surface := sdl.CreateSurface(1280, 960, .RGBA32)
	if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(surface)
	if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
	font, error := os.read_entire_file("resources/font.ttf", context.allocator)
	if !testing.expect(t, error == nil) {return}; defer delete(font)
	for page in ([4]model.Page{.Lab_Menu, .Lab_Settings, .Lab_Hud, .Lab_Inventory}) {
		for boundary in ([3]Interaction_Boundary{.Entry, .Rebuild, .Copy}) {
			requests := exercise_interaction_boundary(t, renderer, font, page, boundary, 0)
			for refusal in 1 ..= requests {exercise_interaction_boundary(t, renderer, font, page, boundary, refusal)}
		}
	}
}

@(test)
lab_hold_threshold_release_loss_and_no_replay :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Hud) {return}
	s := &f.s
	e: sdl.Event; e.key = {
		type     = .KEY_DOWN,
		windowID = 17,
		key      = sdl.K_SPACE,
	}
	testing.expect(t, handle_input(s, e, {1280, 960}))
	testing.expect(t, advance_page_clock(s, 0) && advance_page_clock(s, 999))
	testing.expect(t, s.model.lab_hp == 60 && s.model.lab_hold_count == 0)
	e.key.type = .KEY_UP; handle_input(s, e, {1280, 960})
	advance_page_clock(s, 1000)
	testing.expect(t, s.model.lab_hold_count == 0)
	e.key.type = .KEY_DOWN; handle_input(s, e, {1280, 960})
	advance_page_clock(s, 2000); advance_page_clock(s, 2999)
	testing.expect(t, s.model.lab_hold_count == 0)
	advance_page_clock(s, 3000)
	testing.expect(t, s.model.lab_hp == 100 && s.model.lab_hold_count == 1)
	advance_page_clock(s, 5000); recover(s)
	testing.expect(t, s.model.lab_hold_count == 1)
	e.key.type = .KEY_UP; handle_input(s, e, {1280, 960})
	e.key.type = .KEY_DOWN; handle_input(s, e, {1280, 960})
	advance_page_clock(s, 6000); advance_page_clock(s, 6999)
	loss: sdl.Event; loss.window = {
		type     = .WINDOW_FOCUS_LOST,
		windowID = 17,
	}; handle_input(s, loss, {1280, 960})
	advance_page_clock(s, 7000)
	testing.expect(t, s.model.lab_hold_count == 1)
}

@(test)
lab_failure_recovery_and_historical_readers :: proc(t: ^testing.T) {
	for page in ([4]model.Page{.Lab_Menu, .Lab_Settings, .Lab_Hud, .Lab_Inventory}) {
		f: Page_Fixture; defer stop_page_fixture(&f)
		if !start_page_fixture(t, &f, page) {return}
		s := &f.s
		for fault in ([4]Fault{.Prepare, .Resource, .Copy, .Publish}) {
			stamp := reader_stamp(&s.runtime.live); effects := s.model.effects
			s.runtime.fault = fault
			testing.expect(t, !rebuild(&s.runtime) && !s.runtime.publication.ready)
			testing.expect(t, reader_stamp(&s.runtime.live) == stamp)
			dispatch(s, {.Activate, "shell/catalogue", .Agent, false})
			testing.expect(t, s.model.page == page && s.model.effects == effects)
			testing.expect(t, recover(s) && current(&s.runtime) && s.model.effects == effects)
		}
		for fault in ([3]Fault{.Render, .Readback, .Present}) {
			s.runtime.fault = fault
			testing.expect(t, !present(&s.runtime) && !s.runtime.publication.ready)
			testing.expect(t, recover(s) && current(&s.runtime))
		}
		retained, copied := copy_reader(&s.runtime.live, context.allocator)
		if !testing.expect(t, copied) {return}
		destroy(&s.runtime)
		testing.expect(
			t,
			draw_reader(&retained),
			"Historical owning reader stays readable after runtime destroy",
		)
		testing.expect(t, !reader_stamp(&retained).lifetime.alive)
		destroy_reader(&retained)
	}
}

@(test)
lab_inventory_current_requires_all_family_stamps :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Inventory) {return}
	r := &f.s.runtime; v, _ := r.content.(^Lab_Inventory_Runtime)
	stamp := v.gesture.frame.stamp
	v.gesture.frame.stamp.attempt += 1
	testing.expect(
		t,
		!current(r),
		"Current requires the live gesture owner, not just its reader copy",
	)
	v.gesture.frame.stamp = stamp
	v.states[1].frame.stamp.attempt += 1
	testing.expect(t, !current(r), "Both collection owners participate in currentness")
	v.states[1].frame.stamp = stamp
}

@(test)
lab_scale_and_locale_current_bundles :: proc(t: ^testing.T) {
	for page in ([4]model.Page{.Lab_Menu, .Lab_Settings, .Lab_Hud, .Lab_Inventory}) {
		for locale in model.Locale {
			f: Page_Fixture; defer stop_page_fixture(&f)
			if !start_page_fixture(t, &f, page, locale = locale) {return}
			for scale in ([4]f64{1.5, 2, 1, 2}) {
				f.s.model.scale = scale; f.s.model.pixel_perfect = scale == 2
				f.s.model.revision += 1
				testing.expect(
					t,
					rebuild(&f.s.runtime) && current(&f.s.runtime) && present(&f.s.runtime),
				)
			}
		}
	}
}
