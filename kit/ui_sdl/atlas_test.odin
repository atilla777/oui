package ui_sdl

import base "../ui_base"
import layout "../ui_layout"
import style "../ui_style"
import "base:runtime"
import "core:mem"
import "core:testing"
import sdl "vendor:sdl3"

@(test)
atlas_page_region_retention_and_metadata :: proc(t: ^testing.T) {
	surface := sdl.CreateSurface(
		32,
		32,
		.RGBA32,
	); if !testing.expect(t, surface != nil) {return}; defer sdl.DestroySurface(surface)
	r := sdl.CreateSoftwareRenderer(
		surface,
	); if !testing.expect(t, r != nil) {return}; defer sdl.DestroyRenderer(r)
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	ledger: Resource_Ledger
	pixels: [7 * 7 * 4]u8
	catalog := style.Atlas_Catalog {
		"r",
		[]style.Atlas_Page_Metadata{{"p", {7, 7}}},
		[]style.Atlas_Region {
			{
				image = {id = "tile", source = {5, 5}},
				page_id = "p",
				rect = {1, 1, 5, 5},
				pivot = [2]f64{0.5, 1},
			},
		},
	}
	g, e := create_atlas_generation(
		r,
		catalog,
		[]Decoded_Atlas_Page{{"p", 7, 7, pixels[:]}},
		mem.tracking_allocator(&tracking),
		&ledger,
	)
	if !testing.expect(t, e.code == .None && g != nil) {return}
	testing.expect(t, ledger.live == 1 && ledger.created == 1)
	f := style.Frame {
		resource_revision = "r",
		drawable = {32, 32},
		stamp = {attempt = 1},
		presentation = []style.Presentation{{id = "image", image = catalog.regions[0].image}},
	}
	testing.expect(t, generation_matches(g, &f))
	testing.expect(t, retain_generation(g)); reader := g; release_generation(&g)
	testing.expect(t, generation_matches(reader, &f)); release_generation(&reader)
	testing.expect(
		t,
		ledger.live == 0 &&
		ledger.destroyed == 1 &&
		tracking.current_memory_allocated == 0 &&
		len(tracking.bad_free_array) == 0,
	)
}

// Numeric/pixel oracle retained from unported/atlas_test.odin, now through the
// narrow generation, style projection and painter rather than the legacy host.
@(test)
atlas_region_nine_slice_pixels_repeat_remainder_and_no_bleed :: proc(t: ^testing.T) {
	s := sdl.CreateSurface(
		32,
		32,
		.RGBA32,
	); if !testing.expect(t, s != nil) {return}; defer sdl.DestroySurface(s)
	r := sdl.CreateSoftwareRenderer(
		s,
	); if !testing.expect(t, r != nil) {return}; defer sdl.DestroyRenderer(r)
	pixels: [196]u8
	for y in 0 ..< 7 {for x in 0 ..< 7 {i := (y * 7 + x) * 4; pixels[i], pixels[i + 2], pixels[i + 3] = 255, 255, 255; if x >= 1 && x <= 5 && y >= 1 && y <= 5 {pixels[i], pixels[i + 1], pixels[i + 2] = u8((x - 1) * 40), u8((y - 1) * 40), 0}}}
	p, pe := base.create(
		context.allocator,
	); if !testing.expect(t, pe == .None) {return}; defer base.destroy(&p)
	for scale in ([]f64{1, 1.5, 2}) {for mode in style.Slice_Mode {for omit in ([]bool{false, true}) {
				stamp, _ := base.begin_attempt(&p, 0)
				catalog := style.Atlas_Catalog {
					"r",
					[]style.Atlas_Page_Metadata{{"p", {7, 7}}},
					[]style.Atlas_Region {
						{
							image = {
								id = "tile",
								source = {5, 5},
								nine_slice = style.Nine_Slice_Metadata {
									border = {1, 1, 1, 1},
									texture_scale = 1,
									edges = mode,
									center_x = mode,
									center_y = mode,
									omit_center = omit,
								},
							},
							page_id = "p",
							rect = {1, 1, 5, 5},
						},
					},
				}
				g, e := create_atlas_generation(
					r,
					catalog,
					[]Decoded_Atlas_Page{{"p", 7, 7, pixels[:]}},
					context.allocator,
				); if !testing.expect(t, e.code == .None) {return}; defer release_generation(&g)
				resources, ok := style.atlas_resources(
					catalog,
				); if !testing.expect(t, ok) {return}; defer style.destroy_atlas_resources(&resources)
				geo, le := layout.prepare(
					[]layout.Node {
						{
							id = "box",
							role = .Box,
							enabled = true,
							visible = true,
							layout = layout.Layout {
								x = {mode = .Fixed, value = 9},
								y = {mode = .Fixed, value = 9},
							},
						},
					},
					{drawable = {32, 32}, ui_scale = scale},
					{},
					context.allocator,
					stamp,
				)
				if !testing.expect(t, le.code == .None) {return}; defer layout.destroy_frame(&geo)
				d := style.Description {
					id = "box",
					visual = {kind = .Image, intrinsic = style.Extent{9, 9}},
				}; d.appearance.local.states[.Normal] = []style.Declaration {
					{.Image, style.Image_ID{"tile"}},
					{.Background, style.Color{}},
					{.Border, style.Color{}},
				}
				frame, fe := style.prepare(
					&geo,
					[]style.Description{d},
					{},
					resources,
					context.allocator,
				); if !testing.expect(t, fe.code == .None) {return}; defer style.destroy_frame(&frame)
				if !testing.expect(t, render(g, &frame)) {return}
				image, read := readback(
					r,
					{32, 32},
				); if !testing.expect(t, read) {return}; defer sdl.DestroySurface(image)
				edge := pixel_rect(frame.presentation[0].area, scale).w - 1
				atlas_pixel(
					t,
					image,
					0,
					0,
					{0, 0, 0, 255},
				); atlas_pixel(t, image, edge, edge, {160, 160, 0, 255})
				if omit {atlas_pixel(t, image, i32(4 * scale), i32(4 * scale), {16, 22, 31, 255})}
				if scale == 1 &&
				   mode == .Repeat &&
				   !omit {atlas_pixel(t, image, 7, 2, {40, 80, 0, 255}); atlas_pixel(t, image, 6, 2, {120, 80, 0, 255})}
				for y in 0 ..= edge {for x in 0 ..= edge {red, green, blue, alpha: u8; testing.expect(t, sdl.ReadSurfacePixel(image, x, y, &red, &green, &blue, &alpha)); testing.expect(t, !(red == 255 && green == 0 && blue == 255), "neighbor magenta must never bleed into region")}}
			}}}
}
atlas_pixel :: proc(t: ^testing.T, s: ^sdl.Surface, x, y: i32, expected: [4]u8) {
	r, g, b, a: u8; testing.expect(t, sdl.ReadSurfacePixel(s, x, y, &r, &g, &b, &a)); testing.expect(t, ([4]u8{r, g, b, a}) == expected)
}

Atlas_Allocation_Fault :: struct {
	backing:       mem.Allocator,
	calls, refuse: int,
}
atlas_refuse :: proc(
	p: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old: rawptr,
	old_size: int,
	loc: runtime.Source_Code_Location = #caller_location,
) -> (
	[]u8,
	mem.Allocator_Error,
) {
	f := cast(^Atlas_Allocation_Fault)p
	if size > 0 &&
	   (mode == .Alloc ||
			   mode == .Alloc_Non_Zeroed ||
			   mode == .Resize ||
			   mode ==
				   .Resize_Non_Zeroed) {f.calls += 1; if f.refuse > 0 && f.calls == f.refuse {return nil, .Out_Of_Memory}}
	return f.backing.procedure(f.backing.data, mode, size, alignment, old, old_size, loc)
}
@(test)
atlas_two_pages_binding_allocation_refusal_cleans_native_once :: proc(t: ^testing.T) {
	s := sdl.CreateSurface(
		32,
		32,
		.RGBA32,
	); if !testing.expect(t, s != nil) {return}; defer sdl.DestroySurface(s)
	r := sdl.CreateSoftwareRenderer(
		s,
	); if !testing.expect(t, r != nil) {return}; defer sdl.DestroyRenderer(r)
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	f := Atlas_Allocation_Fault {
		backing = mem.tracking_allocator(&tracking),
	}; ledger: Resource_Ledger; pixel := [4]u8{255, 255, 255, 255}
	catalog := style.Atlas_Catalog {
		"two",
		[]style.Atlas_Page_Metadata{{"a", {1, 1}}, {"b", {1, 1}}},
		[]style.Atlas_Region {
			{image = {id = "first", source = {1, 1}}, page_id = "a", rect = {0, 0, 1, 1}},
			{image = {id = "second", source = {1, 1}}, page_id = "b", rect = {0, 0, 1, 1}},
		},
	}
	requests := 0
	for refusal := 0; refusal <= requests; refusal += 1 {
		f.calls, f.refuse = 0, refusal
		g, e := create_atlas_generation(
			r,
			catalog,
			[]Decoded_Atlas_Page{{"a", 1, 1, pixel[:]}, {"b", 1, 1, pixel[:]}},
			{atlas_refuse, &f},
			&ledger,
		)
		if refusal ==
		   0 {requests = f.calls; testing.expect(t, e.code == .None)} else {testing.expect(t, e.code == .Allocation && g == nil)}
		release_generation(&g)
		testing.expect(
			t,
			ledger.live == 0 &&
			ledger.created == ledger.destroyed &&
			tracking.current_memory_allocated == 0 &&
			len(tracking.bad_free_array) == 0,
		)
	}
}
