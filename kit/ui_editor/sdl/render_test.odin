package ui_editor_sdl
import editor ".."
import base "../../ui_base"
import interaction "../../ui_interaction"
import layout "../../ui_layout"
import backend "../../ui_sdl"
import fonts "../../ui_sdl_text"
import text "../../ui_text"
import "core:os"
import "core:testing"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

@(test)
real_ru_en_editor_painter_uses_one_font_owner_and_restores_renderer :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	data, read := os.read_entire_file("resources/font.ttf", context.allocator)
	if !testing.expect(t, read == nil) {return}; defer delete(data)
	for scale in ([3]f64{1, 1.5, 2}) {
		surface := sdl.CreateSurface(i32(200 * scale), i32(100 * scale), .RGBA32)
		if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
		renderer := sdl.CreateSoftwareRenderer(
			surface,
		); if !testing.expect(t, renderer != nil) {return}; defer sdl.DestroyRenderer(renderer)
		ledger: backend.Resource_Ledger
		g, ge := fonts.create_generation(
			renderer,
			"font-v1",
			[]fonts.Font_Source{{"font", 16, data}},
			scale,
			context.allocator,
			&ledger,
		)
		if !testing.expect(t, ge.code == .None) {return}; defer fonts.release_generation(&g)
		for value in ([2]string{"Name / a\u0301", "Имя / е\u0301"}) {
			p, _ := base.create(context.allocator); defer base.destroy(&p)
			ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
			s := editor.create(); defer editor.destroy(&s)
			stamp, _ := base.begin_attempt(&p, 1)
			nodes := [2]layout.Node {
				{
					id = "field",
					role = .Stack,
					enabled = true,
					visible = true,
					layout = layout.Layout {
						x = {mode = .Fixed, value = 180},
						y = {mode = .Fixed, value = 30},
					},
				},
				{
					id = "value",
					parent = "field",
					role = .Content,
					enabled = true,
					visible = true,
					layout = layout.Layout {
						x = {mode = .Fixed, value = 180},
						y = {mode = .Fixed, value = 30},
					},
				},
			}
			tc, te := text.prepare(
				[]text.Text_Node{{id = "value", text = value, font = {"font"}, font_size = 16}},
				nodes[:],
				{drawable = {200 * scale, 100 * scale}, ui_scale = scale},
				fonts.metrics(g),
				context.allocator,
				stamp,
			)
			if !testing.expect(t, te.code == .None) {return}; defer text.destroy_candidate(&tc)
			i, ie := interaction.prepare(
				&tc.geometry,
				[]interaction.Target{{"field", "editor", true, true}},
				nil,
				context.allocator,
			)
			if !testing.expect(t, ie == .Applied) {return}; defer interaction.destroy_frame(&i)
			c, ce := editor.prepare(
				&s,
				&tc.geometry,
				&i,
				&tc.text,
				[]editor.Description {
					{
						id = "name",
						node_id = "field",
						text_node_id = "value",
						value = value,
						revision = 1,
					},
				},
				fonts.metrics(g),
			)
			if !testing.expect(t, ce.code == .None) {return}; defer editor.destroy_candidate(&c)
			if !testing.expect(t, base.enter_commit(&p, stamp) == .None) {return}
			interaction.commit(
				&ctx,
				&i,
				"field",
			); editor.commit(&s, &c); base.finish_commit(&p, stamp)
			sdl.SetRenderDrawColor(renderer, 10, 20, 30, 255); sdl.RenderClear(renderer)
			sdl.SetRenderScale(
				renderer,
				0.75,
				1.25,
			); sdl.SetRenderDrawColor(renderer, 7, 8, 9, 200)
			before, saved := backend.save_renderer_state(renderer); testing.expect(t, saved)
			if !testing.expect(t, matches(g, &s.frame) && render(g, &s.frame, "field")) {return}
			after, restored := backend.save_renderer_state(
				renderer,
			); testing.expect(t, restored && before == after)
			reader, copied := editor.try_copy_frame(&s.frame); testing.expect(t, copied)
			editor.destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
			testing.expect(
				t,
				render(g, &reader, "field"),
				"historical owning reader may render, never dispatch",
			)
			editor.destroy_frame(&reader)
		}
	}
}
