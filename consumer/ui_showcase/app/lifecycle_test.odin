package app

import model "../model"
import "core:mem"
import "core:os"
import "core:testing"
import interaction "ui:ui_interaction"
import backend "ui:ui_sdl"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

@(test)
cold_sections_no_retained_history_or_old_sequence :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	surface := sdl.CreateSurface(
		800,
		600,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
	data, e := os.read_entire_file(
		"resources/font.ttf",
		context.allocator,
	); if !testing.expect(t, e == nil) {return}; defer delete(data)
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	ledger: backend.Resource_Ledger
	s := Shell {
		model     = model.initial(),
		font_data = data,
		renderer  = renderer,
		allocator = mem.tracking_allocator(&tracking),
		drawable  = {800, 600},
		ledger    = &ledger,
	}
	if !testing.expect(t, enter(&s)) {return}; defer destroy_shell(&s)
	baseline := tracking.current_memory_allocated
	initial_revision_bytes := len(s.runtime.fonts.fonts[0].revision)
	for _ in 0 ..< 64 {
		for id in ([]string{"shell/layout", "shell/controls", "shell/catalogue"}) {testing.expect(t, dispatch(&s, {.Activate, id, .Agent, false}))}
		// Native font pointer/generation text can change length, without retaining history.
		// One font revision string and one copy per current text block are intentional.
		revision_delta := len(s.runtime.fonts.fonts[0].revision) - initial_revision_bytes
		expected := baseline + i64(revision_delta * (1 + len(s.runtime.live.text.text_blocks)))
		testing.expect(t, ledger.live == 1 && tracking.current_memory_allocated == expected)
	}
	testing.expect(t, s.model.effects == 192 && s.runtime.interaction.focus_id == "shell/layout")
	reader, ok := copy_reader(
		&s.runtime.live,
		s.allocator,
	); if !testing.expect(t, ok) {return}; defer destroy_reader(&reader)
	stamp := reader.text.stamp
	testing.expect(
		t,
		dispatch(&s, {.Activate, "shell/controls", .Agent, false}) && ledger.live == 2,
	)
	count := s.model.effects
	event := interaction.Button_Activated {
		id       = "shell/language",
		source   = .Agent,
		sequence = 1,
	}
	testing.expect(t, !accept_base(&s.runtime, stamp, event) && s.model.effects == count)
	destroy_reader(&reader); testing.expect(t, ledger.live == 1)
	destroy_shell(&s)
	testing.expect(
		t,
		ledger.live == 0 &&
		ledger.created == ledger.destroyed &&
		tracking.current_memory_allocated == 0 &&
		len(tracking.bad_free_array) == 0,
	)
}
