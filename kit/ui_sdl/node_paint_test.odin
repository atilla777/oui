package ui_sdl

import base "../ui_base"
import style "../ui_style"
import "core:testing"
import sdl "vendor:sdl3"

@(test)
node_paint_preserves_other_pixels_and_renderer_state :: proc(t: ^testing.T) {
	s := sdl.CreateSurface(
		20,
		10,
		.RGBA32,
	); if !testing.expect(t, s != nil) {return}; defer sdl.DestroySurface(s)
	r := sdl.CreateSoftwareRenderer(
		s,
	); if !testing.expect(t, r != nil) {return}; defer sdl.DestroyRenderer(r)
	g, e := create_generation(
		r,
		"images",
		nil,
		context.allocator,
	); if !testing.expect(t, e.code == .None) {return}; defer release_generation(&g)
	p := style.Presentation {
		id         = "left",
		drawable   = true,
		area       = {0, 0, 10, 10},
		paint_clip = {0, 0, 20, 10},
	}
	p.computed[.Background].value = style.Color{255, 0, 0, 255}
	p.computed[.Border].value = style.Color{}
	p.computed[.Foreground].value = style.Color{}
	ps := [1]style.Presentation{p}
	f := style.Frame {
		presentation = ps[:],
		drawable = {20, 10},
		ui_scale = 1,
		resource_revision = "images",
		stamp = base.Frame_Stamp{attempt = 1},
	}
	sdl.SetRenderDrawColor(r, 0, 255, 0, 255); sdl.RenderClear(r)
	before, _ := save_renderer_state(r)
	testing.expect(
		t,
		paint_node(g, &f, "left"),
		"selected node must draw without clearing the target",
	)
	after, _ := save_renderer_state(r); testing.expect(t, before == after)
	pixels, ok := readback(
		r,
		{20, 10},
	); if !testing.expect(t, ok) {return}; defer sdl.DestroySurface(pixels)
	b := cast([^]u8)(pixels.pixels)
	testing.expect(
		t,
		b[0] == 255 && b[1] == 0 && b[4 * 15] == 0 && b[4 * 15 + 1] == 255,
		"node rendering must leave unrelated pixels untouched",
	)
	ps[0].focus_indicator = true; ps[0].focus_width = 1; ps[0].focus_color = {255, 255, 255, 255}
	testing.expect(t, paint_node(g, &f, "left", true), "focus is a separately ordered command")
}
