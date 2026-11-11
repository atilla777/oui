package ui_scroll

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"

hit_test :: proc(
	f: ^Frame,
	g: ^layout.Frame,
	i: ^interaction.Frame,
	x, y: f64,
	view: base.Geometry_View = {},
) -> (
	^Region,
	bool,
) {
	if f.stamp != g.stamp ||
	   f.stamp != i.stamp ||
	   g.ui_scale <= 0 ||
	   !base.finite(g.ui_scale) ||
	   !base.finite(x) ||
	   !base.finite(y) {return nil, false}
	projected := view.stamp.lifetime != nil || len(view.entries) > 0
	if projected && view.stamp != f.stamp {return nil, false}
	xl, yl := x / g.ui_scale, y / g.ui_scale
	for k := len(f.regions) - 1; k >= 0; k -= 1 {
		r := &f.regions[k]
		if region_gate(i, r) != .Applied {continue}
		clip := r.viewport
		if projected {
			found := false
			for e in view.entries {if e.id == r.id && e.input_enabled && e.geometry.scale > 0 && e.geometry.opacity > 0 {clip = e.geometry.content_clip; found = true; break}}
			if !found {continue}
		}
		if base.contains(clip, xl, yl) {return r, true}
	}
	return nil, false
}
