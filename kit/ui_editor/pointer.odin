package ui_editor

import base "../ui_base"
finite :: base.finite
finite_nonnegative :: base.finite_nonnegative

// dt is caller-controlled seconds, not a wall-clock or event-count surrogate.
editor_drag :: proc(e: View, x, dt: f64) -> (caret: int, scroll: f64, valid: bool) {
	if !finite(x) ||
	   !finite_nonnegative(dt) ||
	   !finite_nonnegative(e.extent) ||
	   !finite_nonnegative(e.content.w) {return e.caret, e.scroll, false}
	scroll = e.scroll
	if x < e.content.x {scroll -= 240 * dt}
	if x >= e.content.x + e.content.w {scroll += 240 * dt}
	scroll = clamp(scroll, 0, max(0, e.extent - e.content.w))
	view := e; view.scroll = scroll
	return editor_hit(view, clamp(x, e.content.x, e.content.x + e.content.w)), scroll, true
}

// x is logical window space. Ties choose the leftmost source boundary.
editor_hit :: proc(e: View, x: f64) -> int {
	if !finite(x) || len(e.stops) == 0 || len(e.stops) != len(e.boundaries) {return 0}
	position := x - e.content.x + e.scroll
	best := 0; distance := abs(position - e.stops[0])
	for stop, i in e.stops {
		if d := abs(position - stop); d < distance {best = i; distance = d}
	}
	return e.boundaries[best]
}
