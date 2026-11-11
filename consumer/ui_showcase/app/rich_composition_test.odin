package app

import "core:os"
import "core:testing"
import layout "ui:ui_layout"

@(test)
c07_real_host_clock_has_no_implicit_hold_owner :: proc(t: ^testing.T) {
	fallback, e := os.read_entire_file("resources/fallback.ttf", context.allocator)
	if !testing.expect(t, e == nil) {return}; defer delete(fallback)
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Rich_Text, fallback = fallback) {return}
	testing.expect(
		t,
		advance_page_clock(&f.s, 1000) && advance_page_clock(&f.s, 1016) && present(&f.s.runtime),
	)
}

@(test)
c07_rich_custom_transition_share_current_and_historical_reader :: proc(t: ^testing.T) {
	fallback, e := os.read_entire_file("resources/fallback.ttf", context.allocator)
	if !testing.expect(t, e == nil) {return}; defer delete(fallback)
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Rich_Text, fallback = fallback) {return}
	s := &f.s
	_, found := layout.find(&s.runtime.live.geometry, "rich/circle")
	if !testing.expect(t, found, "C07 must be an actual rich + custom + transitions page") {return}
	testing.expect(t, present(&s.runtime))
	testing.expect(t, dispatch(s, {.Activate, "rich/limit", .Agent, false}))
	v, selected := active_transition(&s.runtime)
	if !testing.expect(t, selected) {return}
	v.step = {
		kind = .Finish_All,
	}
	testing.expect(t, rebuild(&s.runtime) && present(&s.runtime))
	g := frozen_geometry(&s.runtime.live, "rich/circle")
	testing.expect(t, g.offset[0] == 30)
	n, _ := layout.find(&s.runtime.live.geometry, "rich/circle")
	_, corner := hit_pointer(&s.runtime, n.bounds.x + g.offset[0] + 1, n.bounds.y + 1)
	testing.expect(t, corner != .Applied, "custom corner uses the frozen inverse, not the box")
	before := s.model.effects
	page_pointer(s, .MOUSE_BUTTON_DOWN, n.bounds.x + g.offset[0] + 36, n.bounds.y + 36)
	page_pointer(s, .MOUSE_BUTTON_UP, n.bounds.x + g.offset[0] + 36, n.bounds.y + 36)
	testing.expect(t, s.model.effects == before + 1)
	old, copied := copy_reader(&s.runtime.live, s.allocator)
	if !testing.expect(t, copied) {return}; defer destroy_reader(&old)
	testing.expect(
		t,
		dispatch(s, {.Activate, "shell/catalogue", .Agent, false}) && draw_reader(&old),
	)
}
