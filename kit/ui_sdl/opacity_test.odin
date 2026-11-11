package ui_sdl

import base "../ui_base"
import style "../ui_style"
import "core:testing"
import sdl "vendor:sdl3"

@(test)
per_draw_image_opacity_restores_retained_texture_modulation :: proc(t: ^testing.T) {
	s := sdl.CreateSurface(4, 4, .RGBA32); defer sdl.DestroySurface(s)
	r := sdl.CreateSoftwareRenderer(s); defer sdl.DestroyRenderer(r)
	pixels := [4]u8{255, 255, 255, 255}; images := [1]RGBA_Image{{"tile", 1, 1, pixels[:]}}
	g, e := create_generation(
		r,
		"v",
		images[:],
		context.allocator,
	); if !testing.expect(t, e.code == .None) {return}; defer release_generation(&g)
	p := [1]style.Presentation {
		{
			id = "image",
			drawable = true,
			area = {0, 0, 4, 4},
			paint_clip = {0, 0, 4, 4},
			image = style.Image_Metadata{"tile", {1, 1}, nil},
			patches = []style.Image_Patch{{source = {0, 0, 1, 1}, destination = {0, 0, 4, 4}}},
		},
	}
	p[0].computed[.Background].value =
		style.Color{}; p[0].computed[.Border].value = style.Color{}; p[0].computed[.Foreground].value = style.Color{}
	f := style.Frame {
			presentation = p[:],
			resource_revision = "v",
			drawable = {4, 4},
			ui_scale = 1,
			stamp = base.Frame_Stamp{attempt = 1},
		}
	sdl.SetRenderDrawColor(r, 0, 0, 0, 255); sdl.RenderClear(r)
	sdl.SetTextureAlphaModFloat(g.images[0].texture, 0.8)
	testing.expect(t, paint_node(g, &f, "image", false, 0.5))
	a: f32; sdl.GetTextureAlphaModFloat(g.images[0].texture, &a); testing.expect(t, a == 0.8)
	out, ok := readback(
		r,
		{4, 4},
	); if !testing.expect(t, ok) {return}; defer sdl.DestroySurface(out)
	b := cast([^]u8)out.pixels; testing.expect(t, b[0] >= 99 && b[0] <= 103, "existing alpha 0.8 times per-draw 0.5, not overwrite/global leak")
}

@(test)
missing_image_fallback_uses_the_same_per_draw_opacity :: proc(t: ^testing.T) {
	s := sdl.CreateSurface(
		4,
		4,
		.RGBA32,
	); defer sdl.DestroySurface(s); r := sdl.CreateSoftwareRenderer(s); defer sdl.DestroyRenderer(r)
	g, e := create_generation(
		r,
		"v",
		nil,
		context.allocator,
	); if !testing.expect(t, e.code == .None) {return}; defer release_generation(&g)
	p := [1]style.Presentation {
		{
			id = "missing",
			drawable = true,
			area = {0, 0, 4, 4},
			paint_clip = {0, 0, 4, 4},
			fallback = style.Rect{0, 0, 4, 4},
		},
	}
	p[0].computed[.Background].value =
		style.Color{}; p[0].computed[.Border].value = style.Color{}; p[0].computed[.Foreground].value = style.Color{}
	f := style.Frame {
			presentation = p[:],
			resource_revision = "v",
			drawable = {4, 4},
			ui_scale = 1,
			stamp = base.Frame_Stamp{attempt = 1},
		}
	sdl.SetRenderDrawColor(
		r,
		0,
		0,
		0,
		255,
	); sdl.RenderClear(r); testing.expect(t, paint_node(g, &f, "missing", false, 0.5))
	out, ok := readback(
		r,
		{4, 4},
	); if !testing.expect(t, ok) {return}; defer sdl.DestroySurface(out)
	b := cast([^]u8)out.pixels; testing.expect(t, b[0] >= 125 && b[0] <= 128 && b[2] >= 125 && b[2] <= 128)
}
