package ui_world

import ui "../ui_base"
import "core:math"

Policy :: enum {
	Hide,
	Clamp,
	Direction,
}
Reason :: enum {
	Placed,
	Offscreen,
	No_Space,
}
Error_Kind :: enum {
	None,
	Invalid_Input,
	Projection_Failed,
	Unrepresentable,
}
Placement_Error :: struct {
	kind: Error_Kind,
	id:   string,
}
Description :: struct {
	id:                   string,
	world, screen_offset: [2]f64,
	extent:               ui.Extent,
	pivot:                [2]f64,
	policy:               Policy,
	indicator_extent:     ui.Extent,
}
Converter :: struct {
	project: proc(world: [2]f64, user: rawptr) -> ([2]f64, bool),
	user:    rawptr,
}
Placement :: struct {
	raw_screen, anchor:          [2]f64,
	bounds:                      ui.Rect,
	visible, indicator, clamped: bool,
	reason:                      Reason,
	direction:                   [2]f64,
}
place_anchor :: proc(
	d: Description,
	c: Converter,
	viewport_px: ui.Rect,
	ui_scale: f64,
) -> (
	Placement,
	Placement_Error,
) {
	if d.id == "" ||
	   c.project == nil ||
	   !finite(ui_scale) ||
	   ui_scale <= 0 ||
	   !vector_finite(d.world) ||
	   !vector_finite(d.screen_offset) ||
	   !vector_finite(d.pivot) ||
	   d.pivot.x < 0 ||
	   d.pivot.x > 1 ||
	   d.pivot.y < 0 ||
	   d.pivot.y > 1 ||
	   !extent_valid(d.extent) ||
	   !extent_valid(d.indicator_extent) ||
	   d.indicator_extent.w == 0 ||
	   d.indicator_extent.h == 0 ||
	   (d.policy != .Hide && d.policy != .Clamp && d.policy != .Direction) ||
	   !finite(viewport_px.x) ||
	   !finite(viewport_px.y) ||
	   !extent_valid({viewport_px.w, viewport_px.h}) ||
	   viewport_px.x < 0 ||
	   viewport_px.y < 0 ||
	   !finite(viewport_px.x + viewport_px.w) ||
	   !finite(viewport_px.y + viewport_px.h) ||
	   math.floor(viewport_px.x) != viewport_px.x ||
	   math.floor(viewport_px.y) != viewport_px.y ||
	   math.floor(viewport_px.x + viewport_px.w) != viewport_px.x + viewport_px.w ||
	   math.floor(viewport_px.y + viewport_px.h) != viewport_px.y + viewport_px.h {
		return {}, {.Invalid_Input, d.id}
	}
	if viewport_px.x + viewport_px.w > f64(max(i32)) ||
	   viewport_px.y + viewport_px.h > f64(max(i32)) {return {}, {.Unrepresentable, d.id}}
	raw, ok := c.project(d.world, c.user)
	if !ok {return {}, {.Projection_Failed, d.id}}
	if !vector_finite(raw) || !vector_finite(raw / ui_scale) {return {}, {.Unrepresentable, d.id}}
	p := Placement {
		raw_screen = raw,
		anchor     = raw / ui_scale,
		visible    = true,
	}
	v := ui.Rect {
		viewport_px.x / ui_scale,
		viewport_px.y / ui_scale,
		viewport_px.w / ui_scale,
		viewport_px.h / ui_scale,
	}
	inside :=
		p.anchor.x >= v.x && p.anchor.y >= v.y && p.anchor.x < v.x + v.w && p.anchor.y < v.y + v.h
	if !rect_finite(v) {return {}, {.Unrepresentable, d.id}}
	size := d.extent
	if d.policy == .Direction && !inside {size = d.indicator_extent}
	if v.w == 0 || v.h == 0 || size.w == 0 || size.h == 0 || size.w > v.w || size.h > v.h {
		p.visible, p.reason, p.bounds = false, .No_Space, {}
		return p, {}
	}
	if d.policy == .Hide &&
	   !inside {p.visible = false; p.reason = .Offscreen; p.bounds = {}; return p, {}}
	if d.policy != .Direction || inside {
		p.bounds = {
			p.anchor.x + d.screen_offset.x - d.pivot.x * d.extent.w,
			p.anchor.y + d.screen_offset.y - d.pivot.y * d.extent.h,
			d.extent.w,
			d.extent.h,
		}
		if !rect_finite(p.bounds) ||
		   !drawable_rect(p.bounds, ui_scale) {return {}, {.Unrepresentable, d.id}}
	}
	if d.policy == .Clamp {
		x, y :=
			clamp(p.bounds.x, v.x, v.x + v.w - d.extent.w),
			clamp(p.bounds.y, v.y, v.y + v.h - d.extent.h)
		p.clamped = x != p.bounds.x || y != p.bounds.y
		p.bounds.x, p.bounds.y = x, y
	}
	if d.policy == .Direction && !inside {
		center := [2]f64{v.x + v.w / 2, v.y + v.h / 2}
		delta := p.anchor - center
		m := max(math.abs(delta.x), math.abs(delta.y))
		unit := delta / m
		unit /= math.sqrt(unit.x * unit.x + unit.y * unit.y)
		half := [2]f64{(v.w - d.indicator_extent.w) / 2, (v.h - d.indicator_extent.h) / 2}
		t := max(f64)
		if unit.x != 0 {t = min(t, half.x / math.abs(unit.x))}
		if unit.y != 0 {t = min(t, half.y / math.abs(unit.y))}
		at := center + unit * t
		p.bounds = {
			at.x - d.indicator_extent.w / 2,
			at.y - d.indicator_extent.h / 2,
			d.indicator_extent.w,
			d.indicator_extent.h,
		}
		p.indicator, p.direction = true, unit
	}
	if !rect_finite(p.bounds) ||
	   !drawable_rect(p.bounds, ui_scale) ||
	   !vector_finite(p.direction) {return {}, {.Unrepresentable, d.id}}
	return p, {}
}

finite :: proc(v: f64) -> bool {return !math.is_nan(v) && !math.is_inf(v)}
vector_finite :: proc(v: [2]f64) -> bool {return finite(v.x) && finite(v.y)}
extent_valid :: proc(v: ui.Extent) -> bool {return(
		finite(v.w) &&
		finite(v.h) &&
		v.w >= 0 &&
		v.h >= 0 \
	)}
rect_finite :: proc(v: ui.Rect) -> bool {return(
		finite(v.x) &&
		finite(v.y) &&
		extent_valid({v.w, v.h}) &&
		finite(v.x + v.w) &&
		finite(v.y + v.h) \
	)}
drawable_rect :: proc(v: ui.Rect, s: f64) -> bool {
	for x in ([4]f64{v.x * s, v.y * s, (v.x + v.w) * s, (v.y + v.h) * s}) {if !finite(x) || x < f64(min(i32)) || x > f64(max(i32)) {return false}}
	return true
}
