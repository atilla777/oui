package app

import "core:testing"
import layout "ui:ui_layout"

@(test)
g19_world_has_numeric_anchor_and_real_camera_controls :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .World) {return}; s := &f.s
	a, found := layout.find(&s.runtime.live.geometry, "world/a")
	if !testing.expect(t, found, "G19 must place A in the real page") {return}
	// 1280x960: viewport(32,160,1216,768), center(640,544),
	// card112x48 + offset(0,-12), pivot(.5,1).
	testing.expect(t, a.bounds == layout.Rect{584, 484, 112, 48})
	testing.expect(t, dispatch(s, {.Activate, "world/camera-right", .Agent, false}))
	a, found = layout.find(&s.runtime.live.geometry, "world/a")
	testing.expect(t, found && a.bounds == layout.Rect{520, 484, 112, 48})
	testing.expect(t, dispatch(s, {.Activate, "world/zoom", .Agent, false}))
	a, found = layout.find(&s.runtime.live.geometry, "world/a")
	testing.expect(t, found && a.bounds == layout.Rect{456, 484, 112, 48})
	testing.expect(t, present(&s.runtime))
}

@(test)
g19_world_policies_keep_screen_fixed_progress_and_direction :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .World) {return}; s := &f.s
	bar, found := layout.find(&s.runtime.live.geometry, "world/a-progress")
	testing.expect(
		t,
		found && bar.bounds.w == 84 && bar.bounds.h == 8,
		"75/100 progress in the fixed 112-unit card",
	)
	for _ in 0 ..< 2 {testing.expect(t, dispatch(s, {.Activate, "world/policy", .Agent, false}))}
	b, visible := layout.find(&s.runtime.live.geometry, "world/b")
	testing.expect(t, visible && b.visible && b.bounds == layout.Rect{1224, 532, 24, 24})
	triangle := false
	for p in s.runtime.live.paint.presentation {if p.id == "world/b" {triangle = p.visual.kind == .Triangle}}
	testing.expect(
		t,
		triangle,
		"Direction must paint an oriented triangle, not a placeholder label",
	)
}
