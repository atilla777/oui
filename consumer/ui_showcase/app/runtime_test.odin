package app

import model "../model"
import "core:mem"
import "core:os"
import "core:testing"
import base "ui:ui_base"
import layout "ui:ui_layout"
import backend "ui:ui_sdl"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

@(test)
publication_geometry_and_release :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	surface := sdl.CreateSurface(800, 600, .RGBA32)
	if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	renderer := sdl.CreateSoftwareRenderer(surface)
	if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
	data, e := os.read_entire_file("resources/font.ttf", context.allocator)
	if !testing.expect(t, e == nil) {return}; defer delete(data)
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	a := mem.tracking_allocator(&tracking)
	ledger: backend.Resource_Ledger
	for page in ([4]model.Page{.Catalogue, .Layout, .Controls, .Profiles}) {
		m := model.initial(); m.page = page; m.scale = 2
		r: Runtime
		if !testing.expect(t, init(&r, renderer, data, &m, a, &ledger)) {continue}
		r.drawable = {800, 600}
		if testing.expect(t, rebuild(&r)) {
			testing.expect(
				t,
				base.is_current(&r.publication, r.live.text.stamp) && m.revision == 0,
			)
			expected := "shell/layout"; if page == .Layout {expected = "shell/controls"}; if page == .Controls {expected = "controls/checkbox"}
			if page == .Profiles {expected = "profiles/help"}
			testing.expect(t, r.interaction.focus_id == expected)
			if page == .Layout {
				row_a, _ := layout.find(
					&r.live.geometry,
					"layout/row-a",
				); row_b, _ := layout.find(&r.live.geometry, "layout/row-b")
				testing.expect(
					t,
					row_a != nil &&
					row_b != nil &&
					row_a.bounds.x < row_b.bounds.x &&
					row_a.bounds.y == row_b.bounds.y,
				)
				col_a, _ := layout.find(
					&r.live.geometry,
					"layout/column-a",
				); col_b, _ := layout.find(&r.live.geometry, "layout/column-b")
				testing.expect(t, col_a != nil && col_b != nil && col_a.bounds.y < col_b.bounds.y)
				parent, _ := layout.find(
					&r.live.geometry,
					"layout/absolute",
				); anchor, _ := layout.find(&r.live.geometry, "layout/anchored")
				testing.expect(
					t,
					anchor.bounds.x + anchor.bounds.w == parent.content.x + parent.content.w - 2,
				)
				clip, _ := layout.find(&r.live.geometry, "layout/clipped")
				testing.expect(t, clip.paint_clip.w < clip.bounds.w)
			}
			baseline := tracking.current_memory_allocated
			for _ in 0 ..< 8 {testing.expect(t, rebuild(&r))}
			testing.expect(t, tracking.current_memory_allocated == baseline)
		}
		destroy(&r)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 &&
			len(tracking.bad_free_array) == 0 &&
			ledger.live == 0,
		)
	}
}
