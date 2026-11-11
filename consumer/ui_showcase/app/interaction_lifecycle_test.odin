package app

import "core:testing"
import collections "ui:ui_collections"
import layout "ui:ui_layout"
import scroll "ui:ui_scroll"
import sdl "vendor:sdl3"

// AC-006 evidence uses the real shell route and cold runtime replacement, not
// model.page assignment or direct enter(). Every navigation has exactly its own
// one application effect; a hidden Apply/Drop/completion would violate this count.
lifecycle_navigation :: proc(t: ^testing.T, s: ^Shell, id: string) -> bool {
	before := s.model.effects
	ok := dispatch(s, {.Activate, id, .Agent, false})
	return testing.expect(t, ok && s.model.effects == before + 1 && current(&s.runtime), id)
}
lifecycle_return :: proc(t: ^testing.T, s: ^Shell, id, initial_focus: string) -> bool {
	if !lifecycle_navigation(t, s, "shell/catalogue") {return false}
	for _ in 0 ..< 10 {
		available :=
			false; for target in s.runtime.interaction.frame.targets {if target.description.id == id && target.availability == .Applied {available = true}}
		if available {
			if !lifecycle_navigation(t, s, id) {return false}
			return testing.expect(
				t,
				s.runtime.interaction.focus_id == initial_focus && present(&s.runtime),
				"cold entry uses page initial focus, not the departed technical focus",
			)
		}
		if !lifecycle_navigation(t, s, "catalogue/next") {return false}
	}
	testing.expect(t, false, "requested page not found through the real catalogue"); return false
}
lifecycle_key_edge :: proc(s: ^Shell, key: sdl.Keycode, down: bool) -> bool {
	e: sdl.Event; e.key = {
		type     = .KEY_DOWN if down else .KEY_UP,
		windowID = 17,
		key      = key,
	}
	return handle_input(s, e, {1280, 960})
}

@(test)
g09_roundtrip_preserves_draft_not_selection_capture_or_hidden_apply :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Text_Input) {return}; s := &f.s
	page_key(s, sdl.K_A, sdl.KMOD_CTRL); page_text(s, "Draft")
	field, _ := layout.find(&s.runtime.live.geometry, "name/field")
	x, y := field.content.x + 1, field.content.y + 10
	testing.expect(
		t,
		page_pointer(s, .MOUSE_BUTTON_DOWN, x, y) && page_pointer(s, .MOUSE_MOTION, x + 24, y),
	)
	n, _ := active_name(&s.runtime)
	testing.expect(
		t,
		n.input.capture_id != "" &&
		n.state.frame.editors[0].caret != n.state.frame.editors[0].anchor &&
		s.input.mouse_down,
	)
	page_key(s, sdl.K_LEFT)
	testing.expect(
		t,
		s.runtime.interaction.focus_id == "name/field",
		"in-page interaction retains stable editor focus",
	)
	if !lifecycle_navigation(t, s, "shell/layout") {return}
	testing.expect(
		t,
		s.model.name.draft == "Draft" &&
		s.model.name.applied == "Алексей" &&
		s.input.mouse_down,
	)
	if !lifecycle_return(t, s, "text-input", "name/field") {return}
	n, _ = active_name(&s.runtime)
	testing.expect(
		t,
		n.input.capture_id == "" &&
		n.input.pending_click_id == "" &&
		n.state.pending == nil &&
		n.state.frame.editors[0].caret == n.state.frame.editors[0].anchor,
	)
	effects := s.model.effects
	page_pointer(s, .MOUSE_MOTION, x + 32, y); page_pointer(s, .MOUSE_BUTTON_DOWN, x, y)
	testing.expect(
		t,
		n.input.capture_id == "" && s.model.effects == effects,
		"held button cannot resurrect capture after return",
	)
	page_pointer(s, .MOUSE_BUTTON_UP, x, y); page_pointer(s, .MOUSE_BUTTON_DOWN, x, y)
	testing.expect(
		t,
		n.input.capture_id != "" && s.model.effects == effects,
		"release plus new front starts a fresh selection, not Apply",
	)
	page_pointer(s, .MOUSE_BUTTON_UP, x, y)
	testing.expect(
		t,
		s.model.name.draft == "Draft" &&
		s.model.name.applied == "Алексей" &&
		current(&s.runtime),
	)
}

@(test)
g10_roundtrip_preserves_dataset_selection_not_press_or_technical_focus :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Scroll_Table) {return}; s := &f.s
	testing.expect(t, dispatch(s, {.Activate, "table/dataset", .Agent, false}))
	r := scroll.dispatch(
		&s.runtime.scroll,
		&s.runtime.interaction,
		{kind = .Focus, id = "table/item-20", source = .Agent},
	)
	testing.expect(t, r.code == .Applied && finish_input(s, .Scroll_Table, true))
	testing.expect(t, dispatch(s, {.Activate, "table/item-20", .Agent, false}))
	testing.expect(
		t,
		s.runtime.interaction.focus_id == "table/item-20" && s.model.table_selected == 21,
	)
	row, _ := layout.find(&s.runtime.live.geometry, "table/item-20")
	x, y := row.bounds.x + 20, row.bounds.y + 10
	page_pointer(s, .MOUSE_BUTTON_DOWN, x, y)
	testing.expect(t, s.input.mouse_down && s.runtime.interaction.pressed_id != "")
	if !lifecycle_navigation(t, s, "shell/layout") ||
	   !lifecycle_return(t, s, "scroll-table", "table/dataset") {return}
	testing.expect(
		t,
		s.model.table_dataset == 1 &&
		s.model.table_selected == 21 &&
		s.runtime.interaction.pressed_id == "" &&
		s.input.mouse_down,
	)
	before := s.model.effects
	page_pointer(s, .MOUSE_BUTTON_UP, 20, 210)
	testing.expect(
		t,
		s.model.effects == before && s.model.table_selected == 21,
		"departed press release must not select a new row",
	)
	page_pointer(s, .MOUSE_BUTTON_DOWN, 20, 210); page_pointer(s, .MOUSE_BUTTON_UP, 20, 210)
	testing.expect(
		t,
		s.model.effects == before + 1 && s.model.table_selected == 1 && current(&s.runtime),
	)
}

@(test)
g11_roundtrip_preserves_order_mode_selection_not_press_or_focus :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Collections) {return}; s := &f.s
	testing.expect(
		t,
		dispatch(s, {.Activate, "collections/mode", .Agent, false}) &&
		dispatch(s, {.Activate, "collections/reverse", .Agent, false}),
	)
	c, _ := s.runtime.content.(^Collection_Page_Runtime)
	r := collections.dispatch(
		&c.state,
		&s.runtime.interaction,
		{kind = .Focus, collection_id = "collection", item_id = "item-05000", source = .Agent},
	)
	testing.expect(t, r.dispatch.code == .Applied && finish_input(s, .Collections, true))
	id, error := collections.item_node_id(
		"collection",
		"item-05000",
		context.allocator,
	); if !testing.expect(t, error == nil) {return}; defer delete(id)
	testing.expect(t, dispatch(s, {.Activate, id, .Agent, false}))
	selected := s.collection
	row, _ := layout.find(&s.runtime.live.geometry, id)
	page_pointer(s, .MOUSE_BUTTON_DOWN, row.bounds.x + 10, row.bounds.y + 10)
	testing.expect(t, s.input.mouse_down && s.runtime.interaction.pressed_id != "")
	if !lifecycle_navigation(t, s, "shell/layout") ||
	   !lifecycle_return(t, s, "collections", "collections/mode") {return}
	testing.expect(
		t,
		s.collection == selected && s.runtime.interaction.pressed_id == "" && s.input.mouse_down,
	)
	before := s.model.effects
	page_pointer(s, .MOUSE_BUTTON_UP, 20, 220)
	testing.expect(
		t,
		s.model.effects == before && s.collection == selected,
		"old release cannot activate a freshly materialized item",
	)
	page_pointer(s, .MOUSE_BUTTON_DOWN, 20, 220); page_pointer(s, .MOUSE_BUTTON_UP, 20, 220)
	testing.expect(
		t,
		s.model.effects == before + 1 && s.collection.selected != 5000 && current(&s.runtime),
	)
}

@(test)
g12_roundtrip_respects_modal_guard_and_cancels_scoped_hold_popup :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Layers) {return}; s := &f.s
	testing.expect(
		t,
		dispatch(s, {.Activate, "layers/base-count", .Agent, false}) &&
		dispatch(s, {.Activate, "layers/check", .Agent, false}),
	)
	testing.expect(
		t,
		dispatch(s, {.Activate, "layers/open", .Agent, false}) &&
		dispatch(s, {.Activate, "layers/open-b", .Agent, false}),
	)
	before := s.model.effects
	testing.expect(
		t,
		!dispatch(s, {.Activate, "shell/layout", .Agent, false}) &&
		s.model.page == .Layers &&
		s.model.effects == before &&
		len(s.runtime.layers.frame.layers.modals) == 2,
		"modal guards must not be bypassed to manufacture departure evidence",
	)
	testing.expect(
		t,
		dispatch(s, {.Cancel, "", .Agent, false}) &&
		dispatch(s, {.Cancel, "", .Agent, false}) &&
		s.runtime.interaction.focus_id == "layers/open",
	)
	testing.expect(
		t,
		dispatch(s, {.Activate, "layers/popup", .Agent, false}) &&
		dispatch(s, {.Activate, "layers/tooltip", .Agent, false}),
	)
	testing.expect(t, dispatch(s, {.Focus, "layers/base-hold", .Agent, false}))
	lifecycle_key_edge(s, sdl.K_SPACE, true); advance_page_clock(s, 10); advance_page_clock(s, 510)
	h, _ := s.runtime.content.(^Hold_Page_Runtime)
	testing.expect(t, h.state.live.phase == .Holding && h.state.live.elapsed_ms == 500)
	counts, checked := s.model.layer_counts, s.model.layer_checked
	if !lifecycle_navigation(t, s, "shell/layout") ||
	   !lifecycle_return(t, s, "layers", "layers/open") {return}
	h, _ = s.runtime.content.(^Hold_Page_Runtime)
	testing.expect(
		t,
		s.model.layer_counts == counts &&
		s.model.layer_checked == checked &&
		h.state.live.phase == .Idle &&
		!h.popup &&
		!h.tooltip &&
		len(s.runtime.layers.frame.layers.modals) == 0,
	)
	testing.expect(t, dispatch(s, {.Focus, "layers/base-hold", .Agent, false}))
	before = s.model.effects
	lifecycle_key_edge(s, sdl.K_SPACE, true); advance_page_clock(s, 10000)
	testing.expect(t, h.state.live.phase == .Idle && s.model.effects == before)
	lifecycle_key_edge(s, sdl.K_SPACE, false); lifecycle_key_edge(s, sdl.K_SPACE, true)
	advance_page_clock(s, 10001); advance_page_clock(s, 11001)
	testing.expect(
		t,
		s.model.layer_counts[0] == counts[0] + 1 && s.model.effects == before + 1,
		"new scoped hold completes once only after release/new front",
	)
	lifecycle_key_edge(s, sdl.K_SPACE, false)
}

@(test)
g13_roundtrip_mid_hold_and_loss_preserve_hp_without_hidden_restore :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Hud) {return}; s := &f.s
	testing.expect(t, dispatch(s, {.Activate, "hud/minus", .Agent, false}))
	lifecycle_key_edge(
		s,
		sdl.K_SPACE,
		true,
	); advance_page_clock(s, 100); advance_page_clock(s, 1099)
	h, _ := s.runtime.content.(^Hold_Page_Runtime)
	testing.expect(
		t,
		h.state.live.phase == .Holding && h.state.live.elapsed_ms == 999 && s.model.hud_hp == 50,
	)
	if !lifecycle_navigation(t, s, "shell/layout") ||
	   !lifecycle_return(t, s, "hud", "hud/restore") {return}
	h, _ = s.runtime.content.(^Hold_Page_Runtime)
	before := s.model.effects
	lifecycle_key_edge(s, sdl.K_SPACE, true); advance_page_clock(s, 90000)
	testing.expect(
		t,
		h.state.live.phase == .Idle &&
		s.model.hud_hp == 50 &&
		s.model.hud_count == 0 &&
		s.model.effects == before,
	)
	lifecycle_key_edge(s, sdl.K_SPACE, false); lifecycle_key_edge(s, sdl.K_SPACE, true)
	advance_page_clock(s, 90001); advance_page_clock(s, 90501)
	loss: sdl.Event; loss.window = {
		type     = .WINDOW_FOCUS_LOST,
		windowID = 17,
	}; handle_input(s, loss, {1280, 960})
	testing.expect(t, h.state.live.phase == .Idle && s.model.hud_count == 0)
	loss.window.type = .WINDOW_FOCUS_GAINED; handle_input(s, loss, {1280, 960})
	lifecycle_key_edge(s, sdl.K_SPACE, false); lifecycle_key_edge(s, sdl.K_SPACE, true)
	advance_page_clock(s, 100000); advance_page_clock(s, 100999)
	testing.expect(t, s.model.hud_count == 0 && s.model.effects == before)
	advance_page_clock(s, 101000)
	testing.expect(
		t,
		s.model.hud_count == 1 && s.model.hud_hp == 100 && s.model.effects == before + 1,
	)
	lifecycle_key_edge(s, sdl.K_SPACE, false)
}

@(test)
g14_roundtrips_cancel_armed_drag_repeat_pan_without_model_replay :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Gestures) {return}; s := &f.s
	page_key(s, sdl.K_A, sdl.KMOD_CTRL); page_text(s, "Gesture draft")
	// Preserve an actually accepted card move across every subsequent departure.
	g, _ := s.runtime.content.(^Gesture_Page_Runtime)
	card, _ := layout.find(&s.runtime.live.geometry, "gestures/card-01")
	x, y := card.bounds.x + 20, card.bounds.y + 24
	page_pointer(s, .MOUSE_BUTTON_DOWN, x, y); page_pointer(s, .MOUSE_MOTION, x + 6, y)
	target, _ := layout.find(&s.runtime.live.geometry, "gestures/right-title")
	page_pointer(
		s,
		.MOUSE_MOTION,
		target.bounds.x + 20,
		target.bounds.y + 12,
	); page_pointer(s, .MOUSE_BUTTON_UP, target.bounds.x + 20, target.bounds.y + 12)
	advance_page_clock(s, 0); advance_page_clock(s, 1)
	testing.expect(t, s.gesture.panels[0].count == 5 && s.gesture.panels[1].count == 7)
	for phase in 0 ..< 4 {
		g, _ = s.runtime.content.(^Gesture_Page_Runtime)
		id := "gestures/card-02"
		if phase == 2 {id = "gestures/right-down"}; if phase == 3 {id = "gestures/right-pan"}
		owner, _ := layout.find(&s.runtime.live.geometry, id)
		x, y = owner.bounds.x + 20, owner.bounds.y + owner.bounds.h / 2
		page_pointer(s, .MOUSE_BUTTON_DOWN, x, y)
		if phase == 1 {page_pointer(s, .MOUSE_MOTION, x + 6, y)}
		if phase == 2 {advance_page_clock(s, 100); advance_page_clock(s, 500)}
		if phase == 3 {page_pointer(s, .MOUSE_MOTION, x, y - 24)}
		if phase ==
		   0 {testing.expect(t, g.state.live.phase == .Armed)} else {testing.expect(t, g.state.live.phase == .Active)}
		panels := s.gesture.panels
		if !lifecycle_navigation(t, s, "shell/layout") ||
		   !lifecycle_return(t, s, "gestures", "name/field") {return}
		g, _ = s.runtime.content.(^Gesture_Page_Runtime)
		testing.expect(
			t,
			s.gesture.panels == panels &&
			s.model.gesture_name.draft == "Gesture draft" &&
			s.model.gesture_name.applied == "Алексей" &&
			g.state.live.phase == .Idle &&
			g.input.pending == nil &&
			!g.input.clock.has_base &&
			g.editing.input.capture_id == "",
		)
		before := s.model.effects
		page_pointer(
			s,
			.MOUSE_BUTTON_DOWN,
			x,
			y,
		); page_pointer(s, .MOUSE_MOTION, x + 20, y); advance_page_clock(s, 100000)
		testing.expect(
			t,
			g.state.live.phase == .Idle && s.model.effects == before && s.gesture.panels == panels,
			"old physical press cannot resurrect gesture or synthesize Drop",
		)
		page_pointer(s, .MOUSE_BUTTON_UP, x, y)
		owner, _ = layout.find(&s.runtime.live.geometry, "gestures/card-02")
		x, y = owner.bounds.x + 20, owner.bounds.y + 24
		page_pointer(s, .MOUSE_BUTTON_DOWN, x, y)
		testing.expect(t, g.state.live.phase == .Armed && s.model.effects == before)
		page_pointer(s, .MOUSE_BUTTON_UP, x, y); advance_page_clock(s, 100001)
		testing.expect(
			t,
			s.gesture.panels == panels && s.model.effects == before && current(&s.runtime),
		)
	}
}
