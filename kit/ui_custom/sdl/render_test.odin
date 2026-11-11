package ui_custom_sdl

import ui ".."
import base "../../ui_base"
import interaction "../../ui_interaction"
import layout "../../ui_layout"
import backend "../../ui_sdl"
import style "../../ui_style"
import "core:testing"
import sdl "vendor:sdl3"

valid :: proc(bytes: []u8) -> bool {return len(bytes) == 1 && bytes[0] == 3}
measure :: proc(bytes: []u8, c: ui.Constraints) -> (base.Extent, bool) {return {20, 20}, true}
inside :: proc(bytes: []u8, p: [2]f64, size: base.Extent) -> bool {x, y :=
		(p[0] - size.w / 2) / (size.w / 2), (p[1] - size.h / 2) / (size.h / 2)
	return x * x + y * y < 1}
fail_draw :: proc(_: Canvas, _: []u8, _: Custom_View) -> bool {return false}
@(test)
canvas_zero_radius_is_noop_and_native_failure_is_sticky :: proc(t: ^testing.T) {
	state := Canvas_State {
		geometry = {scale = 1, opacity = 1},
		scale = 1,
		clip = {0, 0, 4, 4},
	}
	canvas := Canvas(rawptr(&state))
	testing.expect(t, canvas_fill_circle(canvas, {2, 2}, 0, {255, 255, 255, 255}) && !state.failed)
	testing.expect(t, !canvas_fill_circle(canvas, {2, 2}, 2, {255, 255, 255, 255}) && state.failed)
	testing.expect(t, !canvas_fill_circle(canvas, {2, 2}, 0, {255, 255, 255, 255}))
}
disk :: proc(canvas: Canvas, bytes: []u8, view: Custom_View) -> bool {
	r := view.presentation.area
	return canvas_fill_circle(canvas, {r.x + r.w / 2, r.y + r.h / 2}, r.w / 2, {255, 0, 0, 255})
}
@(test)
custom_canvas_keeps_layout_abi_and_matches_frozen_circle_hit_pixels :: proc(t: ^testing.T) {
	surface := sdl.CreateSurface(
		160,
		100,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	r := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, r != nil) {return}; defer sdl.DestroyRenderer(r)
	generation, e := create_generation(r, "paint-v1", []Painter{{"circle", "1", disk}})
	if !testing.expect(t, e.code == .None) {return}; defer release_generation(&generation)
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	stamp, _ := base.begin_attempt(&p, 1)
	nodes := []layout.Node {
		{
			id = "root",
			role = .Absolute,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
		},
		{
			id = "disk",
			parent = "root",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 40},
				y = {mode = .Fixed, value = 40},
				offset = {20, 20},
			},
		},
	}
	geometry, ge := layout.prepare(
		nodes,
		{drawable = {160, 100}, ui_scale = 1},
		{},
		context.allocator,
		stamp,
	); defer layout.destroy_frame(&geometry)
	if !testing.expect(t, ge.code == .None) {return}
	i, ie := interaction.prepare(
		&geometry,
		[]interaction.Target{{"disk", "button", true, true}},
		[]interaction.Capture_Claim{{"disk", "custom"}},
		context.allocator,
	); defer interaction.destroy_frame(&i)
	if !testing.expect(
		t,
		ie == .Applied && interaction.bind_activation_owner(&i, "disk", "custom") == .Applied,
	) {return}
	c, ce := ui.prepare(
		&geometry,
		&i,
		[]ui.Description {
			{
				node_id = "disk",
				type_id = "circle",
				revision = "1",
				payload = []u8{3},
				validate = valid,
				measure = measure,
				hit = inside,
			},
		},
	)
	defer ui.destroy_frame(&c)
	if !testing.expect(t, ce.code == .None) {return}
	entries := []base.Geometry_Entry {
		{
			id = "disk",
			input_enabled = true,
			geometry = {
				scale = 1,
				offset = {50, 0},
				opacity = 1,
				bounds = {70, 20, 40, 40},
				content = {70, 20, 40, 40},
				clip = {70, 20, 40, 40},
				content_clip = {70, 20, 40, 40},
			},
		},
	}
	if !testing.expect(t, ui.sample_candidate(&c, {stamp, entries})) {return}
	paint, pe := style.prepare(
		&geometry,
		[]style.Description{{id = "disk", role = "button"}},
		{},
		{},
		context.allocator,
	); defer style.destroy_frame(&paint)
	if !testing.expect(t, pe.code == .None) {return}
	// Ordinary paint may already carry the same frozen visual projection. The
	// custom painter still receives layout-space coordinates, transformed once
	// by Canvas rather than a second time from sampled paint metadata.
	paint.presentation[0].area = entries[0].geometry.bounds
	mismatched, mismatch_error := create_generation(r, "bad", []Painter{{"circle", "2", disk}})
	if !testing.expect(
		t,
		mismatch_error.code == .None,
	) {return}; defer release_generation(&mismatched)
	testing.expect(
		t,
		preflight(mismatched, &c, &paint).code == .Generation &&
		preflight(generation, &c, &paint).code == .None,
	)
	sdl.SetRenderDrawColor(r, 0, 0, 0, 255); sdl.RenderClear(r)
	for contaminated in ([]bool{false, true}) {
		if contaminated {
			viewport := sdl.Rect{3, 4, 120, 80}
			clip := sdl.Rect{0, 0, 1, 1}
			if !testing.expect(
				t,
				sdl.SetRenderViewport(r, &viewport) &&
				sdl.SetRenderScale(r, 1.25, .75) &&
				sdl.SetRenderClipRect(r, &clip) &&
				sdl.SetRenderDrawColor(r, 17, 23, 31, 127) &&
				sdl.SetRenderDrawBlendMode(r, sdl.BLENDMODE_ADD),
			) {return}
		}
		before, _ := backend.save_renderer_state(r)
		e = render_node(generation, &c, &paint, "disk")
		if !testing.expect(t, e.code == .None) {return}
		after, restored := backend.save_renderer_state(r)
		testing.expect(
			t,
			restored &&
			before == after &&
			ui.hit(&c, "disk", {90, 40}) &&
			!ui.hit(&c, "disk", {70, 20}),
		)
		out, read := backend.readback(
			r,
			{160, 100},
		); if !testing.expect(t, read) {return}; defer sdl.DestroySurface(out)
		bytes := cast([^]u8)out.pixels
		testing.expect(
			t,
			bytes[40 * out.pitch + 90 * 4] == 255 && bytes[20 * out.pitch + 70 * 4] == 0,
		)
		// Clear in pixel coordinates so the second pass cannot reuse the first
		// pass's red center. Preserve the incoming state for the failure case below.
		if !contaminated {
			sdl.SetRenderDrawColor(r, 0, 0, 0, 255); sdl.RenderClear(r)
		}
	}
	failing, failure := create_generation(r, "paint-v2", []Painter{{"circle", "1", fail_draw}})
	if !testing.expect(t, failure.code == .None) {return}
	defer release_generation(&failing)
	if !testing.expect(t, retain_generation(failing)) {return}
	reader := failing; release_generation(&failing)
	defer release_generation(&reader)
	state_before, _ := backend.save_renderer_state(r)
	draw_error := render_node(reader, &c, &paint, "disk")
	state_after, state_ok := backend.save_renderer_state(r)
	testing.expect(
		t,
		draw_error.code == .Draw &&
		draw_error.node_id == "disk" &&
		state_ok &&
		state_before == state_after,
	)
}
