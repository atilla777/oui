package ui_editor_sdl
import editor ".."
import base "../../ui_base"
import backend "../../ui_sdl"
import fonts "../../ui_sdl_text"
import "core:math"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"
matches :: proc(g: ^fonts.Generation, f: ^editor.Frame) -> bool {
	if g == nil ||
	   g.scale != f.ui_scale ||
	   f.stamp.attempt == 0 ||
	   !backend.output_matches(g.renderer, f.drawable) {return false}
	m := fonts.metrics(g)
	for e in f.editors {
		if fonts.find_font(g, e.font_id, e.font_size) == nil ||
		   !editor.valid_geometry(e.geometry) ||
		   len(e.runs) + 1 != len(e.stops) ||
		   len(e.stops) != len(e.boundaries) {return false}
		fm, fe := m.font_metrics(e.font_id, e.font_size, m.user)
		if fe != .None ||
		   fm.font_revision != e.font_revision ||
		   fm.ascent != e.ascent ||
		   fm.line_advance != e.line_advance {return false}
		for run, j in e.runs {
			if run.start != e.boundaries[j] ||
			   run.end != e.boundaries[j + 1] ||
			   run.start < 0 ||
			   run.end > len(e.value) ||
			   run.end < run.start ||
			   run.x != e.stops[j] {return false}
			lm, le := m.measure_line(e.value[run.start:run.end], e.font_id, e.font_size, m.user)
			if le != .None ||
			   lm.surface_extent != run.surface_extent ||
			   lm.advance_width != run.advance ||
			   e.stops[j + 1] != run.x + run.advance {return false}
		}
	}
	return true
}
render :: proc(
	g: ^fonts.Generation,
	f: ^editor.Frame,
	focus_id: string = "",
	foreground: base.Color = {230, 235, 245, 255},
	selection: base.Color = {45, 90, 170, 255},
	id: string = "",
) -> bool {
	if !matches(g, f) {return false}
	state, saved := backend.save_renderer_state(g.renderer); if !saved {return false}
	ok :=
		backend.pixel_coordinates(g.renderer) &&
		sdl.SetRenderDrawBlendMode(g.renderer, sdl.BLENDMODE_BLEND)
	if ok {ok = paint(g, f, focus_id, foreground, selection, id)}
	restored := backend.restore_renderer_state(g.renderer, state)
	return ok && restored
}
@(private)
paint :: proc(
	g: ^fonts.Generation,
	f: ^editor.Frame,
	focus: string,
	foreground, selection: base.Color,
	id: string,
) -> bool {
	for e in f.editors {
		if id != "" && id != e.id && id != e.node_id {continue}
		geometry := e.geometry
		clip := backend.pixel_rect(
			base.intersection(
				geometry.content_clip,
				{w = f.drawable.w / f.ui_scale, h = f.drawable.h / f.ui_scale},
			),
			f.ui_scale,
		)
		if !sdl.SetRenderClipRect(g.renderer, &clip) {return false}
		if clip.w <= 0 || clip.h <= 0 || geometry.opacity == 0 {continue}
		left, right, caret: f64
		for b, j in e.boundaries {
			if b == min(e.anchor, e.caret) {left = e.stops[j]}
			if b == max(e.anchor, e.caret) {right = e.stops[j]}
			if b == e.caret {caret = e.stops[j]}
		}
		if e.anchor != e.caret {
			r := base.forward_rect(
				geometry,
				{e.content.x + left - e.scroll, e.content.y, right - left, e.line_advance},
			)
			dest := pixel_destination(r, f.ui_scale)
			color := selection; color[3] = u8(f64(color[3]) * geometry.opacity)
			if !backend.draw_color(g.renderer, color) ||
			   !sdl.RenderFillRect(g.renderer, &dest) {return false}
		}
		font := fonts.find_font(g, e.font_id, e.font_size)
		color := foreground; color[3] = u8(f64(color[3]) * geometry.opacity)
		for run in e.runs {
			value := e.value[run.start:run.end]
			surface := ttf.RenderText_Blended(
				font.font,
				raw_data(value),
				uint(len(value)),
				{color[0], color[1], color[2], color[3]},
			)
			if surface == nil {return false}; defer sdl.DestroySurface(surface)
			if f64(surface.w) / f.ui_scale != run.surface_extent.w ||
			   f64(surface.h) / f.ui_scale != run.surface_extent.h {return false}
			texture := sdl.CreateTextureFromSurface(
				g.renderer,
				surface,
			); if texture == nil {return false}; defer sdl.DestroyTexture(texture)
			r := base.forward_rect(
				geometry,
				{
					e.content.x + run.x - e.scroll,
					e.content.y,
					run.surface_extent.w,
					run.surface_extent.h,
				},
			)
			dest := pixel_destination(r, f.ui_scale)
			if !sdl.SetTextureBlendMode(texture, sdl.BLENDMODE_BLEND) ||
			   !sdl.RenderTexture(g.renderer, texture, nil, &dest) {return false}
		}
		if focus == e.node_id && e.availability == .Applied {
			r := base.forward_rect(
				geometry,
				{e.content.x + caret - e.scroll, e.content.y, 1 / f.ui_scale, e.line_advance},
			)
			dest := pixel_destination(r, f.ui_scale)
			if !backend.draw_color(g.renderer, color) ||
			   !sdl.RenderFillRect(g.renderer, &dest) {return false}
		}
	}
	return true
}
@(private)
pixel_destination :: proc(r: base.Rect, scale: f64) -> sdl.FRect {return {
		f32(math.round(r.x * scale)),
		f32(math.round(r.y * scale)),
		f32(r.w * scale),
		f32(r.h * scale),
	}}
