package app

import model "../model"
import "core:os"
import "core:testing"
import base "ui:ui_base"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

@(test)
software_matrix_failure_recovery_and_history :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	data, e := os.read_entire_file(
		"resources/font.ttf",
		context.allocator,
	); if !testing.expect(t, e == nil) {return}; defer delete(data)
	for size in ([][2]i32{{800, 600}, {960, 720}}) {
		surface := sdl.CreateSurface(
			size[0],
			size[1],
			.RGBA32,
		); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
		renderer := sdl.CreateSoftwareRenderer(
			surface,
		); if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
		for page in ([4]model.Page{.Catalogue, .Layout, .Controls, .Profiles}) {for locale in model.Locale {for scale in ([]f64{1, 1.5, 2}) {for pixel in ([]bool{false, true}) {
						if pixel && scale == 1.5 {continue}
						m := model.initial()
						m.page, m.locale = page, locale
						m.scale, m.pixel_perfect = scale, pixel
						r: Runtime; if !testing.expect(t, init(&r, renderer, data, &m, context.allocator)) {continue}; defer destroy(&r)
						r.drawable = {f64(size[0]), f64(size[1])}
						if !testing.expect(t, rebuild(&r)) {continue}
						if page == .Layout {
							clip, found := layout.find(&r.live.geometry, "layout/clipped")
							testing.expect(t, found && clip.bounds.w > clip.paint_clip.w)
							testing.expect(t, len(r.live.geometry.diagnostics) == 1)
							for d in r.live.geometry.diagnostics {testing.expect(t, d.id == "layout/clipped" && d.kind == .Container_Overflow)}
							_, outside := interaction.hit_test(
								&r.live.interaction,
								(clip.paint_clip.x + clip.paint_clip.w + 2) * scale,
								(clip.bounds.y + 10) * scale,
							)
							testing.expect(t, outside != .Applied)
							target, inside := interaction.hit_test(
								&r.live.interaction,
								(clip.paint_clip.x + 5) * scale,
								(clip.bounds.y + 10) * scale,
							)
							testing.expect(
								t,
								inside == .Applied && target.description.id == "layout/clipped",
							)
							ga, _ := layout.find(
								&r.live.geometry,
								"layout/grid-a",
							); gb, _ := layout.find(&r.live.geometry, "layout/grid-b")
							testing.expect(
								t,
								ga.bounds.x < gb.bounds.x && ga.bounds.y < gb.bounds.y,
							)
							top, _ := layout.find(
								&r.live.geometry,
								"layout/top",
							); bottom, _ := layout.find(&r.live.geometry, "layout/bottom")
							testing.expect(
								t,
								top.bounds.x >= bottom.bounds.x &&
								top.bounds.y >= bottom.bounds.y &&
								top.bounds.x + top.bounds.w <= bottom.bounds.x + bottom.bounds.w,
							)
						}
						testing.expect(t, present(&r))
						testing.expect(t, interaction.ready(&r.interaction))
						when TEST {
							for fault in ([]Fault{.Prepare, .Resource, .Copy, .Publish, .Render, .Readback, .Present}) {
								before := m; old := r.live.text.stamp; r.fault = fault
								if fault <=
								   .Publish {testing.expect(t, !rebuild(&r) && r.live.text.stamp == old)} else {testing.expect(t, !present(&r))}
								testing.expect(
									t,
									!r.publication.ready && m == before && !present(&r),
								)
								testing.expect(
									t,
									interaction.dispatch(&r.interaction, {.Activate, "shell/language", .Agent, false}).code ==
									.Not_Ready,
								)
								testing.expect(t, rebuild(&r) && present(&r) && m == before)
							}
						}
						reader, ok := copy_reader(
							&r.live,
							context.allocator,
						); if !testing.expect(t, ok) {continue}
						stamp := reader.text.stamp; destroy(&r)
						testing.expect(
							t,
							!base.is_current(&r.publication, stamp) && draw_reader(&reader),
						)
						destroy_reader(&reader)
					}}}}
	}
}
