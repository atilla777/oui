package ui_world

import ui "../ui_base"
import "core:math"
import "core:testing"

project_identity :: proc(w: [2]f64, user: rawptr) -> ([2]f64, bool) {
	if user != nil {count := cast(^int)user; count^ += 1}
	return w, true
}
@(test)
validation_and_space :: proc(t: ^testing.T) {
	d := fixture({200, 150}, .Clamp)
	for size in ([]ui.Extent{{0, 300}, {400, 0}, {99, 300}, {400, 39}}) {
		p, e := place_anchor(d, {project_identity, nil}, {0, 0, size.w, size.h}, 1)
		testing.expect(t, e.kind == .None && !p.visible && p.reason == .No_Space)
	}
	for index in 0 ..< 14 {
		x :=
			d; v := ui.Rect{0, 0, 400, 300}; scale := f64(1); c := Converter{project_identity, nil}; calls := 0; c.user = &calls
		switch index {
		case 0:
			x.id = ""
		case 1:
			x.world.x = transmute(f64)u64(0x7ff8000000000000)
		case 2:
			x.screen_offset.y = transmute(f64)u64(0x7ff0000000000000)
		case 3:
			x.extent.w = -1
		case 4:
			x.pivot.x = 1.1
		case 5:
			x.policy = Policy(42)
		case 6:
			x.indicator_extent.w = 0
		case 7:
			scale = 0
		case 8:
			scale = transmute(f64)u64(0x7ff8000000000000)
		case 9:
			v.x = -1
		case 10:
			v.w = transmute(f64)u64(0x7ff0000000000000)
		case 11:
			v.x = .5
		case 12:
			v.h = -1
		case 13:
			c.project = nil
		}
		p, e := place_anchor(x, c, v, scale)
		testing.expect(
			t,
			e.kind == .Invalid_Input && e.id == x.id && p == Placement{} && calls == 0,
		)
	}
	c := Converter{proc(w: [2]f64, u: rawptr) -> ([2]f64, bool) {return {}, false}, nil}
	p, e := place_anchor(d, c, {0, 0, 400, 300}, 1)
	testing.expect(t, e.kind == .Projection_Failed && p == Placement{})
	c.project = proc(w: [2]f64, u: rawptr) -> ([2]f64, bool) {return {
				transmute(f64)u64(0x7ff0000000000000),
				0,
			},
			true}
	p, e = place_anchor(d, c, {0, 0, 400, 300}, 1)
	testing.expect(t, e.kind == .Unrepresentable && p == Placement{})
	d.screen_offset.x = max(f64)
	p, e = place_anchor(d, {project_identity, nil}, {0, 0, 400, 300}, 2)
	testing.expect(t, e.kind == .Unrepresentable && p == Placement{})
}
fixture :: proc(p: [2]f64, policy := Policy.Hide) -> Description {
	return {
		id = "A",
		world = p,
		screen_offset = {0, -12},
		extent = {100, 40},
		pivot = {.5, 1},
		policy = policy,
		indicator_extent = {20, 20},
	}
}
@(test)
policies_and_scale :: proc(t: ^testing.T) {
	for scale in ([3]f64{1, 2, 1.5}) {
		p, e := place_anchor(
			fixture({200 * scale, 150 * scale}),
			{project_identity, nil},
			{0, 0, 400 * scale, 300 * scale},
			scale,
		)
		testing.expect(t, e.kind == .None)
		testing.expect_value(t, p.bounds, ui.Rect{150, 98, 100, 40})
	}
	for policy in Policy {
		p, e := place_anchor(
			fixture({500, 150}, policy),
			{project_identity, nil},
			{0, 0, 400, 300},
			1,
		)
		testing.expect(t, e.kind == .None)
		switch policy {
		case .Hide:
			testing.expect(t, !p.visible && p.reason == .Offscreen)
		case .Clamp:
			testing.expect(t, p.visible && p.clamped)
			testing.expect_value(t, p.bounds, ui.Rect{300, 98, 100, 40})
		case .Direction:
			testing.expect(t, p.visible && p.indicator)
			testing.expect_value(t, p.bounds, ui.Rect{380, 140, 20, 20})
			testing.expect_value(t, p.direction, [2]f64{1, 0})
		}
	}
	for point in ([][2]f64{{-20, 150}, {420, 150}, {200, -20}, {200, 320}, {-20, -20}, {420, -20}, {-20, 320}, {420, 320}, {400, 150}, {200, 300}}) {
		p, e := place_anchor(
			fixture(point, .Direction),
			{project_identity, nil},
			{0, 0, 400, 300},
			1,
		)
		testing.expect(t, e.kind == .None && p.visible && p.indicator)
		testing.expect(
			t,
			p.bounds.x >= 0 &&
			p.bounds.y >= 0 &&
			p.bounds.x + p.bounds.w <= 400 &&
			p.bounds.y + p.bounds.h <= 300,
		)
		testing.expect(
			t,
			math.abs(p.direction.x * p.direction.x + p.direction.y * p.direction.y - 1) < 1e-12,
		)
		testing.expect(t, p.direction.x * (point.x - 200) + p.direction.y * (point.y - 150) > 0)
	}
	p, e := place_anchor(fixture({400, 150}), {project_identity, nil}, {0, 0, 400, 300}, 1)
	testing.expect(t, e.kind == .None && !p.visible)
	p, e = place_anchor(fixture({0, 0}, .Clamp), {project_identity, nil}, {0, 0, 400, 300}, 1)
	testing.expect(t, e.kind == .None && p.bounds.x == 0 && p.bounds.y == 0 && p.clamped)
	p, e = place_anchor(
		fixture({500, 200}, .Direction),
		{project_identity, nil},
		{100, 50, 20, 20},
		1,
	)
	testing.expect(t, e.kind == .None && p.visible && p.bounds == ui.Rect{100, 50, 20, 20})
}
@(test)
oracle :: proc(t: ^testing.T) {
	calls := 0
	p, e := place_anchor(fixture({200, 150}), {project_identity, &calls}, {0, 0, 400, 300}, 1)
	testing.expect(t, e.kind == .None && p.visible && calls == 1)
	testing.expect_value(t, p.bounds, ui.Rect{150, 98, 100, 40})
}

@(test)
far_direction_and_selected_geometry :: proc(t: ^testing.T) {
	d := fixture({1e300, 1e300}, .Direction)
	p, e := place_anchor(d, {project_identity, nil}, {0, 0, 400, 300}, 1)
	testing.expect(
		t,
		e.kind == .None &&
		p.visible &&
		p.indicator &&
		math.abs(p.direction.x - p.direction.y) < 1e-12,
	)
	d.extent = {1000, 1000}; d.screen_offset = {1e300, 1e300}
	p, e = place_anchor(d, {project_identity, nil}, {0, 0, 400, 300}, 1)
	testing.expect(
		t,
		e.kind == .None && p.visible && p.indicator,
		"unselected card must not suppress fitting indicator",
	)
	d = fixture({200, 150}); d.extent = {0, 40}
	p, e = place_anchor(d, {project_identity, nil}, {0, 0, 400, 300}, 1)
	testing.expect(t, e.kind == .None && !p.visible && p.reason == .No_Space)
}

@(test)
empty_viewport_precedes_unused_geometry :: proc(t: ^testing.T) {
	for policy in Policy {
		d := fixture({1e300, 1e300}, policy)
		p, e := place_anchor(d, {project_identity, nil}, {0, 0, 0, 0}, 1)
		testing.expect(t, e.kind == .None && !p.visible && p.reason == .No_Space)
	}
}
