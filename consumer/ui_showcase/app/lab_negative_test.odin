package app

import "core:testing"
import collections "ui:ui_collections"
import gestures "ui:ui_gestures"
import interaction "ui:ui_interaction"
import sdl "vendor:sdl3"

lab_test_gesture :: proc(s: ^Shell, action: gestures.Action) -> gestures.Result {
	r := &s.runtime; v, _ := r.content.(^Lab_Inventory_Runtime)
	ready := r.publication.ready
	result := gestures.dispatch(&v.gesture, &r.interaction, nil, action)
	if !accept_lab_gesture(r, result) {block(r)}
	finish_input(s, s.model.page, ready)
	return result
}
lab_test_offer :: proc(t: ^testing.T, s: ^Shell, target := "panel-right") {
	testing.expect(t, dispatch(s, {.Activate, "8:lab-left7:card-01", .Agent, false}))
	start := lab_test_gesture(s, {kind = .Begin, id = "card-01", source = .Agent})
	testing.expect(t, start.code == .Applied)
	lab_test_gesture(s, {kind = .Aim, id = target, source = .Agent, cycle = start.cycle})
	end := lab_test_gesture(s, {kind = .End, source = .Agent, cycle = start.cycle})
	testing.expect(t, end.code == .Applied)
}

@(test)
lab_pending_transfer_stale_app_refusal_same_container_and_loss :: proc(t: ^testing.T) {
	for scenario in 0 ..< 4 {
		f: Page_Fixture; defer stop_page_fixture(&f)
		if !start_page_fixture(t, &f, .Lab_Inventory) {return}
		s := &f.s; v, _ := s.runtime.content.(^Lab_Inventory_Runtime)
		if scenario == 3 {
			testing.expect(t, dispatch(s, {.Activate, "8:lab-left7:card-01", .Agent, false}))
			lab_test_gesture(s, {kind = .Begin, id = "card-01", source = .Agent})
			loss: sdl.Event; loss.window = {
				type     = .WINDOW_FOCUS_LOST,
				windowID = 17,
			}
			handle_input(s, loss, {1280, 960})
			testing.expect(
				t,
				!v.has_pending && v.gesture.live.phase == .Idle && s.inventory.revision == 0,
			)
			continue
		}
		lab_test_offer(t, s, "panel-left" if scenario == 2 else "panel-right")
		if scenario == 2 {
			testing.expect(
				t,
				!v.has_pending && v.outcome.reason == .Same_Panel && s.inventory.revision == 0,
			)
			continue
		}
		if !testing.expect(
			t,
			v.has_pending && v.pending.payload_id == "card-01" && s.inventory.revision == 0,
		) {return}
		if scenario == 0 {s.inventory.revision += 1} else {s.inventory.panels[1].available = false}
		s.model.revision += 1
		testing.expect(t, rebuild(&s.runtime))
		testing.expect(t, dispatch(s, {.Activate, "lab/transfer-confirm", .Agent, false}))
		testing.expect(
			t,
			!v.has_pending && s.inventory.panels[0].count == 6 && s.inventory.panels[1].count == 6,
		)
		testing.expect(t, v.outcome.reason == (.Stale_Model if scenario == 0 else .Unavailable))
		testing.expect(t, current(&s.runtime) && present(&s.runtime))
	}
}

@(test)
lab_actual_regions_and_capture_claims_refuse_duplicates :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Inventory) {return}
	r := &f.s.runtime; v, _ := r.content.(^Lab_Inventory_Runtime)
	d := v.states[0].frame.collections[0].description
	testing.expect(
		t,
		collections.validate_regions(&r.live.geometry, []collections.Collection_Description{d, d}).code ==
		.Binding,
	)
	candidate, code := interaction.prepare(
		&r.live.geometry,
		[]interaction.Target{{"lab/left-viewport", "button", true, true}},
		[]interaction.Capture_Claim {
			{"lab/left-viewport", "collections"},
			{"lab/left-viewport", "gestures"},
		},
		context.allocator,
	)
	defer interaction.destroy_candidate(&candidate)
	testing.expect(t, code != .Applied && current(r))
}

@(test)
lab_native_text_close_refusal_never_publishes_a_new_owner :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Settings) {return}
	s := &f.s; n, _ := active_name(&s.runtime)
	native: Text_Lifecycle_Fixture
	n.input.lifecycle = {
		start = text_start,
		stop  = text_stop,
		size  = text_size,
		area  = text_area,
		user  = &native,
	}
	testing.expect(t, sync_name(s) && native.starts == 1)
	old := reader_stamp(&s.runtime.live)
	native.fail_stop = true
	testing.expect(t, !dispatch(s, {.Activate, "name/apply", .Agent, false}))
	testing.expect(
		t,
		n.input.text_active &&
		s.cleanup_pending &&
		!s.runtime.publication.ready &&
		reader_stamp(&s.runtime.live) == old,
	)
	native.fail_stop = false
	loss: sdl.Event; loss.window = {
		type     = .WINDOW_FOCUS_LOST,
		windowID = 17,
	}
	handle_input(s, loss, {1280, 960})
	testing.expect(t, native.stops == 1 && n.input.text_active)
	testing.expect(
		t,
		recover(s) && native.stops == 2 && s.model.effects == 0 && current(&s.runtime),
	)
}
