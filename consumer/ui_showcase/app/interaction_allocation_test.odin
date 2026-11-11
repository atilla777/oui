package app

import collection_model "../../virtualized_collections_demo/model"
import model "../model"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:testing"
import backend "ui:ui_sdl"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

Interaction_Boundary :: enum {
	Entry,
	Rebuild,
	Copy,
	Edit,
}
exercise_interaction_boundary :: proc(
	t: ^testing.T,
	renderer: ^sdl.Renderer,
	font: []u8,
	page: model.Page,
	boundary: Interaction_Boundary,
	refusal: int,
) -> int {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	a := mem.tracking_allocator(&tracking); fault := Allocation_Fault {
		backing = a,
	}
	ledger: backend.Resource_Ledger
	s := Shell {
		model     = model.initial(),
		renderer  = renderer,
		font_data = font,
		allocator = {refuse_allocation, &fault},
		drawable  = {1280, 960},
		ledger    = &ledger,
	}
	s.model.page = page; s.input.window_id = 17
	// Three identities exercise every consumer/library backing boundary cheaply;
	// the independent G11 tests retain the actual 10,000-item happy-path fixture.
	if page == .Collections {s.collection = collection_model.create(); s.collection.count = 3}
	if page ==
	   .Diagnostics_Performance {s.performance_collection = collection_model.create(); s.performance_collection.count = 3}
	retained: Reader
	defer {
		fault.refuse = 0
		testing.expect(t, destroy_shell(&s)); destroy_reader(&retained)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 &&
			len(tracking.bad_free_array) == 0 &&
			ledger.live == 0 &&
			ledger.created == ledger.destroyed,
			"interaction boundary cleanup must be complete",
		)
	}
	if boundary != .Entry {
		if !testing.expect(t, enter(&s)) {return 0}
		copied: bool; retained, copied = copy_reader(&s.runtime.live, a)
		if !testing.expect(t, copied) {return 0}
	}
	before_live, before_native := tracking.current_memory_allocated, ledger.live
	stamp := reader_stamp(&s.runtime.live)
	fault.requests, fault.refuse = 0, refusal
	ok := false
	switch boundary {
	case .Entry:
		ok = enter(&s)
	case .Rebuild:
		ok = rebuild(&s.runtime)
	case .Copy:
		reader, copied := copy_reader(&s.runtime.live, s.allocator); ok = copied
		destroy_reader(&reader)
	case .Edit:
		e: sdl.Event; e.text = {
			type     = .TEXT_INPUT,
			windowID = 17,
			text     = "!",
		}
		ok = handle_input(&s, e, {1280, 960})
	}
	requests := fault.requests
	testing.expect(
		t,
		ok == (refusal == 0),
		fmt.tprintf("page=%v boundary=%v refusal=%d/%d", page, boundary, refusal, requests),
	)
	if boundary == .Copy {
		testing.expect(
			t,
			current(&s.runtime) &&
			tracking.current_memory_allocated == before_live &&
			ledger.live == before_native,
		)
	} else if refusal != 0 {
		testing.expect(t, !s.runtime.publication.ready)
		if boundary ==
		   .Rebuild {testing.expect(t, reader_stamp(&s.runtime.live) == stamp && tracking.current_memory_allocated == before_live + i64(len(s.runtime.diagnostic.id)) && ledger.live == before_native, "only one copied error ID may remain beside historical owners")}
		accepted_effects, accepted_revision := s.model.effects, s.model.revision
		fault.refuse = 0
		testing.expect(
			t,
			recover(&s) &&
			current(&s.runtime) &&
			s.model.effects == accepted_effects &&
			s.model.revision == accepted_revision,
			"recovery never replays the application effect",
		)
	}
	return requests
}
@(test)
g09_g14_every_compact_owning_boundary_refuses_without_leaks_or_replay :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	surface := sdl.CreateSurface(
		1280,
		960,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
	font, error := os.read_entire_file(
		"resources/font.ttf",
		context.allocator,
	); if !testing.expect(t, error == nil) {return}; defer delete(font)
	for page in ([6]model.Page{.Text_Input, .Scroll_Table, .Collections, .Layers, .Hud, .Gestures}) {
		for boundary in ([3]Interaction_Boundary{.Entry, .Rebuild, .Copy}) {
			requests := exercise_interaction_boundary(t, renderer, font, page, boundary, 0)
			fmt.printf(
				"interaction boundary page=%v operation=%v requests=%d\n",
				page,
				boundary,
				requests,
			)
			for refusal in 1 ..= requests {exercise_interaction_boundary(t, renderer, font, page, boundary, refusal)}
		}
	}
	requests := exercise_interaction_boundary(t, renderer, font, .Text_Input, .Edit, 0)
	for refusal in 1 ..= requests {exercise_interaction_boundary(t, renderer, font, .Text_Input, .Edit, refusal)}
}
