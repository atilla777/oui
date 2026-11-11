package main

import "core:fmt"
import "core:mem"
import base "ui:ui_base"
import layout "ui:ui_layout"
import backend "ui:ui_sdl"
import style "ui:ui_style"
import sdl "vendor:sdl3"

main :: proc() {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	a := mem.tracking_allocator(&tracking)
	surface := sdl.CreateSurface(
		100,
		60,
		.RGBA32,
	); assert(surface != nil); defer sdl.DestroySurface(surface)
	r := sdl.CreateSoftwareRenderer(surface); assert(r != nil); defer sdl.DestroyRenderer(r)
	p, e := base.create(a); assert(e == .None); defer base.destroy(&p)
	fmt.printf(
		"common-init allocations=%d bytes=%d live=%d peak=%d Publication=%d\n",
		tracking.total_allocation_count,
		tracking.total_memory_allocated,
		tracking.current_memory_allocated,
		tracking.peak_memory_allocated,
		size_of(base.Publication),
	)
	pixels := [4]u8{255, 0, 0, 255}; images := [1]backend.RGBA_Image{{"red", 1, 1, pixels[:]}}
	g, ge := backend.create_generation(
		r,
		"r",
		images[:],
		a,
	); assert(ge.code == .None); defer backend.release_generation(&g)
	s, _ := base.begin_attempt(&p, 0)
	nodes := [1]layout.Node {
		{
			id = "image",
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
		a,
		s,
	); assert(le.code == .None); defer layout.destroy_frame(&l)
	ds := [1]style.Description{{id = "image", role = "image"}}
	declarations := [2]style.Declaration{{.Image, style.Image_ID{"red"}}, {.Border_Width, f64(0)}}
	ds[0].appearance.local.states[.Normal] = declarations[:]
	meta := [1]style.Image_Metadata{{id = "red", source = {1, 1}}}
	f, fe := style.prepare(
		&l,
		ds[:],
		{revision = "theme"},
		{revision = "r", images = meta[:]},
		a,
	); assert(fe.code == .None); defer style.destroy_frame(&f)
	assert(backend.render(g, &f))
	read, ok := backend.readback(r, {100, 60}); assert(ok); defer sdl.DestroySurface(read)
	color: [4]u8
	assert(sdl.ReadSurfacePixel(read, 5, 5, &color[0], &color[1], &color[2], &color[3]))
	assert(color == ([4]u8{255, 0, 0, 255}))
	assert(sdl.ReadSurfacePixel(read, 90, 50, &color[0], &color[1], &color[2], &color[3]))
	assert(color == ([4]u8{16, 22, 31, 255}))
	assert(sdl.RenderPresent(r))
	fmt.printf(
		"primitive allocations=%d bytes=%d live=%d peak=%d Generation=%d images=%d fonts=0 handlers=0\n",
		tracking.total_allocation_count,
		tracking.total_memory_allocated,
		tracking.current_memory_allocated,
		tracking.peak_memory_allocated,
		size_of(backend.Generation),
		len(g.images),
	)
	style.destroy_frame(
		&f,
	); layout.destroy_frame(&l); backend.release_generation(&g); base.destroy(&p)
	fmt.printf("destroy live=%d\n", tracking.current_memory_allocated)
	assert(tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
}
