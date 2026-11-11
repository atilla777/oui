package main

import "core:fmt"
import "core:os"
import "core:testing"
import base "ui:ui_base"
import layout "ui:ui_layout"
import fonts "ui:ui_sdl_text"

@(test)
fixed_label_offsets_are_honored_by_composite_button_geometry :: proc(t: ^testing.T) {
	e: Render_Env; if !init_render_env(&e, t) {return}; defer destroy_render_env(&e); testing.expect(t, publish(&e.r))
	a, _ := layout.find(
		&e.r.reader.geometry,
		"check-label",
	); b, _ := layout.find(&e.r.reader.geometry, "slider-label")
	testing.expect(
		t,
		a.content.x == 4 && a.content.y == 2 && b.content.x == 4 && b.content.y == 42,
		"labels must use the declared inset, matching supplied frozen transforms",
	)
}

@(test)
text_node_refuses_nonfinite_transform_before_touching_renderer :: proc(t: ^testing.T) {
	e: Render_Env; if !init_render_env(&e, t) {return}; defer destroy_render_env(&e); testing.expect(t, publish(&e.r))
	before, _ := backend.save_renderer_state(e.renderer)
	f := &e.r.reader.render
	testing.expect(
		t,
		!fonts.render_node(
			f.fonts,
			&f.text,
			&f.paint,
			"slider-label",
			{scale = 1, opacity = 1, offset = {transmute(f64)u64(0x7ff8000000000000), 0}},
		),
	)
	after, _ := backend.save_renderer_state(e.renderer); testing.expect(t, before == after)
}

@(test)
controlled_checkbox_and_slider_model_values_rebuild_visible_text :: proc(t: ^testing.T) {
	e: Render_Env; if !init_render_env(&e, t) {return}; defer destroy_render_env(&e)
	e.r.checked = true; e.r.value = 80; e.r.render.russian = true; testing.expect(t, publish(&e.r))
	checked, value := false, false
	for b in e.r.reader.render.text.text_blocks {if b.node_id == "check-label" {checked = b.original_text == "[x] Да"}; if b.node_id == "slider-label" {value = b.original_text == "Уровень: 80"}}
	testing.expect(t, checked && value && render_current(&e.r))
}

@(test)
dialog_result_button_has_localized_text_in_the_same_bundle :: proc(t: ^testing.T) {
	e: Render_Env; if !init_render_env(&e, t) {return}; defer destroy_render_env(&e); e.r.modal = true; e.r.render.russian = true
	testing.expect(t, publish(&e.r)); found := false
	for b in e.r.reader.render.text.text_blocks {if b.node_id == "ok-label" && b.original_text == "ОК" {found = true}}
	testing.expect(
		t,
		found && render_current(&e.r),
		"Dialog result label is not a separate stale or missing text path",
	)
}
import controls "ui:ui_controls"

@(test)
sampled_scale_offset_opacity_text_and_native_hit_agree :: proc(t: ^testing.T) {
	e: Render_Env; if !init_render_env(&e, t) {return}; defer destroy_render_env(&e)
	samples := [3]base.Geometry_Entry {
		{
			id = "slider",
			input_enabled = true,
			geometry = {
				scale = 2,
				offset = {100, -40},
				opacity = 0.5,
				bounds = {100, 40, 200, 60},
				content = {100, 40, 200, 60},
				clip = {100, 40, 200, 60},
				content_clip = {100, 40, 200, 60},
			},
		},
		{
			id = "track",
			input_enabled = true,
			geometry = {
				scale = 2,
				offset = {100, -40},
				opacity = 0.5,
				bounds = {100, 40, 200, 40},
				content = {100, 40, 200, 40},
				clip = {100, 40, 200, 40},
				content_clip = {100, 40, 200, 40},
			},
		},
		{
			id = "slider-label",
			input_enabled = true,
			geometry = {
				scale = 2,
				offset = {100, -40},
				opacity = 0.5,
				bounds = {108, 44, 176, 48},
				content = {108, 44, 176, 48},
				clip = {108, 44, 176, 48},
				content_clip = {108, 44, 176, 48},
			},
		},
	}
	testing.expect(t, publish(&e.r, samples[:]))
	surface, ok := readback_current(
		&e.r,
	); if !testing.expect(t, ok) {return}; defer sdl.DestroySurface(surface)
	c := pixel(
		surface,
		250,
		80,
	); testing.expect(t, c[1] >= 90 && c[1] <= 100, "sample opacity blends primitive into base instead of drawing opaque green")
	ink :=
		false; for y in 44 ..< 78 {for x in 150 ..< 182 {p := pixel(surface, x, y); if p[0] > 70 && p[2] > 70 {ink = true}}}
	testing.expect(
		t,
		ink,
		"text is scaled and offset into the same sampled node, not merely translated",
	)
	a := button(
		&e.r,
		150,
		50,
		true,
	); testing.expect(t, a.control.event != nil && a.control.event.?.value == 30)
}

@(test)
selected_image_is_painted_from_the_same_retained_generation :: proc(t: ^testing.T) {
	e: Render_Env; if !init_render_env(&e, t) {return}; defer destroy_render_env(&e)
	testing.expect(
		t,
		publish(&e.r),
	); surface, ok := readback_current(&e.r); if !testing.expect(t, ok) {return}; defer sdl.DestroySurface(surface)
	testing.expect(
		t,
		pixel(surface, 310, 10) == ([4]u8{240, 240, 240, 255}),
		"selected image node uses bundle generation rather than a detached resource",
	)
}

@(test)
covered_text_stays_below_popup_and_tooltip_is_above_popup_without_taking_hit :: proc(
	t: ^testing.T,
) {
	e: Render_Env; if !init_render_env(&e, t) {return}; defer destroy_render_env(&e)
	e.r.popup = true
	samples := [1]base.Geometry_Entry {
		{
			id = "tip",
			input_enabled = false,
			geometry = {
				scale = 1,
				offset = {0, 40},
				opacity = 1,
				bounds = {0, 40, 100, 30},
				content = {0, 40, 100, 30},
				clip = {0, 40, 100, 30},
				content_clip = {0, 40, 100, 30},
			},
		},
	}
	testing.expect(t, publish(&e.r, samples[:]))
	surface, ok := readback_current(
		&e.r,
	); if !testing.expect(t, ok) {return}; defer sdl.DestroySurface(surface)
	ink :=
		false; for y in 84 ..< 101 {for x in 4 ..< 70 {p := pixel(surface, x, y); if p[0] > 150 {ink = true}}}
	testing.expect(t, !ink, "hold text must not be repainted globally after the covering popup")
	top := pixel(
		surface,
		60,
		60,
	); testing.expect(t, top[0] > 100 && top[2] < 200, "tooltip blends after popup rather than before it")
	button(&e.r, 10, 50, true); testing.expect(t, publish(&e.r, samples[:]))
	a := button(
		&e.r,
		10,
		50,
		false,
	); testing.expect(t, a.control.event != nil && a.control.event.?.kind == .Item)
}

@(test)
invalid_render_transform_refuses_before_live_swap :: proc(t: ^testing.T) {
	e: Render_Env; if !init_render_env(&e, t) {return}; defer destroy_render_env(&e)
	testing.expect(t, publish(&e.r)); stamp := e.r.ctx.frame.stamp
	for bad_offset in ([]bool{false, true}) {
		v := base.Frozen_Geometry {
			scale   = 1,
			opacity = 1.5,
			bounds  = {0, 40, 100, 30},
			clip    = {0, 40, 100, 30},
		}
		if bad_offset {v.opacity = 1; v.offset[0] = transmute(f64)u64(0x7ff8000000000000)}
		samples := [1]base.Geometry_Entry{{id = "slider", input_enabled = true, geometry = v}}
		testing.expect(
			t,
			!publish(&e.r, samples[:]) && e.r.ctx.frame.stamp == stamp && !e.r.p.ready,
			"unrenderable sample is a candidate refusal, not a committed broken renderer",
		)
	}
}
import backend "ui:ui_sdl"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

pixel :: proc(surface: ^sdl.Surface, x, y: int) -> [4]u8 {p := cast([^]u8)surface.pixels; at :=
		y * int(surface.pitch) + x * 4
	return {p[at], p[at + 1], p[at + 2], p[at + 3]}}

@(test)
layer_node_text_scrim_focus_order_and_state_are_observable_in_software_pixels :: proc(
	t: ^testing.T,
) {
	e: Render_Env; if !init_render_env(&e, t) {return}; defer destroy_render_env(&e)
	e.r.modal = true; e.r.popup = true; testing.expect(t, publish(&e.r))
	clip := sdl.Rect{7, 8, 20, 21}; view := sdl.Rect{3, 4, 350, 250}
	sdl.SetRenderLogicalPresentation(
		e.renderer,
		200,
		150,
		.LETTERBOX,
	); sdl.SetRenderViewport(e.renderer, &view); sdl.SetRenderScale(e.renderer, 1.25, 1.5); sdl.SetRenderClipRect(e.renderer, &clip); sdl.SetRenderDrawColor(e.renderer, 17, 23, 31, 123); sdl.SetRenderDrawBlendMode(e.renderer, sdl.BLENDMODE_ADD)
	before, ok := backend.save_renderer_state(e.renderer); testing.expect(t, ok)
	testing.expect(t, render_current(&e.r))
	after, _ := backend.save_renderer_state(e.renderer); testing.expect(t, before == after)
	surface, read := readback_current(
		&e.r,
	); if !testing.expect(t, read && surface != nil) {return}; defer sdl.DestroySurface(surface)
	testing.expect(
		t,
		pixel(surface, 300, 250) == ([4]u8{11, 15, 23, 255}),
		fmt.tprintf("base is below modal scrim, pixel=%v", pixel(surface, 300, 250)),
	)
	testing.expect(
		t,
		pixel(surface, 60, 100) == ([4]u8{9, 29, 109, 255}),
		fmt.tprintf(
			"base-owned popup is also below modal scrim, pixel=%v",
			pixel(surface, 60, 100),
		),
	)
	testing.expect(
		t,
		pixel(surface, 340, 90) == ([4]u8{210, 110, 20, 255}),
		"modal node paints after scrim",
	)
	testing.expect(
		t,
		pixel(surface, 200, 0) == ([4]u8{255, 255, 255, 255}),
		"focus command paints after modal descendants",
	)
	final, _ := backend.save_renderer_state(e.renderer); testing.expect(t, before == final)
}

@(test)
ru_en_text_is_real_and_generation_readers_survive_runtime_destroy :: proc(t: ^testing.T) {
	e: Render_Env; if !init_render_env(&e, t) {return}; defer {delete(e.data); sdl.DestroyRenderer(e.renderer); sdl.DestroySurface(e.surface); ttf.Quit()}
	for ru in ([]bool{false, true}) {
		e.r.render.russian =
			ru; testing.expect(t, publish(&e.r)); testing.expect(t, render_current(&e.r))
		word := "[ ] Yes"; if ru {word = "[ ] Да"}
		found :=
			false; for b in e.r.reader.render.text.text_blocks {if b.node_id == "check-label" {found = b.original_text == word && len(b.lines) > 0}}
		testing.expect(t, found)
	}
	controls.dispatch(
		&e.r.controls,
		&e.r.ctx,
		{kind = .Focus, id = "hold", source = .Agent},
		&e.r.layers,
		&e.r.scroll,
	); testing.expect(t, publish(&e.r))
	saved := e.r.reader; e.r.reader = {}; destroy(&e.r)
	testing.expect(
		t,
		e.font_ledger.live == 1 &&
		e.image_ledger.live == 1 &&
		!saved.render.paint.stamp.lifetime.alive,
	)
	testing.expect(t, backend.paint_node(saved.render.images, &saved.render.paint, "hold"))
	destroy_reader(&saved); testing.expect(t, e.font_ledger.live == 0 && e.image_ledger.live == 0)
}

Render_Env :: struct {
	r:                         Runtime,
	surface:                   ^sdl.Surface,
	renderer:                  ^sdl.Renderer,
	data:                      []u8,
	font_ledger, image_ledger: backend.Resource_Ledger,
}
init_render_env :: proc(e: ^Render_Env, t: ^testing.T) -> bool {
	if !testing.expect(t, ttf.Init()) {return false}
	e.surface = sdl.CreateSurface(
		400,
		300,
		.RGBA32,
	); e.renderer = sdl.CreateSoftwareRenderer(e.surface)
	if !testing.expect(t, e.surface != nil && e.renderer != nil) {return false}
	data, err := os.read_entire_file(
		"resources/font.ttf",
		context.allocator,
	); if !testing.expect(t, err == nil) {return false}; e.data = data
	init(&e.r); e.r.render = {
		renderer       = e.renderer,
		font_data      = data,
		font_revision  = "font-1",
		image_revision = "image-1",
		font_ledger    = &e.font_ledger,
		image_ledger   = &e.image_ledger,
	}
	return true
}
destroy_render_env :: proc(e: ^Render_Env) {destroy(&e.r); delete(e.data); sdl.DestroyRenderer(
		e.renderer,
	)
	sdl.DestroySurface(e.surface)
	ttf.Quit()}

@(test)
render_publisher_owns_text_style_and_resource_generations_before_swap :: proc(t: ^testing.T) {
	e: Render_Env; if !init_render_env(&e, t) {return}; defer destroy_render_env(&e)
	if !testing.expect(t, publish(&e.r)) {return}
	f := &e.r.reader.render
	testing.expect(
		t,
		f.images != nil &&
		f.fonts != nil &&
		len(f.text.text_blocks) > 0 &&
		len(f.paint.presentation) > 0 &&
		f.text.stamp == e.r.ctx.frame.stamp &&
		f.paint.stamp == e.r.ctx.frame.stamp,
	)
	testing.expect(
		t,
		render_current(&e.r),
		"selected render executes its immutable layer/text/focus bundle",
	)
}
