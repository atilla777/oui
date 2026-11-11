package ui_sdl

import ui "../ui_style"
import "core:math"
import sdl "vendor:sdl3"

paint_node :: proc(
	g: ^Generation,
	f: ^ui.Frame,
	id: string,
	focus: bool = false,
	opacity: f64 = 1,
) -> bool {
	if id == "" || !generation_matches(g, f) {return false}
	if !ui.finite_nonnegative(opacity) || opacity > 1 {return false}
	found :=
		false; for p in f.presentation {if p.id == id {found = true}}; if !found {return false}
	state, saved := save_renderer_state(g.renderer); if !saved {return false}
	ok := pixel_coordinates(g.renderer) && paint(g, f, id, focus, false, opacity)
	restored := restore_renderer_state(g.renderer, state); return ok && restored
}

pixel_rect :: proc(rect: ui.Rect, scale: f64) -> sdl.Rect {
	// Round physical edges directly. Logical snap -> multiply -> integer truncate
	// can turn a one-pixel border into zero pixels at fractional scale.
	x, y := math.round(rect.x * scale), math.round(rect.y * scale)
	right, bottom := math.round((rect.x + rect.w) * scale), math.round((rect.y + rect.h) * scale)
	return {i32(x), i32(y), i32(right - x), i32(bottom - y)}
}
draw_color :: proc(renderer: ^sdl.Renderer, color: ui.Color) -> bool {
	return sdl.SetRenderDrawColor(renderer, color[0], color[1], color[2], color[3])
}
output_matches :: proc(r: ^sdl.Renderer, drawable: ui.Extent) -> bool {
	w, h: i32
	return sdl.GetRenderOutputSize(r, &w, &h) && f64(w) == drawable.w && f64(h) == drawable.h
}
generation_matches :: proc(g: ^Generation, f: ^ui.Frame) -> bool {
	if g == nil ||
	   f.stamp.attempt == 0 ||
	   f.resource_revision != g.revision ||
	   !output_matches(g.renderer, f.drawable) {return false}
	for p in f.presentation {
		if image, has := p.image.?; has {
			asset, found := resolve_image(g, image.id)
			if !found ||
			   asset.metadata.source != image.source ||
			   (asset.atlas && asset.metadata.nine_slice != image.nine_slice) {return false}
		}
	}
	return true
}
render :: proc(g: ^Generation, f: ^ui.Frame) -> bool {
	if !generation_matches(g, f) {return false}
	r := g.renderer
	state, saved := save_renderer_state(r); if !saved {return false}
	ok := pixel_coordinates(r) && paint(g, f)
	restored := restore_renderer_state(r, state)
	return ok && restored
}
@(private)
paint :: proc(
	g: ^Generation,
	f: ^ui.Frame,
	id: string = "",
	focus_only: bool = false,
	clear: bool = true,
	opacity: f64 = 1,
) -> bool {
	r := g.renderer
	if !sdl.SetRenderDrawBlendMode(r, sdl.BLENDMODE_BLEND) {return false}
	if clear &&
	   (!sdl.SetRenderClipRect(r, nil) ||
			   !draw_color(r, {16, 22, 31, 255}) ||
			   !sdl.RenderClear(r)) {return false}
	for original in f.presentation {
		p := original
		for property in ([]ui.Paint_Property{.Background, .Foreground, .Border}) {color := p.computed[property].value.(ui.Color); color[3] = u8(f64(color[3]) * opacity); p.computed[property].value = color}
		if focus_only || (id != "" && p.id != id) {continue}
		if !p.drawable {continue}
		clip := pixel_rect(p.paint_clip, f.ui_scale)
		if !sdl.SetRenderClipRect(r, &clip) ||
		   !fill_area(
				   r,
				   p.area,
				   f.ui_scale,
				   p.computed[.Background].value.(ui.Color),
			   ) {return false}
		if image, has := p.image.?; has {
			asset, found := resolve_image(g, image.id); if !found {return false}
			for patch in p.patches {
				source := sdl.FRect {
					asset.rect.x + f32(patch.source.x),
					asset.rect.y + f32(patch.source.y),
					f32(patch.source.w),
					f32(patch.source.h),
				}
				d := pixel_rect(patch.destination, f.ui_scale)
				dest := sdl.FRect{f32(d.x), f32(d.y), f32(d.w), f32(d.h)}
				if d.w > 0 &&
				   d.h > 0 &&
				   !texture_with_opacity(r, asset.texture, &source, &dest, opacity) {return false}
			}
		}
		if area, has := p.fallback.?; has {
			if !outline_area(
				r,
				area,
				f.ui_scale,
				1,
				alpha_color({255, 0, 255, 255}, opacity),
			) {return false}
		}
		if !paint_primitive(r, p, f.ui_scale) {return false}
		if (p.visual.kind == .Role || p.visual.kind == .Image) &&
		   !outline_area(
				   r,
				   p.area,
				   f.ui_scale,
				   p.border_width,
				   p.computed[.Border].value.(ui.Color),
			   ) {return false}
	}
	for p in f.presentation {
		if id != "" && (!focus_only || p.id != id) {continue}
		if p.drawable && p.focus_indicator {
			clip := pixel_rect(p.paint_clip, f.ui_scale)
			if !sdl.SetRenderClipRect(r, &clip) ||
			   !outline_area(
					   r,
					   p.area,
					   f.ui_scale,
					   p.focus_width,
					   alpha_color(p.focus_color, opacity),
				   ) {return false}
		}
	}
	return true
}
@(private)
alpha_color :: proc(c: ui.Color, opacity: f64) -> ui.Color {v := c; v[3] = u8(f64(c[3]) * opacity)
	return v}
@(private)
texture_with_opacity :: proc(
	r: ^sdl.Renderer,
	t: ^sdl.Texture,
	source, dest: ^sdl.FRect,
	opacity: f64,
) -> bool {
	alpha: f32; if !sdl.GetTextureAlphaModFloat(t, &alpha) {return false}
	ok :=
		sdl.SetTextureAlphaModFloat(t, alpha * f32(opacity)) &&
		sdl.RenderTexture(r, t, source, dest)
	restored := sdl.SetTextureAlphaModFloat(t, alpha); return ok && restored
}
// Owning readback. Caller destroys it before renderer destruction. No present here.
readback :: proc(r: ^sdl.Renderer, drawable: ui.Extent) -> (^sdl.Surface, bool) {
	if !output_matches(r, drawable) {return nil, false}
	state, saved := save_renderer_state(r); if !saved {return nil, false}
	pixels: ^sdl.Surface
	if pixel_coordinates(r) {pixels = sdl.RenderReadPixels(r, nil)}
	restored := restore_renderer_state(r, state)
	if !restored ||
	   pixels == nil {if pixels != nil {sdl.DestroySurface(pixels)}; return nil, false}
	return pixels, true
}
