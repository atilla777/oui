package app

import "core:testing"
import gestures "ui:ui_gestures"
import interaction "ui:ui_interaction"
import layers "ui:ui_layers"
import layout "ui:ui_layout"
import sdl "vendor:sdl3"

@(test)
lab_contract_inventory_invalid_target_and_early_release_do_not_move :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Inventory) {return}
	s := &f.s
	testing.expect(t, dispatch(s, {.Activate, "8:lab-left7:card-01", .Agent, false}))
	v, _ := s.runtime.content.(^Lab_Inventory_Runtime)
	handle, found := layout.find(&s.runtime.live.geometry, "lab/drag-handle")
	if !testing.expect(t, found) {return}
	x, y := handle.bounds.x + 4, handle.bounds.y + 4
	page_pointer(s, .MOUSE_BUTTON_DOWN, x, y)
	page_pointer(s, .MOUSE_MOTION, x + 5, y)
	page_pointer(s, .MOUSE_BUTTON_UP, x + 5, y)
	testing.expect(t, !v.has_pending && v.gesture.live.phase == .Idle && s.inventory.revision == 0)
	start := lab_test_gesture(s, {kind = .Begin, id = "card-01", source = .Agent})
	lab_test_gesture(s, {kind = .Aim, id = "missing-target", source = .Agent, cycle = start.cycle})
	end := lab_test_gesture(s, {kind = .End, source = .Agent, cycle = start.cycle})
	testing.expect(t, !end.has_proposal && !v.has_pending && s.inventory.revision == 0)
	lab_test_gesture(s, {kind = .End, source = .Agent, cycle = start.cycle})
	testing.expect(
		t,
		s.inventory.panels[0].count == 6 &&
		s.inventory.panels[1].count == 6 &&
		current(&s.runtime),
	)
}

@(test)
lab_contract_upper_settings_modal_traps_focus_and_background_actions :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Settings) {return}
	s := &f.s
	testing.expect(t, dispatch(s, {.Activate, "name/apply", .Agent, false}))
	before := s.model
	testing.expect(t, !dispatch(s, {.Activate, "lab/enabled", .Agent, false}))
	testing.expect(t, !dispatch(s, {.Focus, "name/field", .Agent, false}))
	for _ in 0 ..< 4 {
		page_key(s, sdl.K_TAB)
		id := s.runtime.interaction.focus_id
		testing.expect(t, id == "lab/decline" || id == "lab/confirm")
	}
	testing.expect(t, s.model == before && current(&s.runtime))
	page_key(s, sdl.K_ESCAPE)
	v, _ := s.runtime.content.(^Lab_Menu_Runtime)
	testing.expect(
		t,
		v.settings &&
		!v.confirm &&
		!v.discard &&
		s.model.lab_name.applied == before.lab_name.applied,
	)
}

@(test)
lab_contract_named_unsupported_editor_scope_and_pan_refusals :: proc(t: ^testing.T) {
	{
		f: Page_Fixture; defer stop_page_fixture(&f)
		if !start_page_fixture(t, &f, .Lab_Settings) {return}
		s := &f.s
		draft, applied, count := s.model.lab_name.draft, s.model.lab_name.applied, s.model.effects
		e: sdl.Event; e.edit = {
			type     = .TEXT_EDITING,
			windowID = 17,
			text     = "preedit",
		}
		handle_input(s, e, {1280, 960})
		n, _ := active_name(&s.runtime)
		testing.expect(t, n.native_error == .Unsupported_Composition && current(&s.runtime))
		testing.expect(
			t,
			s.model.lab_name.draft == draft &&
			s.model.lab_name.applied == applied &&
			s.model.effects == count,
		)
		target := s.runtime.live.interaction.targets[0].description
		candidate, e2 := layers.prepare(
			&s.runtime.layers,
			&s.runtime.interaction,
			&s.runtime.live.geometry,
			[]interaction.Target{target},
			nil,
			{
				base_root_id = "root",
				popups = []layers.Popup{{root_id = "root", owner_scope_id = "missing-scope"}},
			},
			s.allocator,
		)
		defer layers.destroy_candidate(&candidate)
		testing.expect(t, e2.code != .None && current(&s.runtime) && s.model.effects == count)
	}
	{
		f: Page_Fixture; defer stop_page_fixture(&f)
		if !start_page_fixture(t, &f, .Lab_Inventory) {return}
		r := &f.s.runtime; v, _ := r.content.(^Lab_Inventory_Runtime)
		candidate, e := gestures.prepare(
			&v.gesture,
			&r.live.geometry,
			&r.live.interaction,
			nil,
			[]gestures.Description {
				{
					id = "unsupported-row-pan",
					node_id = "lab/left-viewport",
					kind = .Pan_Scroll,
					scroll_id = "lab/left-viewport",
				},
			},
			v.model.revision,
			r.allocator,
		)
		defer gestures.destroy_candidate(&candidate)
		testing.expect(t, e.code != .None && current(r) && f.s.inventory.revision == 0)
	}
}

@(test)
lab_contract_settings_decision_recovery_is_not_apply_replay :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Settings) {return}
	s := &f.s
	page_key(s, sdl.K_A, {.LCTRL}); page_text(s, "Shown draft")
	testing.expect(t, dispatch(s, {.Activate, "lab/enabled", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "lab/amount/increment", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "name/apply", .Agent, false}))
	v, _ := s.runtime.content.(^Lab_Menu_Runtime)
	testing.expect(t, v.confirm && s.runtime.interaction.focus_id == "lab/decline")
	before := s.model.effects
	for fault in ([]Fault{.Prepare, .Resource, .Copy, .Publish, .Render, .Readback, .Present}) {
		s.runtime.fault = fault
		failed := !rebuild(&s.runtime)
		if fault == .Render ||
		   fault == .Readback ||
		   fault == .Present {failed = !present(&s.runtime)}
		testing.expect(t, failed && !current(&s.runtime))
		dispatch(s, {.Activate, "lab/confirm", .Agent, false})
		testing.expect(t, s.model.effects == before && v.confirm)
		testing.expect(t, recover(s) && current(&s.runtime) && present(&s.runtime))
		testing.expect(t, v.confirm && s.model.lab_name.applied == "Алексей")
	}
	testing.expect(t, dispatch(s, {.Activate, "lab/confirm", .Agent, false}))
	testing.expect(t, s.model.effects == before + 1 && s.model.lab_name.applied == "Shown draft")
	testing.expect(t, s.model.lab_applied_enabled && s.model.lab_applied_amount == 51)
	s.runtime.fault = .Render
	testing.expect(t, !present(&s.runtime) && recover(s) && present(&s.runtime))
	dispatch(s, {.Activate, "lab/confirm", .Agent, false})
	testing.expect(t, s.model.effects == before + 1 && !v.confirm)
}

@(test)
lab_contract_inventory_recovery_and_cold_lifetime_cancel_pending :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Inventory) {return}
	s := &f.s
	lab_test_offer(t, s)
	v, _ := s.runtime.content.(^Lab_Inventory_Runtime)
	testing.expect(t, v.has_pending && s.runtime.interaction.focus_id == "lab/transfer-cancel")
	before := s.inventory
	s.runtime.fault = .Present
	testing.expect(t, !present(&s.runtime))
	dispatch(s, {.Activate, "lab/transfer-confirm", .Agent, false})
	testing.expect(t, s.inventory == before && v.has_pending)
	testing.expect(t, recover(s) && present(&s.runtime) && v.has_pending)
	testing.expect(t, dispatch(s, {.Activate, "lab/transfer-confirm", .Agent, false}))
	testing.expect(t, s.inventory.panels[0].count == 5 && s.inventory.panels[1].count == 7)
	applied := s.inventory
	testing.expect(t, recover(s) && s.inventory == applied)
	dispatch(s, {.Activate, "lab/transfer-confirm", .Agent, false})
	testing.expect(t, s.inventory == applied && s.model.lab_selected == "card-01")
	// A second, different request is transient; destroying this runtime must not
	// resurrect it from a retained gesture result in the cold lifetime.
	testing.expect(t, dispatch(s, {.Activate, "8:lab-left7:card-02", .Agent, false}))
	start := lab_test_gesture(s, {kind = .Begin, id = "card-02", source = .Agent})
	lab_test_gesture(s, {kind = .Aim, id = "panel-right", source = .Agent, cycle = start.cycle})
	lab_test_gesture(s, {kind = .End, source = .Agent, cycle = start.cycle})
	testing.expect(t, v.has_pending)
	old, copied := copy_reader(&s.runtime.live, context.allocator)
	if !testing.expect(t, copied) {return}; defer destroy_reader(&old)
	stamp := reader_stamp(&old)
	cold := applied; cold.last_sequence, cold.last_cycle = 0, 0
	testing.expect(t, enter(s) && current(&s.runtime) && present(&s.runtime))
	v, _ = s.runtime.content.(^Lab_Inventory_Runtime)
	testing.expect(t, !v.has_pending && s.inventory == cold && !stamp.lifetime.alive)
	testing.expect(t, draw_reader(&old))
	testing.expect(
		t,
		!accept_base(
			&s.runtime,
			stamp,
			interaction.Button_Activated {
				id = "lab/transfer-confirm",
				sequence = 1,
				source = .Agent,
			},
		),
	)
}

@(test)
lab_contract_cold_hud_retains_values_not_held_front_or_popup :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Hud) {return}
	s := &f.s
	testing.expect(t, dispatch(s, {.Activate, "hud/minus", .Agent, false}))
	lifecycle_key_edge(s, sdl.K_SPACE, true)
	advance_page_clock(s, 0); advance_page_clock(s, 999)
	testing.expect(t, s.model.lab_hp == 50 && s.model.lab_hold_count == 0)
	testing.expect(t, enter(s))
	advance_page_clock(s, 1000); advance_page_clock(s, 3000)
	testing.expect(t, s.model.lab_hp == 50 && s.model.lab_hold_count == 0)
	lifecycle_key_edge(s, sdl.K_SPACE, true)
	advance_page_clock(s, 4000); advance_page_clock(s, 5000)
	testing.expect(
		t,
		s.model.lab_hold_count == 0,
		"held physical state needs release and a new front",
	)
	lifecycle_key_edge(s, sdl.K_SPACE, false); lifecycle_key_edge(s, sdl.K_SPACE, true)
	advance_page_clock(s, 6000); advance_page_clock(s, 7000)
	testing.expect(t, s.model.lab_hp == 100 && s.model.lab_hold_count == 1)
	lifecycle_key_edge(s, sdl.K_SPACE, false)
	testing.expect(t, dispatch(s, {.Activate, "lab/popup", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "lab/tooltip", .Agent, false}))
	testing.expect(t, enter(s) && current(&s.runtime) && present(&s.runtime))
	h, _ := active_hold(&s.runtime)
	testing.expect(
		t,
		!h.popup && !h.tooltip && s.model.lab_hp == 100 && s.model.lab_hold_count == 1,
	)
}
