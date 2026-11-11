package ui_custom_sdl

import ui ".."
import base "../../ui_base"
import backend "../../ui_sdl"
import style "../../ui_style"
import "core:math"
import "core:mem"
import "core:strings"
import sdl "vendor:sdl3"

Canvas :: distinct rawptr
Paint_Metadata :: style.Presentation
Custom_View :: struct {
	presentation: Paint_Metadata,
	scale:        f64,
}
Painter :: struct {
	type_id, revision: string,
	draw:              proc(canvas: Canvas, payload: []u8, view: Custom_View) -> bool,
}
Generation :: struct {
	renderer:  ^sdl.Renderer,
	revision:  string,
	painters:  []Painter,
	readers:   u64,
	allocator: mem.Allocator,
}
Error_Code :: enum {
	None,
	Invalid,
	Allocation,
	Generation,
	Draw,
	Canvas,
}
Error :: struct {
	code:                       Error_Code,
	node_id, type_id, revision: string,
}
create_generation :: proc(
	renderer: ^sdl.Renderer,
	revision: string,
	painters: []Painter,
	a := context.allocator,
) -> (
	^Generation,
	Error,
) {
	if renderer == nil || revision == "" {return nil, {code = .Invalid}}
	for p, index in painters {
		if p.type_id == "" ||
		   p.revision == "" ||
		   p.draw ==
			   nil {return nil, {code = .Invalid, type_id = p.type_id, revision = p.revision}}
		for prior in painters[:index] {if prior.type_id == p.type_id && prior.revision == p.revision {return nil, {code = .Invalid, type_id = p.type_id, revision = p.revision}}}
	}
	g, ae := new(Generation, a); if ae != nil {return nil, {code = .Allocation}}
	g^ = {
		renderer  = renderer,
		readers   = 1,
		allocator = a,
	}
	complete := false; defer {if !complete {release_generation(&g)}}
	g.revision, ae = strings.clone(revision, a); if ae != nil {return nil, {code = .Allocation}}
	g.painters, ae = make(
		[]Painter,
		len(painters),
		a,
	); if ae != nil {return nil, {code = .Allocation}}
	for p, index in painters {
		g.painters[index].draw = p.draw
		g.painters[index].type_id, ae = strings.clone(
			p.type_id,
			a,
		); if ae != nil {return nil, {code = .Allocation}}
		g.painters[index].revision, ae = strings.clone(
			p.revision,
			a,
		); if ae != nil {return nil, {code = .Allocation}}
	}
	complete = true; return g, {}
}
retain_generation :: proc(g: ^Generation) -> bool {if g == nil || g.readers == max(u64) {return(
			false \
		)}
	g.readers += 1
	return true}
release_generation :: proc(generation: ^^Generation) {
	g := generation^; generation^ = nil; if g == nil {return}
	g.readers -= 1; if g.readers > 0 {return}
	for p in g.painters {delete(p.type_id, g.allocator); delete(p.revision, g.allocator)}
	delete(g.painters, g.allocator); delete(g.revision, g.allocator); free(g, g.allocator)
}
canvas_fill_circle :: proc(
	canvas: Canvas,
	center: [2]f64,
	radius: f64,
	color: base.Color,
) -> bool {
	s := cast(^Canvas_State)rawptr(canvas)
	if s == nil || s.failed {return false}
	if !base.finite(center[0]) ||
	   !base.finite(center[1]) ||
	   !base.finite_nonnegative(radius) {s.failed = true; return false}
	if radius == 0 || color[3] == 0 || s.clip.w <= 0 || s.clip.h <= 0 {return true}
	point := base.forward_point(s.geometry, center)
	radius_visual := radius * s.geometry.scale
	color :=
		color; color[3] = u8(clamp(math.floor(f64(color[3]) * s.geometry.opacity + .5), 0, 255))
	if !base.finite(point[0]) ||
	   !base.finite(point[1]) ||
	   !base.finite_nonnegative(radius_visual) {s.failed = true; return false}
	if radius_visual == 0 || color[3] == 0 {return true}
	clip := backend.pixel_rect(s.clip, s.scale)
	if !backend.draw_color(s.renderer, color) {s.failed = true; return false}
	for y in clip.y ..< clip.y + clip.h {
		start := i32(-1)
		for x in clip.x ..= clip.x + clip.w {
			dx := ((f64(x) + .5) / s.scale - point[0]) / radius_visual
			dy := ((f64(y) + .5) / s.scale - point[1]) / radius_visual
			inside := x < clip.x + clip.w && dx * dx + dy * dy < 1
			if inside && start < 0 {start = x}
			if !inside && start >= 0 {
				rect := sdl.FRect{f32(start), f32(y), f32(x - start), 1}
				if !sdl.RenderFillRect(
					s.renderer,
					&rect,
				) {s.failed = true; return false}; start = -1
			}
		}
	}
	return true
}
preflight :: proc(g: ^Generation, frame: ^ui.Frame, paint: ^style.Frame) -> Error {
	if g == nil ||
	   frame.stamp.attempt == 0 ||
	   frame.stamp != paint.stamp ||
	   frame.drawable != paint.drawable ||
	   frame.ui_scale != paint.ui_scale ||
	   frame.ui_scale <= 0 ||
	   !backend.output_matches(g.renderer, frame.drawable) {return {code = .Generation}}
	for v in frame.views {
		found := false
		for p in g.painters {if p.type_id == v.type_id && p.revision == v.revision {found = true; break}}
		paint_found := false
		for p in paint.presentation {if p.id == v.node_id {paint_found = true; break}}
		if !found ||
		   !paint_found ||
		   !ui.valid_geometry(
				   v.geometry,
			   ) {return {code = .Generation, node_id = v.node_id, type_id = v.type_id, revision = v.revision}}
	}
	return {}
}
render_node :: proc(g: ^Generation, frame: ^ui.Frame, paint: ^style.Frame, id: string) -> Error {
	if error := preflight(g, frame, paint); error.code != .None {return error}
	for view in frame.views {if view.node_id == id {
			error := Error {
				node_id  = id,
				type_id  = view.type_id,
				revision = view.revision,
			}
			painter: Painter; found := false
			for p in g.painters {if p.type_id == view.type_id && p.revision == view.revision {painter, found = p, true; break}}
			if !found || !ui.valid_geometry(view.geometry) {error.code = .Generation; return error}
			presentation: style.Presentation; found = false
			for p in paint.presentation {if p.id == id {presentation, found = p, true; break}}
			if !found {error.code = .Generation; return error}
			if !presentation.drawable ||
			   view.geometry.scale == 0 ||
			   view.geometry.opacity == 0 {return {}}
			// Canvas alone owns layout -> visual mapping. Never pass a sampled
			// visual rectangle back as an original painter coordinate.
			presentation.area = view.layout_bounds
			state, saved := backend.save_renderer_state(
				g.renderer,
			); if !saved {error.code = .Draw; return error}
			canvas_state := Canvas_State {
				geometry = view.geometry,
				renderer = g.renderer,
				scale    = frame.ui_scale,
				clip     = view.geometry.clip,
			}
			// Host clip is saved state, not an additional UI clip. Install the
			// selected frozen node clip after normalizing viewport/scale.
			clip := backend.pixel_rect(view.geometry.clip, frame.ui_scale)
			ok :=
				backend.pixel_coordinates(g.renderer) &&
				sdl.SetRenderClipRect(g.renderer, &clip) &&
				sdl.SetRenderDrawBlendMode(g.renderer, sdl.BLENDMODE_BLEND)
			if ok {ok = painter.draw(Canvas(rawptr(&canvas_state)), view.payload, {presentation, frame.ui_scale})}
			restored := backend.restore_renderer_state(g.renderer, state)
			if canvas_state.failed {error.code = .Canvas} else if !ok || !restored {error.code = .Draw}
			return error
		}}
	return {code = .Generation, node_id = id}
}
Canvas_State :: struct {
	geometry: base.Frozen_Geometry,
	renderer: ^sdl.Renderer,
	scale:    f64,
	clip:     base.Rect,
	failed:   bool,
}
