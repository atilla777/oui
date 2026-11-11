package ui_base

// Frame-bound numerical values. No clock, allocator, application or SDL owner.
Frozen_Geometry :: struct {
	scale:                               f64,
	offset:                              [2]f64,
	opacity:                             f64,
	bounds, content, clip, content_clip: Rect,
}
Geometry_Entry :: struct {
	id:            string,
	geometry:      Frozen_Geometry,
	input_enabled: bool,
}
// Borrowed synchronously; owning users materialize entries and retain stamp.
Geometry_View :: struct {
	stamp:   Frame_Stamp,
	entries: []Geometry_Entry,
}
forward_point :: proc(v: Frozen_Geometry, p: [2]f64) -> [2]f64 {return {
		p[0] * v.scale + v.offset[0],
		p[1] * v.scale + v.offset[1],
	}}
forward_rect :: proc(v: Frozen_Geometry, r: Rect) -> Rect {
	p := forward_point(v, {r.x, r.y}); return {p[0], p[1], r.w * v.scale, r.h * v.scale}
}
inverse_point :: proc(v: Frozen_Geometry, p: [2]f64) -> ([2]f64, bool) {
	if v.scale <= 0 || !finite(v.scale) || !finite(p[0]) || !finite(p[1]) {return {}, false}
	q := [2]f64{(p[0] - v.offset[0]) / v.scale, (p[1] - v.offset[1]) / v.scale}
	return q, finite(q[0]) && finite(q[1])
}
