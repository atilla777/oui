package app

import model "../model"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import "core:testing"
import collections "ui:ui_collections"
import layout "ui:ui_layout"
import scroll "ui:ui_scroll"
import backend "ui:ui_sdl"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

// G09: the normal page composition must expose its own editor and explicit
// application controls; catalogue metadata alone is not an implementation.
@(test)
g09_name_editor_is_an_actual_page :: proc(t: ^testing.T) {
	m := model.initial(); m.page = .Text_Input
	c: Page_Composition; defer destroy_composition(&c)
	if !testing.expect(t, compose_page(&c, m, context.allocator)) {return}
	field, apply, cancel := false, false, false
	for n in c.nodes[:c.n] {if n.id == "name/field" {field = true}}
	for target in c.targets[:c.ni] {
		if target.id == "name/apply" {apply = true}
		if target.id == "name/cancel" {cancel = true}
	}
	testing.expect(t, field && apply && cancel, "G09 requires a real field, Apply and Cancel")
}

Page_Fixture :: struct {
	s:        Shell,
	surface:  ^sdl.Surface,
	renderer: ^sdl.Renderer,
	font:     []u8,
}

@(test)
g10_g11_projection_reveals_text_not_only_empty_row_boxes :: proc(t: ^testing.T) {
	for page in ([2]model.Page{.Scroll_Table, .Collections}) {
		f: Page_Fixture; defer stop_page_fixture(&f)
		if !start_page_fixture(t, &f, page) {return}; s := &f.s
		id := "table/item-32/0"
		if page == .Scroll_Table {
			r := scroll.dispatch(
				&s.runtime.scroll,
				&s.runtime.interaction,
				{kind = .Focus, id = "table/item-32", source = .Agent},
			)
			testing.expect(t, r.code == .Applied && finish_input(s, page, true))
		} else {
			testing.expect(t, dispatch(s, {.Activate, "collections/end", .Agent, false}))
			id = "10:collection10:item-10000"
		}
		n, found := layout.find(&s.runtime.live.geometry, id)
		if !testing.expect(t, found && n.clip.h > 0) {return}
		painted := false
		for b in s.runtime.live.text.text_blocks {if b.node_id == id {for line in b.lines {painted ||= line.displayed && line.display_text != ""}}}
		testing.expect(
			t,
			painted,
			"revealed row must publish displayed text in the projected clip",
		)
		testing.expect(t, current(&s.runtime) && present(&s.runtime))
	}
}
start_page_fixture :: proc(
	t: ^testing.T,
	f: ^Page_Fixture,
	page: model.Page,
	ledger: ^backend.Resource_Ledger = nil,
	size: [2]i32 = {1280, 960},
	fallback: []u8 = nil,
	locale: model.Locale = .Russian,
	measurements_off := false,
	assets: string = "",
	alternate_assets: string = "",
) -> bool {
	if !testing.expect(t, ttf.Init()) {return false}
	f.surface = sdl.CreateSurface(size.x, size.y, .RGBA32)
	if !testing.expect(t, f.surface != nil) {return false}
	f.renderer = sdl.CreateSoftwareRenderer(f.surface)
	if !testing.expect(t, f.renderer != nil) {return false}
	e: os.Error; f.font, e = os.read_entire_file("resources/font.ttf", context.allocator)
	if !testing.expect(t, e == nil) {return false}
	f.s = {
		model = model.initial(),
		sources = {fallback = fallback, assets = assets, alternate_assets = alternate_assets},
		ledger = ledger,
		font_data = f.font,
		renderer = f.renderer,
		allocator = context.allocator,
		drawable = {f64(size.x), f64(size.y)},
	}
	f.s.model.page, f.s.model.locale, f.s.model.measurements_off =
		page, locale, measurements_off; f.s.input.window_id = 17
	return testing.expect(t, enter(&f.s))
}
stop_page_fixture :: proc(f: ^Page_Fixture) {
	destroy_shell(&f.s); delete(f.font)
	if f.renderer != nil {sdl.DestroyRenderer(f.renderer)}
	if f.surface != nil {sdl.DestroySurface(f.surface)}
	ttf.Quit()
}

@(test)
g10_ordinary_table_dataset_and_scroll_are_real :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Scroll_Table) {return}; s := &f.s
	if !testing.expect(
		t,
		len(s.runtime.scroll.frame.regions) == 1,
		"G10 owns one ordinary region",
	) {return}
	testing.expect(t, len(s.runtime.scroll.frame.regions[0].items) == 32)
	region := s.runtime.scroll.frame.regions[0]
	wheel: sdl.Event; wheel.wheel = {
		type     = .MOUSE_WHEEL,
		windowID = 17,
		y        = -1,
		mouse_x  = f32(region.viewport.x + 10),
		mouse_y  = f32(region.viewport.y + 10),
	}
	handle_input(s, wheel, {1280, 960})
	testing.expect(
		t,
		s.runtime.scroll.frame.regions[0].offset == 3 * region.items[0].height,
		"one wheel notch is three row heights",
	)
	testing.expect(t, dispatch(s, {.Activate, "table/dataset", .Agent, false}))
	testing.expect(t, len(s.runtime.scroll.frame.regions[0].items) == 33 && s.model.effects == 1)
	testing.expect(t, current(&s.runtime) && present(&s.runtime))
}

@(test)
g10_removed_selection_focus_successor_and_empty_fixture :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Scroll_Table) {return}; s := &f.s
	result := scroll.dispatch(
		&s.runtime.scroll,
		&s.runtime.interaction,
		{kind = .Focus, id = "table/item-05", source = .Agent},
	)
	testing.expect(t, result.code == .Applied && finish_input(s, .Scroll_Table, true))
	testing.expect(
		t,
		dispatch(s, {.Activate, "table/item-05", .Agent, false}) && s.model.table_selected == 6,
	)
	testing.expect(
		t,
		dispatch(s, {.Activate, "table/dataset", .Agent, false}) && s.model.table_selected == 6,
	)
	testing.expect(t, dispatch(s, {.Activate, "table/fixture", .Agent, false}))
	testing.expect(
		t,
		s.model.table_selected == 0 && s.runtime.interaction.focus_id == "table/item-06",
		"removed selection is cleared; focus chooses successor in old order",
	)
	for _ in 0 ..< 3 {testing.expect(t, dispatch(s, {.Activate, "table/fixture", .Agent, false}))}
	testing.expect(t, len(s.runtime.scroll.frame.regions[0].items) == 0 && current(&s.runtime))
}

@(test)
g11_virtual_end_reveal_materializes_the_last_item :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Collections) {return}; s := &f.s
	if !testing.expect(
		t,
		dispatch(s, {.Activate, "collections/end", .Agent, false}),
		"G11 real reveal control",
	) {return}
	last := false
	for block in s.runtime.live.text.text_blocks {if block.original_text == "item-10000" {last = true}}
	testing.expect(
		t,
		last && len(s.runtime.live.geometry.nodes) < 256,
		"offscreen logical item is revealed with bounded materialization",
	)
	testing.expect(t, current(&s.runtime) && present(&s.runtime))
}

@(test)
g11_lookup_focus_activation_reverse_delete_restore_and_grid_bounds :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Collections) {return}; s := &f.s
	n, _ := s.runtime.content.(^Collection_Page_Runtime)
	logical, code := collections.lookup_collection_item(&n.state.frame, "collection", "item-10000")
	testing.expect(
		t,
		code == .Applied &&
		logical.logical_ordinal == 9999 &&
		!logical.materialized &&
		logical.bounds == nil,
	)
	testing.expect(t, dispatch(s, {.Activate, "collections/reverse", .Agent, false}))
	result := collections.dispatch(
		&n.state,
		&s.runtime.interaction,
		{kind = .Focus, collection_id = "collection", item_id = "item-05000", source = .Agent},
	)
	testing.expect(t, result.dispatch.code == .Applied && finish_input(s, .Collections, true))
	id, ie := collections.item_node_id(
		"collection",
		"item-05000",
		context.allocator,
	); defer delete(id)
	if !testing.expect(t, ie == nil) {return}
	testing.expect(t, dispatch(s, {.Activate, id, .Agent, false}) && s.collection.selected == 5000)
	testing.expect(
		t,
		dispatch(s, {.Activate, "collections/delete", .Agent, false}) &&
		s.collection.count == 9999 &&
		s.collection.selected == 0,
	)
	_, code = collections.lookup_collection_item(
		&n.state.frame,
		"collection",
		"item-05000",
	); testing.expect(t, code == .Not_Found)
	testing.expect(
		t,
		dispatch(s, {.Activate, "collections/restore", .Agent, false}) &&
		s.collection.count == 10000,
	)
	testing.expect(t, dispatch(s, {.Activate, "collections/mode", .Agent, false}))
	for expected_columns in ([3]int{7, 6, 4}) {
		view := n.state.frame.collections[0]
		testing.expect(
			t,
			view.columns == expected_columns &&
			view.description.height == 32 &&
			view.description.gap == 4 &&
			view.description.card_width == 132 &&
			view.description.overscan_rows == 1,
		)
		testing.expect(
			t,
			view.materialized_count <= 10 * expected_columns &&
			len(s.runtime.live.geometry.nodes) < 256 &&
			current(&s.runtime) &&
			present(&s.runtime),
		)
		if expected_columns !=
		   4 {testing.expect(t, dispatch(s, {.Activate, "shell/scale", .Agent, false}))}
	}
}

@(test)
g13_restore_cannot_be_plain_activated :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Hud) {return}
	testing.expect(
		t,
		route(&f.s.runtime, {.Activate, "hud/restore", .Agent, false}) == .Activation_Required,
	)
	testing.expect(t, f.s.model.effects == 0)
}

@(test)
g13_clamped_delta_keeps_the_original_accepted_request_revision :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Hud) {return}
	for _ in 0 ..< 5 {testing.expect(t, dispatch(&f.s, {.Activate, "hud/plus", .Agent, false}))}
	testing.expect(t, f.s.model.hud_hp == 100 && f.s.model.effects == 5 && f.s.model.revision == 5)
}

@(test)
g12_nested_modal_guards_and_focus_return :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Layers) {return}; s := &f.s
	if !testing.expect(t, dispatch(s, {.Activate, "layers/open", .Agent, false})) {return}
	testing.expect(t, len(s.runtime.layers.frame.layers.modals) == 1)
	testing.expect(
		t,
		route(&s.runtime, {.Activate, "shell/catalogue", .Agent, false}) == .Blocked_By_Modal,
	)
	testing.expect(t, dispatch(s, {.Activate, "layers/open-b", .Agent, false}))
	testing.expect(t, len(s.runtime.layers.frame.layers.modals) == 2)
	testing.expect(t, dispatch(s, {.Cancel, "", .Agent, false}))
	testing.expect(t, len(s.runtime.layers.frame.layers.modals) == 1)
	testing.expect(t, dispatch(s, {.Cancel, "", .Agent, false}))
	testing.expect(
		t,
		len(s.runtime.layers.frame.layers.modals) == 0 &&
		current(&s.runtime) &&
		present(&s.runtime),
	)
}

@(test)
g12_scroll_popup_policy_and_tooltip_use_active_scope :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Layers) {return}; s := &f.s
	testing.expect(t, dispatch(s, {.Activate, "layers/open", .Agent, false}))
	region := s.runtime.scroll.frame.regions[1]
	e: sdl.Event; e.wheel = {
		type     = .MOUSE_WHEEL,
		windowID = 17,
		y        = -1,
		mouse_x  = f32(region.viewport.x + 10),
		mouse_y  = f32(region.viewport.y + 10),
	}
	handle_input(s, e, {1280, 960})
	testing.expect(
		t,
		s.runtime.scroll.frame.regions[1].offset == 84 &&
		s.runtime.scroll.frame.regions[0].offset == 0,
		"only the active scope scrolls",
	)
	testing.expect(t, dispatch(s, {.Activate, "layers/popup", .Agent, false}))
	testing.expect(t, len(s.runtime.layers.frame.layers.popups) == 1)
	testing.expect(t, dispatch(s, {.Cancel, "", .Agent, false}))
	testing.expect(
		t,
		len(s.runtime.layers.frame.layers.popups) == 0 &&
		len(s.runtime.layers.frame.layers.modals) == 1,
	)
	testing.expect(t, dispatch(s, {.Activate, "layers/policy", .Agent, false}))
	testing.expect(
		t,
		!dispatch(s, {.Cancel, "", .Agent, false}) &&
		len(s.runtime.layers.frame.layers.modals) == 1,
	)
	testing.expect(t, dispatch(s, {.Activate, "layers/tooltip", .Agent, false}))
	testing.expect(
		t,
		route(&s.runtime, {.Focus, "layers/tip-label", .Agent, false}) == .Non_Interactive_Overlay,
	)
	testing.expect(
		t,
		dispatch(s, {.Activate, "layers/close", .Agent, false}) && current(&s.runtime),
	)
}

@(test)
g13_native_999_plus_1_release_loss_and_failure_are_single_effect :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Hud) {return}; s := &f.s
	e: sdl.Event; e.key = {
		type     = .KEY_DOWN,
		windowID = 17,
		key      = sdl.K_SPACE,
	}
	testing.expect(t, handle_input(s, e, {1280, 960}))
	testing.expect(t, advance_page_clock(s, 100) && advance_page_clock(s, 1099))
	testing.expect(t, s.model.hud_count == 0 && s.model.effects == 0)
	testing.expect(t, advance_page_clock(s, 1100))
	testing.expect(t, s.model.hud_count == 1 && s.model.hud_hp == 100 && s.model.effects == 1)
	testing.expect(t, advance_page_clock(s, 5100) && s.model.effects == 1)
	e.key.type = .KEY_UP; handle_input(s, e, {1280, 960})
	e.key.type = .KEY_DOWN; handle_input(s, e, {1280, 960})
	advance_page_clock(s, 6000); advance_page_clock(s, 6999)
	e.key.type = .KEY_UP; handle_input(s, e, {1280, 960})
	advance_page_clock(s, 7000)
	testing.expect(t, s.model.effects == 1, "early release is never completion")
	e.key.type = .KEY_DOWN; handle_input(s, e, {1280, 960})
	loss: sdl.Event; loss.window = {
		type     = .WINDOW_FOCUS_LOST,
		windowID = 17,
	}
	handle_input(s, loss, {1280, 960}); advance_page_clock(s, 9000)
	testing.expect(t, s.model.effects == 1, "loss cancels and resets the clock")
}

@(test)
g14_cards_are_gesture_owned_not_plain_buttons :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Gestures) {return}
	testing.expect(
		t,
		route(&f.s.runtime, {.Activate, "gestures/card-01", .Agent, false}) ==
		.Activation_Required,
	)
	card :=
		false; for b in f.s.runtime.live.text.text_blocks {if b.original_text == "card-01" {card = true}}
	testing.expect(t, card, "G14 must paint its own card fixture")
}

@(test)
g14_active_drag_has_a_visible_frozen_preview :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Gestures) {return}; s := &f.s
	card, _ := layout.find(&s.runtime.live.geometry, "gestures/card-01")
	x, y := card.bounds.x + 20, card.bounds.y + 24
	page_pointer(s, .MOUSE_BUTTON_DOWN, x, y); page_pointer(s, .MOUSE_MOTION, x + 6, y)
	testing.expect(t, draw_reader(&s.runtime.live))
	pixels, captured := backend.readback(s.renderer, s.drawable)
	if !testing.expect(t, captured) {return}; defer sdl.DestroySurface(pixels)
	r, g, b, a: u8
	testing.expect(t, sdl.ReadSurfacePixel(pixels, i32(x + 6), i32(y), &r, &g, &b, &a))
	testing.expect(
		t,
		r == 255 && g == 218 && b == 110 && a == 255,
		fmt.tprintf(
			"active preview marker must be RGBA(255,218,110,255), observed=%d,%d,%d,%d",
			r,
			g,
			b,
			a,
		),
	)
}

page_pointer :: proc(s: ^Shell, kind: sdl.EventType, x, y: f64) -> bool {
	e: sdl.Event
	if kind == .MOUSE_MOTION {e.motion = {
			type     = kind,
			windowID = 17,
			x        = f32(x),
			y        = f32(y),
		}} else {e.button = {
			type     = kind,
			windowID = 17,
			button   = 1,
			x        = f32(x),
			y        = f32(y),
		}}
	return handle_input(s, e, {1280, 960})
}
@(test)
g14_native_threshold_drop_rejection_repeat_pan_and_editor :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Gestures) {return}; s := &f.s
	g, _ := s.runtime.content.(^Gesture_Page_Runtime)
	card, found := layout.find(
		&s.runtime.live.geometry,
		"gestures/card-01",
	); if !testing.expect(t, found) {return}
	x, y := card.bounds.x + 20, card.bounds.y + 24
	testing.expect(t, page_pointer(s, .MOUSE_BUTTON_DOWN, x, y) && g.state.live.phase == .Armed)
	testing.expect(t, page_pointer(s, .MOUSE_MOTION, x + 5, y) && g.state.live.phase == .Armed)
	testing.expect(t, page_pointer(s, .MOUSE_MOTION, x + 6, y) && g.state.live.phase == .Active)
	right, _ := layout.find(&s.runtime.live.geometry, "gestures/right-title")
	rx, ry := right.bounds.x + 30, right.bounds.y + 12
	testing.expect(t, page_pointer(s, .MOUSE_MOTION, rx, ry))
	testing.expect(t, page_pointer(s, .MOUSE_BUTTON_UP, rx, ry))
	advance_page_clock(s, 0); advance_page_clock(s, 1)
	testing.expect(
		t,
		s.gesture.panels[0].count == 5 && s.gesture.panels[1].count == 7 && s.model.effects == 1,
	)
	card, _ = layout.find(
		&s.runtime.live.geometry,
		"gestures/card-02",
	); x, y = card.bounds.x + 20, card.bounds.y + 24
	page_pointer(s, .MOUSE_BUTTON_DOWN, x, y); page_pointer(s, .MOUSE_MOTION, x + 6, y)
	left, _ := layout.find(&s.runtime.live.geometry, "gestures/left-title")
	lx, ly := left.bounds.x + 30, left.bounds.y + 12
	page_pointer(s, .MOUSE_MOTION, lx, ly)
	testing.expect(
		t,
		g.state.live.phase == .Active && g.state.live.target_id == "panel-left",
		fmt.tprintf("same-panel Move: %v", g.state.live),
	)
	page_pointer(s, .MOUSE_BUTTON_UP, lx, ly)
	advance_page_clock(s, 2); advance_page_clock(s, 3)
	testing.expect(
		t,
		g.outcome.reason == .Same_Panel && s.model.effects == 1,
		fmt.tprintf(
			"typed UI Drop outcome=%v, cycle=%d, effects=%d, result=%v",
			g.outcome,
			g.state.live.cycle,
			s.model.effects,
			g.state.result,
		),
	)
	testing.expect(t, dispatch(s, {.Focus, "gestures/right-down", .Agent, false}))
	e: sdl.Event; e.key = {
		type     = .KEY_DOWN,
		windowID = 17,
		key      = sdl.K_RETURN,
	}; handle_input(s, e, {1280, 960})
	advance_page_clock(s, 100); advance_page_clock(s, 499)
	testing.expect(t, s.runtime.scroll.frame.regions[1].offset == 24)
	advance_page_clock(s, 500); testing.expect(t, s.runtime.scroll.frame.regions[1].offset == 48)
	advance_page_clock(s, 600); testing.expect(t, s.runtime.scroll.frame.regions[1].offset == 72)
	e.key.type = .KEY_UP; handle_input(s, e, {1280, 960}); advance_page_clock(s, 700)
	testing.expect(
		t,
		s.model.effects == 1,
		"repeat is technical scrolling, not a second app effect",
	)
	testing.expect(t, dispatch(s, {.Focus, "name/field", .Agent, false}))
	page_key(s, sdl.K_A, sdl.KMOD_CTRL); page_text(s, "Editor")
	testing.expect(
		t,
		s.model.gesture_name.draft == "Editor" &&
		s.model.name.draft == "Алексей" &&
		s.model.effects == 2,
	)
	pan, _ := layout.find(&s.runtime.live.geometry, "gestures/right-pan")
	px, py := pan.bounds.x + 30, pan.bounds.y + 16
	before_pan := s.runtime.scroll.frame.regions[1].offset
	page_pointer(
		s,
		.MOUSE_BUTTON_DOWN,
		px,
		py,
	); page_pointer(s, .MOUSE_MOTION, px, py - 24); page_pointer(s, .MOUSE_BUTTON_UP, px, py - 24)
	advance_page_clock(s, 800); advance_page_clock(s, 900)
	testing.expect(
		t,
		s.runtime.scroll.frame.regions[1].offset == before_pan + 24 && s.model.effects == 2,
		"pan has one offset owner and no inertia",
	)
	testing.expect(t, dispatch(s, {.Focus, "gestures/card-02", .Agent, false}))
	page_key(s, sdl.K_RETURN); page_key(s, sdl.K_TAB); page_key(s, sdl.K_ESCAPE)
	testing.expect(
		t,
		g.state.live.phase == .Idle && s.model.effects == 2,
		"keyboard aim/cancel never drops",
	)
	s.input.gamepad_id = 9
	pad: sdl.Event; pad.gbutton = {
		type   = .GAMEPAD_BUTTON_DOWN,
		which  = 9,
		button = u8(sdl.GamepadButton.SOUTH),
	}
	handle_input(
		s,
		pad,
		{1280, 960},
	); pad.gbutton.type = .GAMEPAD_BUTTON_UP; handle_input(s, pad, {1280, 960})
	for _ in 0 ..< 2 {pad.gbutton.type, pad.gbutton.button = .GAMEPAD_BUTTON_DOWN, u8(sdl.GamepadButton.DPAD_RIGHT); handle_input(s, pad, {1280, 960}); pad.gbutton.type = .GAMEPAD_BUTTON_UP; handle_input(s, pad, {1280, 960})}
	pad.gbutton.type, pad.gbutton.button =
		.GAMEPAD_BUTTON_DOWN,
		u8(
			sdl.GamepadButton.SOUTH,
		); handle_input(s, pad, {1280, 960}); pad.gbutton.type = .GAMEPAD_BUTTON_UP; handle_input(s, pad, {1280, 960})
	testing.expect(
		t,
		s.gesture.panels[0].count == 4 && s.gesture.panels[1].count == 8 && s.model.effects == 3,
		"normalized gamepad aim/end shares the reducer",
	)
	testing.expect(t, current(&s.runtime) && present(&s.runtime))
}
page_key :: proc(s: ^Shell, key: sdl.Keycode, mods: sdl.Keymod = {}) {
	e: sdl.Event; e.key = {
		type     = .KEY_DOWN,
		windowID = 17,
		key      = key,
		mod      = mods,
	}
	handle_input(s, e, {1280, 960}); e.key.type = .KEY_UP; handle_input(s, e, {1280, 960})
}
page_text :: proc(s: ^Shell, text: cstring) {
	e: sdl.Event; e.text = {
		type     = .TEXT_INPUT,
		windowID = 17,
		text     = text,
	}
	handle_input(s, e, {1280, 960})
}

Clipboard_Fixture :: struct {
	buffer:             [65536]u8,
	count:              int,
	fail_get, fail_set: bool,
}
clipboard_get :: proc(a: mem.Allocator, user: rawptr) -> (string, bool) {
	c := cast(^Clipboard_Fixture)user; if c.fail_get {return "", false}
	value, e := strings.clone(string(c.buffer[:c.count]), a); return value, e == nil
}
clipboard_set :: proc(value: string, user: rawptr) -> bool {
	c := cast(^Clipboard_Fixture)user; if c.fail_set || len(value) > len(c.buffer) {return false}
	c.count = copy(c.buffer[:], transmute([]u8)value); return true
}
@(test)
g09_clipboard_refusal_is_visible_and_cut_is_atomic :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Text_Input) {return}; s := &f.s
	n, _ := active_name(&s.runtime); clip: Clipboard_Fixture
	n.input.clipboard = {
		get  = clipboard_get,
		set  = clipboard_set,
		user = &clip,
	}
	page_key(s, sdl.K_A, sdl.KMOD_CTRL); page_key(s, sdl.K_C, sdl.KMOD_CTRL)
	testing.expect(t, string(clip.buffer[:clip.count]) == "Алексей" && s.model.effects == 0)
	clip.fail_set = true; page_key(s, sdl.K_X, sdl.KMOD_CTRL)
	testing.expect(t, s.model.name.draft == "Алексей" && s.model.effects == 0)
	visible :=
		false; for b in s.runtime.live.text.text_blocks {if b.node_id == "name/status" && strings.contains(b.original_text, "Буфер") {visible = true}}
	testing.expect(
		t,
		visible,
		"native clipboard refusal must be visible, not success or only a log",
	)
	clip.fail_set = false; page_key(s, sdl.K_X, sdl.KMOD_CTRL)
	testing.expect(t, s.model.name.draft == "" && s.model.effects == 1)
	page_key(s, sdl.K_V, sdl.KMOD_CTRL)
	testing.expect(
		t,
		s.model.name.draft == "Алексей" &&
		s.model.effects == 2 &&
		s.model.name.applied == "Алексей",
	)
	clip.fail_get = true; page_key(s, sdl.K_V, sdl.KMOD_CTRL)
	testing.expect(t, s.model.effects == 2 && current(&s.runtime))
}

Text_Lifecycle_Fixture :: struct {
	starts, stops: int,
	fail_stop:     bool,
}
text_start :: proc(_: ^sdl.Window, user: rawptr) -> bool {s := cast(^Text_Lifecycle_Fixture)user
	s.starts += 1
	return true}
text_stop :: proc(_: ^sdl.Window, user: rawptr) -> bool {s := cast(^Text_Lifecycle_Fixture)user
	s.stops += 1
	return !s.fail_stop}
text_size :: proc(_: ^sdl.Window, _: rawptr) -> (i32, i32, bool) {return 1280, 960, true}
text_area :: proc(_: ^sdl.Window, _: sdl.Rect, _: i32, _: rawptr) -> bool {return true}
@(test)
g09_stop_text_failure_preserves_owner_for_explicit_retry :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Text_Input) {return}; s := &f.s
	n, _ := active_name(&s.runtime); native: Text_Lifecycle_Fixture
	n.input.lifecycle = {
		start = text_start,
		stop  = text_stop,
		size  = text_size,
		area  = text_area,
		user  = &native,
	}
	testing.expect(t, sync_name(s) && n.input.text_active && native.starts == 1)
	native.fail_stop = true
	testing.expect(t, !dispatch(s, {.Activate, "shell/controls", .Agent, false}))
	testing.expect(
		t,
		s.model.page == .Controls &&
		s.runtime.page == .Text_Input &&
		n.input.text_active &&
		!current(&s.runtime),
	)
	effects := s.model.effects
	native.fail_stop = false
	loss: sdl.Event; loss.window = {
		type     = .WINDOW_FOCUS_LOST,
		windowID = 17,
	}
	handle_input(s, loss, {1280, 960})
	testing.expect(
		t,
		n.input.text_active && native.stops == 1,
		"ordinary loss must not silently retry an already failed close",
	)
	testing.expect(t, recover(s) && current(&s.runtime) && s.runtime.page == .Controls)
	testing.expect(
		t,
		native.starts == 1 &&
		native.stops == 2 &&
		s.model.effects == effects &&
		s.model.name.applied == "Алексей",
	)
}

@(test)
g09_native_editor_allocation_refusal_is_not_success :: proc(t: ^testing.T) {
	fault := Allocation_Fault {
		backing = context.allocator,
	}
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Text_Input) {return}
	destroy_shell(&f.s); f.s.allocator = {refuse_allocation, &fault}; f.s.input.window_id = 17
	if !testing.expect(t, enter(&f.s)) {return}
	fault.requests, fault.refuse = 0, 1
	page_text(&f.s, "!")
	testing.expect(
		t,
		!f.s.runtime.publication.ready &&
		f.s.model.effects == 0 &&
		f.s.model.name.draft == "Алексей",
		"allocation refusal must block without claiming a successful edit",
	)
	fault.refuse = 0
	testing.expect(t, recover(&f.s) && current(&f.s.runtime) && f.s.model.effects == 0)
}

@(test)
g11_g13_g14_current_reader_checks_selected_family_stamps :: proc(t: ^testing.T) {
	for page in ([3]model.Page{.Collections, .Hud, .Gestures}) {
		f: Page_Fixture; defer stop_page_fixture(&f)
		if !start_page_fixture(t, &f, page) {return}; r := &f.s.runtime
		if c, ok := r.live.content.(Collection_Page_Reader);
		   ok {c.frame.stamp.model_revision += 1; r.live.content = c}
		if c, ok := r.live.content.(Hold_Page_Reader);
		   ok {c.frame.stamp.model_revision += 1; r.live.content = c}
		if c, ok := r.live.content.(Gesture_Page_Reader);
		   ok {c.frame.stamp.model_revision += 1; r.live.content = c}
		testing.expect(
			t,
			!current(r),
			"a matching common frame cannot authorize a mismatched selected family",
		)
	}
}
@(test)
g09_egc_empty_refusal_apply_cancel_and_failure :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Text_Input) {return}; s := &f.s
	page_key(s, sdl.K_A, sdl.KMOD_CTRL)
	page_text(s, "е́")
	testing.expect(
		t,
		s.model.name.draft == "е́" &&
		s.model.name.applied == "Алексей" &&
		s.model.effects == 1,
	)
	page_key(s, sdl.K_BACKSPACE)
	testing.expect(
		t,
		s.model.name.draft == "" && s.model.effects == 2,
		"one Backspace removes the entire EGC",
	)
	page_key(s, sdl.K_RETURN)
	testing.expect(
		t,
		current(&s.runtime) && s.model.name.applied == "Алексей" && s.model.effects == 2,
		"empty Submit refuses without blocking or applying",
	)
	page_text(s, "Имя")
	page_key(s, sdl.K_RETURN)
	testing.expect(t, s.model.name.applied == "Имя" && s.model.effects == 4)
	before := s.model.effects
	page_text(s, "bad\nwhole")
	testing.expect(
		t,
		s.model.name.draft == "Имя" && s.model.effects == before,
		"whole insertion refusal",
	)
	page_key(s, sdl.K_A, sdl.KMOD_CTRL)
	page_text(s, "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklm")
	testing.expect(
		t,
		s.model.name.draft == "Имя" && s.model.effects == before,
		"65 EGC refuse atomically",
	)
	page_text(s, "Name")
	page_key(s, sdl.K_ESCAPE)
	testing.expect(t, s.model.name.draft == "Имя" && s.model.name.applied == "Имя")
	s.runtime.fault = .Copy
	page_text(s, "!")
	accepted := s.model.effects
	testing.expect(t, !s.runtime.publication.ready)
	testing.expect(t, recover(s) && current(&s.runtime) && s.model.effects == accepted)
	reader, copied := copy_reader(&s.runtime.live, context.allocator)
	if testing.expect(t, copied) {
		defer destroy_reader(&reader)
		testing.expect(
			t,
			destroy_shell(s) && draw_reader(&reader),
			"owning historical editor remains readable",
		)
	}
}

@(test)
g09_committed_input_is_a_controlled_effect :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	surface := sdl.CreateSurface(1280, 960, .RGBA32)
	if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(surface)
	if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
	data, e := os.read_entire_file("resources/font.ttf", context.allocator)
	if !testing.expect(t, e == nil) {return}; defer delete(data)
	s := Shell {
		model     = model.initial(),
		font_data = data,
		renderer  = renderer,
		allocator = context.allocator,
		drawable  = {1280, 960},
	}
	s.model.page = .Text_Input
	defer destroy_shell(&s)
	if !testing.expect(t, enter(&s)) {return}
	event := sdl.Event {
		type = .TEXT_INPUT,
	}; event.text.text = "я"
	testing.expect(t, handle_input(&s, event, {1280, 960}))
	testing.expect(
		t,
		s.model.effects == 1 && s.model.revision == 1,
		"committed insertion has exactly one controlled application effect",
	)
	testing.expect(t, current(&s.runtime) && present(&s.runtime))
}
