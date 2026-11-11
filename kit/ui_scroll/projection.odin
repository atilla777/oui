package ui_scroll

import base "../ui_base"
import layout "../ui_layout"

// Numerical candidate-only stage for a specialized logical data owner. The
// caller owns the one offset; no ui_scroll.State is installed for that region.
// Reuses the same translation/clipping algorithm as ordinary scroll prepare.
project_region :: proc(g: ^layout.Frame, d: Description, offset: f64) -> Error {
	viewport, vok := layout.find(g, d.id); content, cok := layout.find(g, d.content_id)
	if !vok ||
	   !cok ||
	   content.description.parent != d.id ||
	   content.description.role != .Column ||
	   !base.finite(offset) ||
	   g.ui_scale <= 0 {return {.Invalid_Scroll, d.id}}
	l, has := content.description.layout.?
	if !has ||
	   l.y.mode != .Content ||
	   l.grow != 0 ||
	   l.shrink != 0 {return {.Invalid_Scroll, d.content_id}}
	clamped := clamp(offset, 0, max(0, content.bounds.h - viewport.clip.h))
	translate(g, d.content_id, -clamped, viewport.clip)
	return {}
}
