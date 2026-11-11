package ui_sdl

import sdl "vendor:sdl3"

Renderer_State :: struct {
	clip, viewport:        sdl.Rect,
	clipped, viewport_set: bool,
	color:                 [4]f32,
	blend:                 sdl.BlendMode,
	sx, sy, color_scale:   f32,
	lw, lh:                i32,
	logical:               sdl.RendererLogicalPresentation,
}
save_renderer_state :: proc(r: ^sdl.Renderer) -> (Renderer_State, bool) {
	s := Renderer_State {
		clipped      = sdl.RenderClipEnabled(r),
		viewport_set = sdl.RenderViewportSet(r),
	}
	ok :=
		sdl.GetRenderClipRect(r, &s.clip) &&
		sdl.GetRenderDrawColorFloat(r, &s.color[0], &s.color[1], &s.color[2], &s.color[3]) &&
		sdl.GetRenderDrawBlendMode(r, &s.blend) &&
		sdl.GetRenderViewport(r, &s.viewport) &&
		sdl.GetRenderScale(r, &s.sx, &s.sy) &&
		sdl.GetRenderColorScale(r, &s.color_scale) &&
		sdl.GetRenderLogicalPresentation(r, &s.lw, &s.lh, &s.logical)
	return s, ok
}
pixel_coordinates :: proc(r: ^sdl.Renderer) -> bool {
	return(
		sdl.SetRenderLogicalPresentation(r, 0, 0, .DISABLED) &&
		sdl.SetRenderViewport(r, nil) &&
		sdl.SetRenderScale(r, 1, 1) &&
		sdl.SetRenderColorScale(r, 1) \
	)
}
restore_renderer_state :: proc(r: ^sdl.Renderer, state: Renderer_State) -> bool {
	s := state
	// Every restoration is attempted, even after a preceding failure.
	l := sdl.SetRenderLogicalPresentation(r, s.lw, s.lh, s.logical)
	v := sdl.SetRenderViewport(r, nil)
	if s.viewport_set {v = sdl.SetRenderViewport(r, &s.viewport) && v}
	scale := sdl.SetRenderScale(r, s.sx, s.sy)
	cs := sdl.SetRenderColorScale(r, s.color_scale)
	c := sdl.SetRenderClipRect(r, nil)
	if s.clipped {c = sdl.SetRenderClipRect(r, &s.clip) && c}
	b := sdl.SetRenderDrawBlendMode(r, s.blend)
	d := sdl.SetRenderDrawColorFloat(r, s.color[0], s.color[1], s.color[2], s.color[3])
	return l && v && scale && cs && c && b && d
}
