package ui_rich_sdl

import ui ".."
import base "../../ui_base"
import layout "../../ui_layout"
import backend "../../ui_sdl"
import style "../../ui_style"
import "core:os"
import "core:testing"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

Color_Probe :: struct {
	colors: [128]base.Color,
	seen:   [128]bool,
}
color_surface :: proc(
	font: ^ttf.Font,
	value: string,
	color: base.Color,
	user: rawptr,
) -> ^sdl.Surface {
	p := cast(^Color_Probe)user
	for r in value {if r < 128 {p.colors[int(r)], p.seen[int(r)] = color, true}}
	return native_surface(font, value, color, nil)
}

fail_surface :: proc(
	font: ^ttf.Font,
	value: string,
	color: base.Color,
	user: rawptr,
) -> ^sdl.Surface {return nil}
fail_texture :: proc(_: ^sdl.Renderer, _: ^sdl.Surface, _: rawptr) -> ^sdl.Texture {return nil}
fail_native_draw :: proc(
	_: ^sdl.Renderer,
	_: ^sdl.Texture,
	_: ^sdl.FRect,
	_: ^sdl.FRect,
	_: rawptr,
) -> bool {return false}
@(test)
rich_real_render_and_failed_draw_restore_renderer_and_resources :: proc(t: ^testing.T) {
	if !testing.expect(t, ttf.Init()) {return}; defer ttf.Quit()
	surface := sdl.CreateSurface(
		240,
		200,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	r := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, r != nil) {return}; defer sdl.DestroyRenderer(r)
	data, fe := os.read_entire_file(
		"resources/font.ttf",
		context.allocator,
	); if !testing.expect(t, fe == nil) {return}; defer delete(data)
	g, ok := create_rich_generation(
		r,
		"rich-v1",
		[]RGBA_Image{{"tile", 1, 1, []u8{255, 0, 0, 255}}},
		[]Rich_Font_Source{{"default", data}},
		[]Rich_Font_Chain{{"default", nil}},
		[]Rich_Font_Request{{"default", 16, false, false, false}},
		1,
	)
	if !testing.expect(t, ok) {return}; defer release_generation(&g)
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	stamp, _ := base.begin_attempt(&p, 1)
	nodes := []layout.Node {
		{
			id = "root",
			role = .Column,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
		},
		{
			id = "text",
			parent = "root",
			role = .Content,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Content}},
		},
	}
	c, ce := ui.prepare(
		nodes,
		{drawable = {240, 200}, ui_scale = 1},
		[]ui.Description {
			{
				id = "text",
				source = "Действие / Action",
				base_style = {font_id = "default", size = 16, color = {240, 240, 240, 255}},
			},
		},
		rich_metrics(g),
		context.allocator,
		stamp,
	)
	defer ui.destroy_candidate(&c)
	if !testing.expect(t, ce.code == .None) {return}
	paint, pe := style.prepare(
		&c.geometry,
		[]style.Description{{id = "text", role = "label"}},
		{},
		{revision = "rich-v1"},
		context.allocator,
	)
	defer style.destroy_frame(&paint)
	if !testing.expect(t, pe.code == .None) {return}
	if !testing.expect(t, render_node(g, &c.frame, &paint, "text")) {return}
	// Prepared rich runs already freeze the effective base foreground (including
	// EGC coalescing). A later incompatible paint sample must not silently recolor
	// an explicit equal-color override or skip grapheme validation.
	prior_foreground := paint.presentation[0].computed[.Foreground].value
	paint.presentation[0].computed[.Foreground].value = base.Color{90, 120, 160, 255}
	testing.expect(t, !render_node(g, &c.frame, &paint, "text"))
	paint.presentation[0].computed[.Foreground].value = prior_foreground
	// Port of the former rich_state_color oracle: state foreground is resolved
	// before parsing/metrics; equal explicit overrides do not become inheritance.
	for color in ([]base.Color{{240, 240, 240, 255}, {90, 90, 90, 255}, {40, 80, 240, 255}, {40, 210, 80, 255}, {230, 180, 40, 255}}) {
		state_candidate, state_error := ui.prepare(
			nodes,
			{drawable = {240, 200}, ui_scale = 1},
			[]ui.Description {
				{
					id = "text",
					source = "A[color=#f0f0f0ff]B[/color][color=#ff0000ff]C[/color]D",
					base_style = {font_id = "default", size = 16, color = color},
				},
			},
			rich_metrics(g),
			context.allocator,
			stamp,
		)
		defer ui.destroy_candidate(&state_candidate)
		if !testing.expect(t, state_error.code == .None) {return}
		paint.presentation[0].computed[.Foreground].value = color
		probe: Color_Probe
		testing.expect(
			t,
			render_node(
				g,
				&state_candidate.frame,
				&paint,
				"text",
				{scale = 1, opacity = 1},
				{color_surface, native_texture, native_draw},
				&probe,
			),
		)
		testing.expect(
			t,
			probe.seen['A'] &&
			probe.seen['B'] &&
			probe.seen['C'] &&
			probe.seen['D'] &&
			probe.colors['A'] == color &&
			probe.colors['D'] == color &&
			probe.colors['B'] == (base.Color{240, 240, 240, 255}) &&
			probe.colors['C'] == (base.Color{255, 0, 0, 255}),
		)
	}
	paint.presentation[0].computed[.Foreground].value = prior_foreground
	before, saved := backend.save_renderer_state(r); testing.expect(t, saved)
	allocations := sdl.GetNumAllocations()
	testing.expect(
		t,
		!render_node(
			g,
			&c.frame,
			&paint,
			"text",
			draw_backend = {fail_surface, native_texture, native_draw},
		),
	)
	after, restored := backend.save_renderer_state(r)
	testing.expect(t, restored && after == before && sdl.GetNumAllocations() == allocations)
	for seam in ([]Render_Backend{{native_surface, fail_texture, native_draw}, {native_surface, native_texture, fail_native_draw}}) {
		testing.expect(t, !render_node(g, &c.frame, &paint, "text", draw_backend = seam))
		after_failure, state_ok := backend.save_renderer_state(r)
		testing.expect(
			t,
			state_ok && after_failure == before && sdl.GetNumAllocations() == allocations,
		)
	}
	image_candidate, image_error := ui.prepare(
		nodes,
		{drawable = {240, 200}, ui_scale = 1},
		[]ui.Description {
			{
				id = "text",
				source = "[img id=\"tile\" alt=\"red tile\" w=20 h=20/]",
				base_style = {font_id = "default", size = 16, color = {240, 240, 240, 255}},
			},
		},
		rich_metrics(g),
		context.allocator,
		stamp,
	)
	defer ui.destroy_candidate(&image_candidate)
	if !testing.expect(t, image_error.code == .None) {return}
	image_paint, paint_error := style.prepare(
		&image_candidate.geometry,
		[]style.Description{{id = "text", role = "label"}},
		{},
		{revision = "rich-v1"},
		context.allocator,
	)
	defer style.destroy_frame(&image_paint)
	if !testing.expect(t, paint_error.code == .None) {return}
	sdl.SetRenderDrawColor(r, 0, 0, 0, 255); sdl.RenderClear(r)
	testing.expect(t, render_node(g, &image_candidate.frame, &image_paint, "text"))
	output, read_ok := backend.readback(
		r,
		{240, 200},
	); if !testing.expect(t, read_ok) {return}; defer sdl.DestroySurface(output)
	pixels := cast([^]u8)output.pixels
	testing.expect(
		t,
		pixels[10 * output.pitch + 10 * 4] == 255 && pixels[10 * output.pitch + 30 * 4] == 0,
	)
}
