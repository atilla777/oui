package world_only

import world "ui:ui_world"

project :: proc(point: [2]f64, user: rawptr) -> ([2]f64, bool) {
	calls := cast(^int)user
	calls^ += 1
	return point, true
}

main :: proc() {
	calls := 0
	p, e := world.place_anchor(
		{
			id = "anchor",
			world = {500, 150},
			extent = {100, 40},
			pivot = {.5, 1},
			policy = .Direction,
			indicator_extent = {20, 20},
		},
		{project, &calls},
		{0, 0, 400, 300},
		1,
	)
	assert(e.kind == .None && calls == 1)
	assert(p.visible && p.indicator && p.direction == [2]f64{1, 0})
	assert(p.bounds.x == 380 && p.bounds.y == 140 && p.bounds.w == 20 && p.bounds.h == 20)
}
