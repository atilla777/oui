package main
import base "ui:ui_base"
import editor_sdl "ui:ui_editor/sdl"
import backend "ui:ui_sdl"
import fonts "ui:ui_sdl_text"
import sdl "vendor:sdl3"

render_current :: proc(r: ^Runtime) -> (ok: bool) {
	defer {if !ok {block_runtime(r)}}
	f := &r.reader
	if !base.is_current(&r.publication, f.editor.stamp) ||
	   f.editor.stamp != f.gestures.stamp ||
	   f.editor.stamp != f.text.stamp ||
	   f.editor.stamp != f.paint.stamp ||
	   !fonts.matches(f.fonts, &f.text, &f.paint) {return false}
	renderer := f.fonts.renderer
	state, saved := backend.save_renderer_state(renderer); if !saved {return false}
	ok =
		backend.pixel_coordinates(renderer) &&
		sdl.SetRenderClipRect(renderer, nil) &&
		backend.draw_color(renderer, {16, 22, 31, 255}) &&
		sdl.RenderClear(renderer)
	if ok {ok = draw_selected(r)}
	restored := backend.restore_renderer_state(renderer, state)
	return ok && restored
}
draw_selected :: proc(r: ^Runtime) -> bool {
	f := &r.reader; renderer := f.fonts.renderer; scale := f.editor.ui_scale
	for n in r.interaction.frame.targets {
		if n.description.role == "" {continue}
		color := base.Color{35, 66, 96, 255}
		if n.description.id == r.interaction.focus_id {color = {72, 91, 118, 255}}
		clip := backend.pixel_rect(n.clip, scale); bounds := backend.pixel_rect(n.bounds, scale)
		box := sdl.FRect{f32(bounds.x), f32(bounds.y), f32(bounds.w), f32(bounds.h)}
		if !sdl.SetRenderClipRect(renderer, &clip) ||
		   !backend.draw_color(renderer, color) ||
		   !sdl.RenderFillRect(renderer, &box) {return false}
	}
	for d in f.gestures.gestures {
		clip := backend.pixel_rect(
			d.geometry.clip,
			scale,
		); bounds := backend.pixel_rect(d.geometry.bounds, scale)
		box := sdl.FRect{f32(bounds.x), f32(bounds.y), f32(bounds.w), f32(bounds.h)}
		color := base.Color{45, 90, 125, 255}
		if d.kind ==
		   .Drop_Target {color = {55, 115, 80, 255}; if r.dropped {color = {90, 150, 60, 255}}}
		if !sdl.SetRenderClipRect(renderer, &clip) ||
		   !backend.draw_color(renderer, color) ||
		   !sdl.RenderFillRect(renderer, &box) {return false}
		if d.kind == .Pan_Scroll {
			for index in 0 ..< 4 {
				stripe := sdl.FRect {
					box.x + 4,
					f32((d.geometry.bounds.y + f64(index) * 60 - d.scroll_offset) * scale),
					box.w - 8,
					f32(48 * scale),
				}
				if !backend.draw_color(renderer, {130, 100, u8(80 + index * 25), 255}) ||
				   !sdl.RenderFillRect(renderer, &stripe) {return false}
			}
		}
	}
	for b in f.text.text_blocks {if b.node_id != "value" {if !fonts.render_node(f.fonts, &f.text, &f.paint, b.node_id) {return false}}}
	return editor_sdl.render(f.fonts, &f.editor, r.interaction.focus_id)
}
