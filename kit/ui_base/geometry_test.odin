package ui_base

import "core:testing"

@(test)
frozen_geometry_round_trip_and_unavailable_inverse :: proc(t: ^testing.T) {
	v := Frozen_Geometry {
		scale   = 2,
		offset  = {10, -3},
		opacity = 1,
	}
	p := forward_point(v, {4, 6})
	testing.expect(t, p == ([2]f64{18, 9}))
	q, ok := inverse_point(v, p)
	testing.expect(t, ok && q == ([2]f64{4, 6}))
	testing.expect(t, forward_rect(v, {4, 6, 3, 2}) == (Rect{18, 9, 6, 4}))
	v.scale = 0
	_, ok = inverse_point(v, p); testing.expect(t, !ok)
	v.scale = -1
	_, ok = inverse_point(v, p); testing.expect(t, !ok)
}
