package ui_sdl

import ui "../ui_style"
import "core:math"
import sdl "vendor:sdl3"

fill_area :: proc(r: ^sdl.Renderer, area: ui.Rect, scale: f64, color: ui.Color) -> bool {
	d := pixel_rect(area, scale)
	if d.w <= 0 || d.h <= 0 || color[3] == 0 {return true}
	f := sdl.FRect{f32(d.x), f32(d.y), f32(d.w), f32(d.h)}
	if !draw_color(r, color) {return false}
	return sdl.RenderFillRect(r, &f)
}
outline_area :: proc(r: ^sdl.Renderer, area: ui.Rect, scale, width: f64, color: ui.Color) -> bool {
	w := min(width, min(area.w, area.h) / 2)
	if w <= 0 {return true}
	return(
		fill_area(r, {area.x, area.y, area.w, w}, scale, color) &&
		fill_area(r, {area.x, area.y + area.h - w, area.w, w}, scale, color) &&
		fill_area(r, {area.x, area.y + w, w, area.h - 2 * w}, scale, color) &&
		fill_area(r, {area.x + area.w - w, area.y + w, w, area.h - 2 * w}, scale, color) \
	)
}
segment_distance :: proc(x, y, ax, ay, bx, by: f64) -> f64 {
	dx, dy := bx - ax, by - ay
	t := f64(0)
	if dx * dx + dy * dy >
	   0 {t = clamp(((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy), 0, 1)}
	return math.sqrt(math.pow(x - ax - t * dx, 2) + math.pow(y - ay - t * dy, 2))
}
// Pixel-center scan conversion handles concave simple polygons without an
// external triangulator. Horizontal runs avoid one SDL command per pixel.
shape_contains :: proc(p: ui.Presentation, x, y: f64) -> bool {
	w, h := p.content.w, p.content.h
	if x < 0 || y < 0 || x >= w || y >= h {return false}
	switch p.visual.kind {
	case .Rectangle:
		return true
	case .Rounded_Rectangle:
		r := p.radius
		cx, cy := clamp(x, r, w - r), clamp(y, r, h - r)
		return (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r
	case .Ellipse:
		return math.pow((x - w / 2) / (w / 2), 2) + math.pow((y - h / 2) / (h / 2), 2) <= 1
	case .Line:
		return p.border_width > 0 && segment_distance(x, y, 0, 0, w, h) <= p.border_width / 2
	case .Border:
		return(
			x < p.border_width ||
			y < p.border_width ||
			x >= w - p.border_width ||
			y >= h - p.border_width \
		)
	case .Triangle, .Polygon:
		inside := false
		for a, i in p.visual.points {
			b := p.visual.points[(i + 1) % len(p.visual.points)]
			ax, ay, bx, by := a[0] * w, a[1] * h, b[0] * w, b[1] * h
			if (ay > y) != (by > y) && x < (bx - ax) * (y - ay) / (by - ay) + ax {inside = !inside}
		}
		return inside
	case .Role, .Image:
		return false
	}
	return false
}
paint_primitive :: proc(r: ^sdl.Renderer, p: ui.Presentation, scale: f64) -> bool {
	if p.visual.kind == .Role || p.visual.kind == .Image {return true}
	return paint_shape_runs(r, p, scale, false) && paint_shape_runs(r, p, scale, true)
}
shape_border :: proc(p: ui.Presentation, x, y: f64) -> bool {
	b := p.border_width
	if b <= 0 || p.visual.kind == .Line || p.visual.kind == .Border {return false}
	if p.visual.kind == .Polygon || p.visual.kind == .Triangle {
		for a, i in p.visual.points {
			c := p.visual.points[(i + 1) % len(p.visual.points)]
			if segment_distance(
				   x,
				   y,
				   a[0] * p.content.w,
				   a[1] * p.content.h,
				   c[0] * p.content.w,
				   c[1] * p.content.h,
			   ) <
			   b {return true}
		}
		return false
	}
	inner := p
	inner.content.w -= 2 * b; inner.content.h -= 2 * b
	inner.radius = max(0, inner.radius - b)
	return !shape_contains(inner, x - b, y - b)
}
paint_shape_runs :: proc(r: ^sdl.Renderer, p: ui.Presentation, scale: f64, stroke: bool) -> bool {
	color := p.computed[.Foreground].value.(ui.Color)
	if stroke {color = p.computed[.Border].value.(ui.Color)}
	if color[3] == 0 {return true}
	d := pixel_rect(p.content, scale)
	clip := pixel_rect(p.paint_clip, scale)
	if !draw_color(r, color) {return false}
	for y in max(d.y, clip.y) ..< min(d.y + d.h, clip.y + clip.h) {
		start := i32(-1)
		end := min(d.x + d.w, clip.x + clip.w)
		for x in max(d.x, clip.x) ..= end {
			inside :=
				x < end &&
				shape_contains(
					p,
					(f64(x) + 0.5) / scale - p.content.x,
					(f64(y) + 0.5) / scale - p.content.y,
				)
			if inside &&
			   stroke {inside = shape_border(p, (f64(x) + 0.5) / scale - p.content.x, (f64(y) + 0.5) / scale - p.content.y)}
			if inside && start < 0 {start = x}
			if !inside && start >= 0 {
				rect := sdl.FRect{f32(start), f32(y), f32(x - start), 1}
				if !sdl.RenderFillRect(r, &rect) {return false}
				start = -1
			}
		}
	}
	return true
}
