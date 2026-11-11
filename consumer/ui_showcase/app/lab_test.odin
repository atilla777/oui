package app

import model "../model"
import "core:strings"
import "core:testing"

@(test)
lab_empty_apply_keeps_editor_and_shows_reason :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Settings) {return}
	s := &f.s
	page_key(s, sdl.K_A, {.LCTRL}); page_key(s, sdl.K_BACKSPACE)
	dispatch(s, {.Activate, "name/apply", .Agent, false})
	visible := false
	for text in s.runtime.live.text.text_blocks {visible ||= strings.contains(text.original_text, "Пустое имя нельзя применить")}
	testing.expect(
		t,
		visible && s.model.lab_name.draft == "" && s.model.lab_name.applied == "Алексей",
	)
	testing.expect(t, dispatch(s, {.Focus, "name/field", .Agent, false}))
	page_text(s, "Fixed")
	testing.expect(t, s.model.lab_name.draft == "Fixed" && current(&s.runtime))
}

@(test)
lab_inventory_cards_have_localized_names_and_source :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Inventory) {return}
	s := &f.s
	named := false
	for text in s.runtime.live.text.text_blocks {named ||= text.original_text == "Компас"}
	testing.expect(t, named, "Cards have display names, not just semantic IDs")
}

@(test)
lab_shell_departure_is_a_guarded_intention_not_background_activation :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Settings) {return}
	s := &f.s; v, _ := s.runtime.content.(^Lab_Menu_Runtime)
	page_key(s, sdl.K_A, {.LCTRL}); page_text(s, "Draft")
	testing.expect(t, dispatch(s, {.Activate, "shell/catalogue", .Agent, false}))
	if !testing.expect(
		t,
		v.discard && s.model.page == .Lab_Settings,
		"Shell departure goes through draft guard",
	) {return}
	testing.expect(
		t,
		!dispatch(s, {.Activate, "shell/controls", .Agent, false}),
		"Upper decision blocks another departure",
	)
	testing.expect(t, dispatch(s, {.Activate, "lab/stay", .Agent, false}))
	target, _ := layout.find(&s.runtime.live.geometry, "shell/controls")
	x, y := target.bounds.x + 4, target.bounds.y + 4
	page_pointer(s, .MOUSE_BUTTON_DOWN, x, y); page_pointer(s, .MOUSE_BUTTON_UP, x, y)
	testing.expect(t, v.discard && s.model.page == .Lab_Settings)
	testing.expect(t, dispatch(s, {.Activate, "lab/discard", .Agent, false}))
	testing.expect(
		t,
		s.model.page == .Controls && s.model.lab_name.draft == s.model.lab_name.applied,
	)
}
import collections "ui:ui_collections"

@(test)
lab_catalogue_has_separate_group :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Catalogue, size = {800, 600}) {return}
	s := &f.s
	if !testing.expect(
		t,
		dispatch(s, {.Activate, "catalogue/lab", .Agent, false}),
		"A separate Lab group opens without adding height to the frozen gallery view",
	) {return}
	for id in ([]string{"lab-menu", "lab-settings", "lab-hud", "lab-inventory"}) {
		found := false
		for target in s.runtime.live.interaction.targets {found ||= target.description.id == id}
		testing.expect(t, found, id)
	}
	s.model.scale = 2; s.model.revision += 1
	testing.expect(t, rebuild(&s.runtime) && current(&s.runtime) && present(&s.runtime))
	testing.expect(t, dispatch(s, {.Activate, "catalogue/lab", .Agent, false}))
	testing.expect(t, len(model.SECTIONS) == 19)
}

@(test)
lab_inventory_native_navigation_and_wheel_have_one_region :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Inventory) {return}
	s := &f.s; v, _ := s.runtime.content.(^Lab_Inventory_Runtime)
	page_key(s, sdl.K_TAB)
	collection, _, valid := collections.decode_item_node_id(s.runtime.interaction.focus_id)
	testing.expect(
		t,
		valid && collection == "lab-right",
		"Tab visits each logical collection once",
	)
	page_key(s, sdl.K_DOWN)
	page_key(s, sdl.K_RETURN)
	testing.expect(t, s.model.lab_selected == "card-08")
	e: sdl.Event; e.wheel = {
		type     = .MOUSE_WHEEL,
		windowID = 17,
		y        = -4,
		mouse_x  = 20,
		mouse_y  = 180,
	}
	handle_input(s, e, {1280, 960})
	testing.expect(
		t,
		v.states[0].frame.collections[0].offset > 0 &&
		v.states[1].frame.collections[0].offset == 0,
	)
}

@(test)
lab_inventory_drop_waits_for_confirm :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Inventory) {return}
	s := &f.s
	id, ae := collections.item_node_id("lab-left", "card-01", context.allocator); defer delete(id)
	if !testing.expect(t, ae == nil && dispatch(s, {.Activate, id, .Agent, false})) {return}
	handle, _ := layout.find(&s.runtime.live.geometry, "lab/drag-handle")
	header, _ := layout.find(&s.runtime.live.geometry, "panel-right")
	x, y := handle.bounds.x + 8, handle.bounds.y + 8
	tx, ty := header.bounds.x + 8, header.bounds.y + 8
	page_pointer(s, .MOUSE_BUTTON_DOWN, x, y); page_pointer(s, .MOUSE_MOTION, x + 6, y)
	page_pointer(s, .MOUSE_MOTION, tx, ty); page_pointer(s, .MOUSE_BUTTON_UP, tx, ty)
	_, found := layout.find(&s.runtime.live.geometry, "lab/transfer-confirm")
	if !testing.expect(t, found, "Drop must open a confirmation in this same runtime") {return}
	testing.expect(t, s.inventory.panels[0].count == 6 && s.inventory.panels[1].count == 6)
	testing.expect(t, dispatch(s, {.Cancel, "", .Agent, false}))
	testing.expect(t, s.inventory.panels[0].count == 6)
	handle, _ = layout.find(&s.runtime.live.geometry, "lab/drag-handle")
	x, y = handle.bounds.x + 8, handle.bounds.y + 8
	page_pointer(s, .MOUSE_BUTTON_DOWN, x, y); page_pointer(s, .MOUSE_MOTION, x + 6, y)
	page_pointer(s, .MOUSE_MOTION, tx, ty); page_pointer(s, .MOUSE_BUTTON_UP, tx, ty)
	testing.expect(t, dispatch(s, {.Activate, "lab/transfer-confirm", .Agent, false}))
	testing.expect(
		t,
		s.inventory.panels[0].count == 5 &&
		s.inventory.panels[1].count == 7 &&
		s.inventory.panels[1].cards[6] == "card-01" &&
		s.model.lab_selected == "card-01",
	)
	count := s.inventory.revision
	dispatch(s, {.Activate, "lab/transfer-confirm", .Agent, false})
	testing.expect(t, s.inventory.revision == count && current(&s.runtime) && present(&s.runtime))
}
import layout "ui:ui_layout"
import sdl "vendor:sdl3"

@(test)
lab_inventory_reveal_select_handle :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Inventory) {return}
	s := &f.s; v, _ := s.runtime.content.(^Lab_Inventory_Runtime)
	x := collections.dispatch(
		&v.states[0],
		&s.runtime.interaction,
		{kind = .Scroll_To_Item, collection_id = "lab-left", item_id = "card-06", source = .Agent},
	)
	testing.expect(t, x.dispatch.code == .Applied && finish_input(s, s.model.page, true))
	id, ae := collections.item_node_id("lab-left", "card-06", context.allocator); defer delete(id)
	if !testing.expect(t, ae == nil) {return}
	testing.expect(t, dispatch(s, {.Activate, id, .Agent, false}))
	_, found := layout.find(&s.runtime.live.geometry, "lab/drag-handle")
	if !testing.expect(t, found, "Selection must expose a separate drag owner") {return}
	testing.expect(t, dispatch(s, {.Activate, "lab/reverse", .Agent, false}))
	testing.expect(t, current(&s.runtime) && present(&s.runtime))
}

@(test)
lab_inventory_two_lists :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Inventory) {return}
	s := &f.s
	_, left := layout.find(&s.runtime.live.geometry, "lab/left-viewport")
	_, right := layout.find(&s.runtime.live.geometry, "lab/right-viewport")
	if !testing.expect(
		t,
		left && right,
		"Inventory must compose both collections in one publisher",
	) {return}
	testing.expect(t, current(&s.runtime) && present(&s.runtime))
}

@(test)
lab_hud_composes_popup_tooltip_and_hold :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Hud) {return}
	s := &f.s
	_, found := layout.find(&s.runtime.live.geometry, "hud/restore")
	if !testing.expect(t, found, "HUD recipe needs the real hold target") {return}
	testing.expect(t, dispatch(s, {.Activate, "hud/minus", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "lab/popup", .Agent, false}))
	_, found = layout.find(&s.runtime.live.geometry, "lab/popup-panel")
	testing.expect(t, found && current(&s.runtime) && present(&s.runtime))
	testing.expect(t, dispatch(s, {.Cancel, "", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "lab/tooltip", .Agent, false}))
	testing.expect(t, current(&s.runtime) && present(&s.runtime))
}

@(test)
lab_settings_controls_are_draft :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Settings) {return}
	s := &f.s
	_, found := layout.find(&s.runtime.live.geometry, "lab/enabled")
	if !testing.expect(
		t,
		found,
		"Settings must combine editor with Bool and Integer owners",
	) {return}
	testing.expect(t, dispatch(s, {.Activate, "lab/enabled", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "lab/amount/increment", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "name/apply", .Agent, false}))
	shown := false
	for text in s.runtime.live.text.text_blocks {if text.node_id == "lab/shown-values" {shown = strings.contains(text.original_text, "51")}}
	testing.expect(
		t,
		shown && !s.model.lab_applied_enabled && s.model.lab_applied_amount == 50,
		"Confirmation shows the whole unapplied transaction",
	)
	testing.expect(t, dispatch(s, {.Activate, "lab/confirm", .Agent, false}))
	testing.expect(t, s.model.lab_applied_enabled && s.model.lab_applied_amount == 51)
	testing.expect(t, current(&s.runtime) && present(&s.runtime))
}

@(test)
lab_dirty_departure_guard :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Settings) {return}
	s := &f.s
	page_key(s, sdl.K_A, {.LCTRL}); page_text(s, "Draft")
	testing.expect(t, dispatch(s, {.Cancel, "", .Agent, false}))
	_, found := layout.find(&s.runtime.live.geometry, "lab/discard")
	if !testing.expect(t, found, "Dirty departure needs explicit discard decision") {return}
	testing.expect(t, dispatch(s, {.Activate, "lab/stay", .Agent, false}))
	testing.expect(t, s.model.lab_name.draft == "Draft")
	testing.expect(t, dispatch(s, {.Cancel, "", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "lab/discard", .Agent, false}))
	testing.expect(
		t,
		s.model.lab_name.draft == s.model.lab_name.applied &&
		s.runtime.interaction.focus_id == "lab/settings",
	)
}

@(test)
lab_direct_start :: proc(t: ^testing.T) {
	for id in ([]string{"lab-menu", "lab-settings", "lab-hud", "lab-inventory"}) {
		_, ok := parse_options([]string{"--font", "own.ttf", "--section", id})
		testing.expect(t, ok, id)
	}
}

@(test)
lab_settings_apply_is_confirmed_transaction :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Settings) {return}
	s := &f.s
	page_key(s, sdl.K_A, {.LCTRL}); page_text(s, "New name")
	testing.expect(
		t,
		s.model.lab_name.draft == "New name" && s.model.lab_name.applied == "Алексей",
	)
	testing.expect(t, dispatch(s, {.Activate, "name/apply", .Agent, false}))
	_, found := layout.find(&s.runtime.live.geometry, "lab/confirm")
	if !testing.expect(t, found, "Apply opens confirmation, never applies directly") {return}
	testing.expect(t, s.model.lab_name.applied == "Алексей")
	testing.expect(t, dispatch(s, {.Cancel, "", .Agent, false}))
	testing.expect(t, s.model.lab_name.draft == "New name")
	testing.expect(t, dispatch(s, {.Activate, "name/apply", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "lab/confirm", .Agent, false}))
	testing.expect(t, s.model.lab_name.applied == "New name")
	count := s.model.effects
	dispatch(s, {.Activate, "lab/confirm", .Agent, false})
	testing.expect(t, s.model.effects == count && current(&s.runtime) && present(&s.runtime))
}

@(test)
lab_menu_route :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Menu) {return}
	s := &f.s
	_, found := layout.find(&s.runtime.live.geometry, "lab/submenu")
	if !testing.expect(t, found, "Lab must compose a menu, not an empty gallery page") {return}
	testing.expect(t, dispatch(s, {.Activate, "lab/submenu", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "lab/settings", .Agent, false}))
	testing.expect(t, s.runtime.interaction.focus_id == "name/field")
	testing.expect(t, dispatch(s, {.Cancel, "", .Agent, false}))
	testing.expect(t, s.runtime.interaction.focus_id == "lab/settings")
}
