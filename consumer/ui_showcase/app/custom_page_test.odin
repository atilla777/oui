package app

import "core:fmt"
import "core:testing"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"

@(test)
g16_tooltip_text_does_not_overprint_the_shell_heading :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Custom) {return}
	testing.expect(t, dispatch(&f.s, {.Activate, "custom/tooltip", .Agent, false}))
	n, found := layout.find(&f.s.runtime.live.geometry, "custom/tooltip-root")
	testing.expect(
		t,
		found && n.bounds.y >= 440 && n.bounds.y + n.bounds.h <= f.s.runtime.drawable.h,
		"tooltip needs a readable reserved position, not text on top of the shell title",
	)
	testing.expect(t, present(&f.s.runtime))
}

@(test)
g16_custom_page_uses_circle_hit_and_semantic_owner :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(
		t,
		&f,
		.Custom,
	) {fmt.eprintf("custom page fault=%v diagnostic=%v\n", f.s.runtime.error, f.s.runtime.diagnostic); return}; s := &f.s
	n, found := layout.find(&s.runtime.live.geometry, "node:4:left7:content6:circle")
	if !testing.expect(t, found, "G16 requires a real custom circle") {return}
	_, corner := hit_pointer(&s.runtime, n.bounds.x + 1, n.bounds.y + 1)
	target, center := hit_pointer(
		&s.runtime,
		n.bounds.x + n.bounds.w / 2,
		n.bounds.y + n.bounds.h / 2,
	)
	testing.expect(
		t,
		corner != .Applied &&
		center == .Applied &&
		target.description.id == "node:4:left7:content6:circle",
	)
	testing.expect(t, dispatch(s, {.Activate, "node:4:left7:content6:circle", .Agent, false}))
	base, _ := interaction.find(&s.runtime.interaction.frame, "node:4:left7:content6:circle")
	testing.expect(t, base.activation_owner == "custom")
	testing.expect(t, present(&s.runtime))
}

@(test)
g16_native_circle_edges_and_cold_return :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Custom) {return}; s := &f.s
	n, _ := layout.find(&s.runtime.live.geometry, "node:4:left7:content6:circle")
	x, y := n.bounds.x + 36, n.bounds.y + 36
	page_pointer(s, .MOUSE_BUTTON_DOWN, n.bounds.x + 1, n.bounds.y + 1)
	page_pointer(s, .MOUSE_BUTTON_UP, x, y)
	testing.expect(t, s.model.custom_counts[0] == 0)
	page_pointer(s, .MOUSE_BUTTON_DOWN, x, y)
	page_pointer(s, .MOUSE_BUTTON_UP, x, y)
	testing.expect(t, s.model.custom_counts[0] == 1 && s.model.custom_counts[1] == 0)
	testing.expect(t, dispatch(s, {.Activate, "custom/style", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "custom/slot", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "custom/tooltip", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "custom/popup", .Agent, false}))
	testing.expect(t, dispatch(s, {.Activate, "shell/catalogue", .Agent, false}))
	for _ in 0 ..< 7 {testing.expect(t, dispatch(s, {.Activate, "catalogue/next", .Agent, false}))}
	testing.expect(t, dispatch(s, {.Activate, "custom", .Agent, false}))
	c, selected := s.runtime.content.(^Custom_Page_Runtime)
	testing.expect(t, selected && !c.popup && !c.tooltip)
	testing.expect(
		t,
		s.model.custom_counts[0] == 1 && s.model.custom_style && s.model.custom_slot_absent,
	)
	testing.expect(t, dispatch(s, {.Activate, "custom/disabled", .Agent, false}))
	before := s.model
	testing.expect(
		t,
		!dispatch(s, {.Activate, "node:4:left7:content6:circle", .Agent, false}) &&
		before == s.model,
	)
}
