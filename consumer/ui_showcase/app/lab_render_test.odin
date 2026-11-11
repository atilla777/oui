package app

import "core:testing"
import layout "ui:ui_layout"
import backend "ui:ui_sdl"
import sdl "vendor:sdl3"

@(test)
lab_hidden_editor_never_paints_a_ghost_on_the_menu :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Menu) {return}
	s := &f.s
	for pass in 0 ..< 2 {
		if pass == 1 {
			testing.expect(t, dispatch(s, {.Activate, "lab/submenu", .Agent, false}))
			testing.expect(t, dispatch(s, {.Activate, "lab/settings", .Agent, false}))
			testing.expect(t, dispatch(s, {.Cancel, "", .Agent, false}))
		}
		node, found := layout.find(&s.runtime.live.geometry, "name/value")
		if !testing.expect(t, found && !node.visible) {return}
		status, has_status := layout.find(&s.runtime.live.geometry, "name/status")
		testing.expect(
			t,
			has_status && !status.visible,
			"Editor diagnostics belong to settings, not the closed menu",
		)
		testing.expect(
			t,
			sdl.SetRenderClipRect(s.renderer, nil) &&
			sdl.SetRenderDrawColor(s.renderer, 7, 13, 19, 255) &&
			sdl.RenderClear(s.renderer),
		)
		testing.expect(t, draw_leaf(&s.runtime.live, "name/value"))
		pixels, read := backend.readback(s.renderer, s.drawable)
		if !testing.expect(t, read) {return}
		changed := 0
		for y in 0 ..< int(pixels.h) {for x in 0 ..< int(pixels.w) {
				r, g, b, a: u8
				if !sdl.ReadSurfacePixel(pixels, i32(x), i32(y), &r, &g, &b, &a) ||
				   r != 7 ||
				   g != 13 ||
				   b != 19 ||
				   a != 255 {changed += 1}
			}}
		sdl.DestroySurface(pixels)
		testing.expect(
			t,
			changed == 0,
			"Hidden editor must leave every software-renderer pixel unchanged",
		)
	}
}
