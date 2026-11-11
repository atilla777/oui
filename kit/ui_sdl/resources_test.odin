package ui_sdl

import base "../ui_base"
import layout "../ui_layout"
import style "../ui_style"
import "core:mem"
import "core:testing"
import sdl "vendor:sdl3"

@(test)
fractional_scale_keeps_integer_pixel_edges :: proc(t: ^testing.T) {
	for pixel_y in 0 ..< 600 {
		rect := pixel_rect({0, f64(pixel_y) / 1.5, 100, 1 / 1.5}, 1.5)
		if !testing.expect(t, rect == (sdl.Rect{0, i32(pixel_y), 150, 1})) {return}
	}
}

@(test)
resources_retention_and_render_state :: proc(t: ^testing.T) {
	surface := sdl.CreateSurface(
		100,
		60,
		.RGBA32,
	); testing.expect(t, surface != nil); if surface == nil {return}; defer sdl.DestroySurface(surface)
	r := sdl.CreateSoftwareRenderer(
		surface,
	); testing.expect(t, r != nil); if r == nil {return}; defer sdl.DestroyRenderer(r)
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	a := mem.tracking_allocator(&tracking)
	pixels := [4]u8{255, 0, 0, 255}
	images := [1]RGBA_Image{{"red", 1, 1, pixels[:]}}
	ledger: Resource_Ledger
	g, e := create_generation(r, "resources-1", images[:], a, &ledger)
	testing.expect(t, e.code == .None && g != nil)
	if g == nil {return}
	testing.expect(t, ledger.created == 1 && ledger.live == 1 && ledger.peak == 1)
	testing.expect(t, retain_generation(g) && g.readers == 2)
	reader := g; release_generation(&g)
	testing.expect(t, g == nil && reader.readers == 1 && reader.images[0].id == "red")
	release_generation(&reader)
	testing.expect(t, ledger.destroyed == 1 && ledger.live == 0)
	testing.expect(t, reader == nil && tracking.current_memory_allocated == 0)
	bad := [1]RGBA_Image{{"bad", 2, 1, pixels[:]}}
	g, e = create_generation(r, "x", bad[:], a)
	testing.expect(t, g == nil && e.code != .None && tracking.current_memory_allocated == 0)
}

@(test)
renderer_and_readback_restore_state :: proc(t: ^testing.T) {
	surface := sdl.CreateSurface(
		100,
		60,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	r := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, r != nil) {return}; defer sdl.DestroyRenderer(r)
	g, e := create_generation(
		r,
		"r",
		nil,
		context.allocator,
	); if !testing.expect(t, e.code == .None) {return}; defer release_generation(&g)
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s, _ := base.begin_attempt(&p, 0)
	nodes := [1]layout.Node {
		{
			id = "box",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 40},
				y = {mode = .Fixed, value = 20},
			},
		},
	}
	l, le := layout.prepare(
		nodes[:],
		{drawable = {100, 60}, ui_scale = 1},
		{},
		context.allocator,
		s,
	); testing.expect(t, le.code == .None); defer layout.destroy_frame(&l)
	ds := [1]style.Description{{id = "box", role = "button"}}
	f, fe := style.prepare(
		&l,
		ds[:],
		{revision = "theme"},
		{revision = "r"},
		context.allocator,
	); testing.expect(t, fe.code == .None); defer style.destroy_frame(&f)
	sdl.SetRenderDrawColor(r, 9, 8, 7, 6); sdl.SetRenderScale(r, 2, 3)
	clip := sdl.Rect{1, 2, 20, 10}; sdl.SetRenderClipRect(r, &clip)
	before, ok := save_renderer_state(r); testing.expect(t, ok)
	testing.expect(t, render(g, &f))
	after, saved := save_renderer_state(r); testing.expect(t, saved && before == after)
	read, read_ok := readback(r, {100, 60}); testing.expect(t, read_ok && read != nil)
	if read != nil {testing.expect(t, read.w == 100 && read.h == 60); sdl.DestroySurface(read)}
	after, saved = save_renderer_state(r); testing.expect(t, saved && before == after)
	old_revision := f.resource_revision
	f.resource_revision = "wrong"
	testing.expect(t, !render(g, &f))
	f.resource_revision = old_revision
	target := sdl.CreateTexture(r, .RGBA8888, .TARGET, 50, 30)
	if testing.expect(t, target != nil) {
		testing.expect(t, sdl.SetRenderTarget(r, target))
		wrong, valid := readback(r, {100, 60})
		testing.expect(t, !valid && wrong == nil)
		if wrong != nil {sdl.DestroySurface(wrong)}
		testing.expect(t, sdl.GetRenderTarget(r) == target)
		sdl.SetRenderTarget(r, nil); sdl.DestroyTexture(target)
	}
}
