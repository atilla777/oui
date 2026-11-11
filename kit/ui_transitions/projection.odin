package ui_transitions

import base "../ui_base"
import interaction "../ui_interaction"
import style "../ui_style"
import "core:math"

geometry :: proc(f: ^Frame, id: string) -> (base.Frozen_Geometry, bool) {for e in f.entries {if e.id ==
		   id {return e.geometry, true}}
	return {}, false}
sample_interaction :: proc(f: ^Frame, i: ^interaction.Candidate) -> bool {
	if !f.bound || f.stamp != i.stamp {return false}
	for n in i.targets {if _, found := geometry(f, n.description.id); !found {return false}}
	for &n in i.targets {for e in f.entries {if e.id == n.description.id {
				n.bounds, n.clip = e.geometry.bounds, e.geometry.clip
				if !e.input_enabled {n.availability = .Not_Visible}
			}}}
	return true
}
sample_style :: proc(f: ^Frame, s: ^style.Frame) -> bool {
	if !f.bound ||
	   f.stamp != s.stamp ||
	   f.drawable != s.drawable ||
	   f.ui_scale != s.ui_scale {return false}
	for p in s.presentation {
		v, found := geometry(f, p.id); if !found {return false}
		for width in ([4]f64{p.radius, p.border_width, p.focus_width, v.scale}) {if !base.finite_nonnegative(width) || !base.finite(width * v.scale) {return false}}
	}
	for &p in s.presentation {
		v, _ := geometry(f, p.id)
		p.area, p.content, p.paint_clip, p.content_clip =
			v.bounds, v.content, v.clip, v.content_clip
		p.drawable = p.drawable && v.scale > 0 && v.opacity > 0
		p.radius *= v.scale; p.border_width *= v.scale; p.focus_width *= v.scale
		if fallback, has := p.fallback.?; has {p.fallback = base.forward_rect(v, fallback)}
		for &patch in p.patches {patch.destination = base.forward_rect(v, patch.destination)}
		for tr in f.tracks {if tr.node_id == p.id {#partial switch tr.property {
				case .Foreground, .Background, .Border:
					property := style.Paint_Property.Foreground
					if tr.property ==
					   .Background {property = .Background}; if tr.property == .Border {property = .Border}
					value, _ := color(tr.current.([4]f64)); p.computed[property].value = value
				case:
				}}}
	}
	return true
}
progress_value :: proc(f: ^Frame, id: string, fallback: f64) -> f64 {
	for tr in f.tracks {if tr.node_id == id && tr.property == .Progress {return tr.current.(f64)}}
	return fallback
}
color :: proc(value: [4]f64) -> (base.Color, bool) {
	if !value_valid(.Foreground, value) {return {}, false}
	c: base.Color; for x, index in value {c[index] = u8(clamp(math.floor(x + .5), 0, 255))}
	return c, true
}
