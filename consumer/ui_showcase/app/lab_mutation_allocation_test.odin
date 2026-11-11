package app

import model "../model"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:testing"
import gestures "ui:ui_gestures"
import backend "ui:ui_sdl"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

Lab_Mutation_Boundary :: enum {
	Edit,
	Apply_Open,
	Apply_Confirm,
	Discard,
	Transfer_Offer,
	Transfer_Confirm,
	Transfer_Cancel,
	Select,
	Focus_Reveal,
	Transfer_Begin,
	Transfer_Aim,
	Reverse,
	Scale,
}
exercise_lab_mutation :: proc(
	t: ^testing.T,
	renderer: ^sdl.Renderer,
	font: []u8,
	boundary: Lab_Mutation_Boundary,
	refusal: int,
) -> int {
	tracking: mem.Tracking_Allocator
	mem.tracking_allocator_init(
		&tracking,
		context.allocator,
	); defer mem.tracking_allocator_destroy(&tracking)
	fault := Allocation_Fault {
		backing = mem.tracking_allocator(&tracking),
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
	s.model.page = .Lab_Settings; s.input.window_id = 17
	if boundary >= .Transfer_Offer {s.model.page = .Lab_Inventory}
	defer {
		fault.refuse = 0
		testing.expect(t, destroy_shell(&s))
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 &&
			len(tracking.bad_free_array) == 0 &&
			ledger.live == 0 &&
			ledger.created == ledger.destroyed,
			"Lab mutation teardown balances tracked memory and native handles separately",
		)
	}
	if !testing.expect(t, enter(&s)) {return 0}
	if boundary > .Edit && boundary <= .Discard {page_text(&s, "!")}
	if boundary ==
	   .Apply_Confirm {testing.expect(t, dispatch(&s, {.Activate, "name/apply", .Agent, false}))}
	if boundary == .Discard {testing.expect(t, dispatch(&s, {.Cancel, "", .Agent, false}))}
	if boundary == .Transfer_Offer {
		testing.expect(t, dispatch(&s, {.Activate, "8:lab-left7:card-01", .Agent, false}))
		start := lab_test_gesture(&s, {kind = .Begin, id = "card-01", source = .Agent})
		lab_test_gesture(
			&s,
			{kind = .Aim, id = "panel-right", source = .Agent, cycle = start.cycle},
		)
	}
	if boundary == .Transfer_Confirm || boundary == .Transfer_Cancel {lab_test_offer(t, &s)}
	if boundary == .Transfer_Begin ||
	   boundary == .Transfer_Aim ||
	   boundary == .Reverse ||
	   boundary == .Scale {
		testing.expect(t, dispatch(&s, {.Activate, "8:lab-left7:card-01", .Agent, false}))
		if boundary ==
		   .Transfer_Aim {lab_test_gesture(&s, {kind = .Begin, id = "card-01", source = .Agent})}
	}
	old := reader_stamp(&s.runtime.live)
	fault.requests, fault.refuse = 0, refusal
	ok := false
	switch boundary {
	case .Edit:
		e: sdl.Event; e.text = {
			type     = .TEXT_INPUT,
			windowID = 17,
			text     = "!",
		}
		ok = handle_input(&s, e, {1280, 960})
	case .Apply_Open:
		ok = dispatch(&s, {.Activate, "name/apply", .Agent, false})
	case .Apply_Confirm:
		ok = dispatch(&s, {.Activate, "lab/confirm", .Agent, false})
	case .Discard:
		ok = dispatch(&s, {.Activate, "lab/discard", .Agent, false})
	case .Transfer_Offer:
		v, _ := s.runtime.content.(^Lab_Inventory_Runtime)
		result := gestures.dispatch(
			&v.gesture,
			&s.runtime.interaction,
			nil,
			{kind = .End, source = .Agent, cycle = v.gesture.live.cycle},
		)
		accepted := accept_lab_gesture(&s.runtime, result)
		if !accepted {block(&s.runtime)}
		ok = accepted && finish_input(&s, s.model.page, true)
	case .Transfer_Confirm:
		ok = dispatch(&s, {.Activate, "lab/transfer-confirm", .Agent, false})
	case .Transfer_Cancel:
		ok = dispatch(&s, {.Cancel, "", .Agent, false})
	case .Select:
		ok = dispatch(&s, {.Activate, "8:lab-left7:card-01", .Agent, false})
	case .Focus_Reveal:
		ok = dispatch(&s, {.Focus, "8:lab-left7:card-06", .Agent, false})
	case .Transfer_Begin, .Transfer_Aim:
		v, _ := s.runtime.content.(^Lab_Inventory_Runtime)
		action := gestures.Action {
			kind   = .Begin,
			id     = "card-01",
			source = .Agent,
		}
		if boundary == .Transfer_Aim {action = {
				kind   = .Aim,
				id     = "panel-right",
				source = .Agent,
				cycle  = v.gesture.live.cycle,
			}}
		result := gestures.dispatch(&v.gesture, &s.runtime.interaction, nil, action)
		accepted := accept_lab_gesture(&s.runtime, result)
		if !accepted {block(&s.runtime)}
		ok = accepted && finish_input(&s, s.model.page, true)
	case .Reverse:
		ok = dispatch(&s, {.Activate, "lab/reverse", .Agent, false})
	case .Scale:
		ok = dispatch(&s, {.Activate, "shell/scale", .Agent, false})
	}
	requests := fault.requests
	message := fmt.tprintf("boundary=%v refusal=%d requests=%d", boundary, refusal, requests)
	testing.expect(t, ok == (refusal == 0), message)
	if refusal != 0 {
		testing.expect(
			t,
			!s.runtime.publication.ready &&
			!current(&s.runtime) &&
			reader_stamp(&s.runtime.live) == old,
			message,
		)
		accepted_model, accepted_inventory := s.model, s.inventory
		pending := false
		if v, selected := s.runtime.content.(^Lab_Inventory_Runtime);
		   selected {pending = v.has_pending}
		fault.refuse = 0
		testing.expect(t, recover(&s) && current(&s.runtime), message)
		testing.expect(
			t,
			s.model == accepted_model && s.inventory == accepted_inventory,
			"R rebuilds the accepted model without replaying the failed intention",
		)
		if v, selected := s.runtime.content.(^Lab_Inventory_Runtime);
		   selected {testing.expect(t, v.has_pending == pending, "Recovery of the same runtime preserves only its surviving pending decision")}
	}
	return requests
}

@(test)
lab_mutation_failure_is_a_barrier_not_implicit_recovery :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	surface := sdl.CreateSurface(1280, 960, .RGBA32)
	if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(surface)
	if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
	font, error := os.read_entire_file("resources/font.ttf", context.allocator)
	if !testing.expect(t, error == nil) {return}; defer delete(font)
	for boundary in Lab_Mutation_Boundary {exercise_lab_mutation(t, renderer, font, boundary, 1)}
}

@(test)
lab_every_mutation_allocation_refuses_without_partial_publication_or_replay :: proc(
	t: ^testing.T,
) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	surface := sdl.CreateSurface(1280, 960, .RGBA32)
	if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(surface)
	if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
	font, error := os.read_entire_file("resources/font.ttf", context.allocator)
	if !testing.expect(t, error == nil) {return}; defer delete(font)
	for boundary in Lab_Mutation_Boundary {
		requests := exercise_lab_mutation(t, renderer, font, boundary, 0)
		fmt.printf("Lab mutation boundary=%v backing-requests=%d\n", boundary, requests)
		for refusal in 1 ..= requests {exercise_lab_mutation(t, renderer, font, boundary, refusal)}
	}
}
