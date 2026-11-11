package app

import model "../model"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"
import interaction "ui:ui_interaction"
import sdl "vendor:sdl3"

@(test)
all_nineteen_pages_share_lifecycle_failure_recovery_and_owning_readers :: proc(t: ^testing.T) {
	fallback, e := os.read_entire_file("resources/fallback.ttf", context.allocator)
	if !testing.expect(t, e == nil) {return}; defer delete(fallback)
	for locale in model.Locale {for section in model.SECTIONS {
			f: Page_Fixture
			if !start_page_fixture(
				t,
				&f,
				section.page,
				fallback = fallback,
				locale = locale,
				assets = "resources/atlas/a/manifest.json",
				alternate_assets = "resources/atlas/b/manifest.json",
			) {stop_page_fixture(&f); return}
			s := &f.s; r := &s.runtime
			initial, ie := strings.clone(
				r.interaction.focus_id,
				context.allocator,
			); if !testing.expect(t, ie == nil) {stop_page_fixture(&f); return}; defer delete(initial)
			testing.expect(t, initial != "" && current(r) && present(r))
			for fault in ([]Fault{.Prepare, .Resource, .Copy, .Publish, .Render, .Readback, .Present}) {
				before := s.model.effects
				r.fault = fault
				failed := !rebuild(r)
				if fault == .Render ||
				   fault == .Readback ||
				   fault == .Present {failed = !present(r)}
				testing.expect(t, failed && !current(r) && s.model.effects == before, section.id)
				lifecycle_key_edge(s, sdl.K_TAB, true); lifecycle_key_edge(s, sdl.K_TAB, false)
				testing.expect(
					t,
					!current(r) && s.model.effects == before,
					"ordinary input cannot recover or replay",
				)
				testing.expect(t, recover(s) && present(r) && s.model.effects == before)
			}
			old, copied := copy_reader(&r.live, s.allocator)
			if !testing.expect(t, copied) {stop_page_fixture(&f); return}
			stamp := reader_stamp(&old)
			testing.expect(t, dispatch(s, {.Focus, "shell/language", .Agent, false}))
			lifecycle_key_edge(s, sdl.K_RETURN, true)
			if !lifecycle_return(
				t,
				s,
				section.id,
				initial,
			) {destroy_reader(&old); stop_page_fixture(&f); return}
			before := s.model.effects
			testing.expect(t, r.interaction.pressed_id == "" && r.adapter.capture_id == "")
			testing.expect(
				t,
				!accept_base(
					r,
					stamp,
					interaction.Button_Activated {
						id = "shell/language",
						sequence = 1,
						source = .Agent,
					},
				),
			)
			lifecycle_key_edge(s, sdl.K_RETURN, false)
			testing.expect(
				t,
				s.model.effects == before && draw_reader(&old),
				"historical owning reader is readable but cannot act",
			)
			destroy_reader(&old)
			fmt.printf(
				"Integrated page=%s locale=%v faults=7 cold-focus=%s historical-reader=pass revision=%d effects=%d\n",
				section.id,
				locale,
				initial,
				s.model.revision,
				s.model.effects,
			)
			stop_page_fixture(&f)
		}}
}
