package sections

import model "../model"
import "core:fmt"
import "core:math"
import base "ui:ui_base"
import style "ui:ui_style"
import world "ui:ui_world"

World_Camera :: struct {
	center, origin: [2]f64,
	zoom:           f64,
}
world_project :: proc(point: [2]f64, user: rawptr) -> ([2]f64, bool) {
	c := cast(^World_Camera)user
	return c.origin + (point - c.center) * c.zoom, true
}
compose_world :: proc(c: ^Page_Composition, m: model.Model, drawable: base.Extent) -> bool {
	en := m.locale == .English
	control_labels, world_labels := WORLD_CONTROL_LABELS, WORLD_LABELS
	policies := [3]string{"Hide", "Clamp", "Direction"}
	card_labels := [3]string{"A 75/100", "B 75/100", "C 75/100"}
	progress_ids := [3]string{"world/a-progress", "world/b-progress", "world/c-progress"}
	track_ids := [3]string{"world/a-track", "world/b-track", "world/c-track"}
	label(
		c,
		"world/title",
		"root",
		"G19 / anchors",
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 20}},
	)
	node(
		c,
		"world/actions",
		"root",
		.Row,
		{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}, gap = 4},
	)
	rows := [2]string{"world/actions", "world/actions"}
	ids := [2][4]string {
		{"world/object-left", "world/object-right", "world/object-up", "world/object-down"},
		{"world/camera-left", "world/camera-right", "world/camera-up", "world/camera-down"},
	}
	labels := [2][4]string {
		{"A -X", "A +X", "A -Y", "A +Y"},
		{"Camera -X", "Camera +X", "Camera -Y", "Camera +Y"},
	}
	if !en {labels[1] = {"Камера -X", "Камера +X", "Камера -Y", "Камера +Y"}}
	for row, i in rows {
		for id, j in ids[i] {button(c, id, control_labels[i][j], row, labels[i][j])}
	}
	button(
		c,
		"world/zoom",
		"world/zoom-label",
		"world/actions",
		"Zoom 2" if m.world.zoomed else "Zoom 1",
	)
	button(c, "world/policy", "world/policy-label", "world/actions", policies[m.world.policy])
	button(
		c,
		"world/reset",
		"world/reset-label",
		"world/actions",
		"Reset" if en else "Сбросить",
	)
	// Original world fixture in drawable pixels; no shrinking of cards/indicators.
	scale := m.scale
	left, top := math.ceil(32 * scale), math.ceil(160 * scale)
	right, bottom := math.floor(drawable.w - 32 * scale), math.floor(drawable.h - 32 * scale)
	viewport := base.Rect {
		min(left, drawable.w),
		min(top, drawable.h),
		max(0, right - left),
		max(0, bottom - top),
	}
	node(c, "world/overlay", "shell/root", .Absolute, {x = {mode = .Fill}, y = {mode = .Fill}})
	node(
		c,
		"world/viewport",
		"world/overlay",
		.Absolute,
		{
			x = {mode = .Fixed, value = viewport.w / scale},
			y = {mode = .Fixed, value = viewport.h / scale},
			offset = {viewport.x / scale, viewport.y / scale},
			overflow = .Clip,
		},
	)
	camera := World_Camera {
		center = m.world.camera,
		origin = {viewport.x + viewport.w / 2, viewport.y + viewport.h / 2},
		zoom   = 1,
	}
	if m.world.zoomed {camera.zoom = 2}
	positions := [3][2]f64{m.world.object, {800, 0}, {-800, -500}}
	for id, i in ([3]string{"world/a", "world/b", "world/c"}) {
		p, e := world.place_anchor(
			{
				id = id,
				world = positions[i],
				screen_offset = {0, -12},
				extent = {112, 48},
				pivot = {.5, 1},
				policy = world.Policy(m.world.policy),
				indicator_extent = {24, 24},
			},
			{project = world_project, user = &camera},
			viewport,
			scale,
		)
		if e.kind != .None {return false}
		c.world[i] = p
		node(
			c,
			id,
			"world/viewport",
			.Absolute,
			{
				x = {mode = .Fixed, value = p.bounds.w},
				y = {mode = .Fixed, value = p.bounds.h},
				offset = {p.bounds.x - viewport.x / scale, p.bounds.y - viewport.y / scale},
			},
		)
		c.nodes[c.n - 1].visible = p.visible
		if p.indicator {c.nodes[c.n - 1].role = .Box}
		world_style(c, id, i * 3, {35, 66, 96, 255})
		if p.indicator {
			d := p.direction; perpendicular := [2]f64{-d.y, d.x}
			c.world_triangles[i] = {
				{.5, .5} + d * .5,
				{.5, .5} - d * .3 + perpendicular * .35,
				{.5, .5} - d * .3 - perpendicular * .35,
			}
			c.styles[c.ns - 1].visual = {
				kind      = .Triangle,
				points    = c.world_triangles[i][:],
				intrinsic = {24, 24},
			}
		} else {
			label(
				c,
				world_labels[i],
				id,
				card_labels[i],
				{x = {mode = .Fill}, y = {mode = .Fixed, value = 24}},
			)
			node(
				c,
				track_ids[i],
				id,
				.Box,
				{
					x = {mode = .Fixed, value = 112},
					y = {mode = .Fixed, value = 8},
					offset = {0, 32},
				},
			)
			world_style(c, track_ids[i], i * 3 + 1, {45, 45, 45, 255})
			node(
				c,
				progress_ids[i],
				id,
				.Box,
				{
					x = {mode = .Fixed, value = 84},
					y = {mode = .Fixed, value = 8},
					offset = {0, 32},
				},
			)
			world_style(c, progress_ids[i], i * 3 + 2, {65, 180, 120, 255})
		}
	}
	for &t in c.texts[:c.nt] {if t.id == "world/title" {t.text = fmt.bprintf(c.world_buffer[:], "G19 / anchors | A=%v B=%v C=%v", c.world[0].reason, c.world[1].reason, c.world[2].reason)}}
	c.initial_focus = "world/object-left"
	return true
}
world_style :: proc(c: ^Page_Composition, id: string, index: int, color: style.Color) {
	c.world_paint[index] = {
		{.Background, color},
		{.Foreground, color},
		{.Border_Width, f64(0)},
		{.Font, style.Font_ID{"own"}},
		{.Font_Size, f64(14)},
	}
	c.styles[c.ns] = {
		id = id,
	}; c.styles[c.ns].appearance.local.states[.Normal] = c.world_paint[index][:]; c.ns += 1
}
WORLD_LABELS :: [3]string{"world/a-label", "world/b-label", "world/c-label"}
WORLD_CONTROL_LABELS :: [2][4]string {
	{
		"world/object-left-label",
		"world/object-right-label",
		"world/object-up-label",
		"world/object-down-label",
	},
	{
		"world/camera-left-label",
		"world/camera-right-label",
		"world/camera-up-label",
		"world/camera-down-label",
	},
}
