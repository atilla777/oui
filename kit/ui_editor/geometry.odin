package ui_editor
import base "../ui_base"
// Candidate-only materialization of the selected frozen numerical projection.
sample_candidate :: proc(c: ^Candidate, view: base.Geometry_View) -> bool {
	if view.stamp != c.frame.stamp {return false}
	for e in c.frame.editors {
		found := false
		for entry, j in view.entries {if entry.id == e.node_id {
				if !valid_geometry(entry.geometry) {return false}
				for prior in view.entries[:j] {if prior.id == entry.id {return false}}
				found = true
			}}
		if !found {return false}
	}
	for &e in c.frame.editors {for entry in view.entries {if entry.id == e.node_id {
				e.geometry = entry.geometry
				if !entry.input_enabled ||
				   entry.geometry.opacity == 0 {e.availability = .Not_Visible}
			}}}
	return true
}
valid_geometry :: proc(g: base.Frozen_Geometry) -> bool {
	if !base.finite(g.scale) ||
	   g.scale <= 0 ||
	   !base.finite(g.opacity) ||
	   g.opacity < 0 ||
	   g.opacity > 1 ||
	   !base.finite(g.offset[0]) ||
	   !base.finite(g.offset[1]) {return false}
	for r in ([4]base.Rect{g.bounds, g.content, g.clip, g.content_clip}) {
		if !base.finite(r.x) ||
		   !base.finite(r.y) ||
		   !base.finite_nonnegative(r.w) ||
		   !base.finite_nonnegative(r.h) ||
		   !base.finite(r.x + r.w) ||
		   !base.finite(r.y + r.h) {return false}
	}
	return true
}
