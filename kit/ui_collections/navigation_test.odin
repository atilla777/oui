package ui_collections

import "core:testing"

@(test)
logical_navigation_skips_disabled_and_does_not_cross_grid_row :: proc(t: ^testing.T) {
	items := [6]Collection_Item {
		{"a", "A", true, true, ""},
		{"b", "B", true, false, "locked"},
		{"c", "C", true, true, ""},
		{"d", "D", true, true, ""},
		{"e", "E", true, true, ""},
		{"f", "F", true, true, ""},
	}
	d := fixture_description(items[:]); d.mode = .Grid; d.card_width = 10
	f, e := prepare_collection(d, {w = 24, h = 10}, 0); defer destroy_frame(&f)
	if !testing.expect(t, e.code == .None) {return}
	id, code := move_item(&f, "list", "a", .Down)
	testing.expect(t, code == .Applied && id == "c")
	id, code = move_item(&f, "list", "a", .Right)
	testing.expect(t, code == .Applied && id == "a")
	a, status := reveal_action(&f, "list", "f", .Agent)
	testing.expect(t, status == .Applied && a.delta_y == 24 && a.id == "scroll")
}
