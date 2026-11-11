package ui_sdl

import style "../ui_style"
import "core:mem"
import "core:strings"
import sdl "vendor:sdl3"

Code :: enum {
	None,
	Invalid,
	Allocation,
	Resource,
	Generation,
	Render,
	Readback,
	Present,
}
Error :: struct {
	code: Code,
	id:   string,
}
RGBA_Image :: struct {
	id:            string,
	width, height: i32,
	pixels:        []u8,
}
Asset_Texture :: struct {
	id:            string,
	width, height: i32,
	texture:       ^sdl.Texture,
}
Generation :: struct {
	renderer:      ^sdl.Renderer,
	revision:      string,
	images:        []Asset_Texture,
	atlas_pages:   []Asset_Texture,
	atlas_regions: []style.Atlas_Region,
	allocator:     mem.Allocator,
	readers:       u64,
	ledger:        ^Resource_Ledger, // Optional observer; must outlive all retained generations.
}
Resource_Ledger :: struct {
	created, destroyed, live, peak: u64,
}
resource_can_acquire :: proc(l: ^Resource_Ledger) -> bool {return(
		l == nil ||
		(l.created < max(u64) && l.live < max(u64)) \
	)}
resource_acquired :: proc(l: ^Resource_Ledger) {if l != nil {l.created += 1; l.live += 1; l.peak =
			max(l.peak, l.live)}}
resource_released :: proc(l: ^Resource_Ledger) {if l != nil {l.destroyed += 1; l.live -= 1}}
create_generation :: proc(
	r: ^sdl.Renderer,
	revision: string,
	images: []RGBA_Image,
	a: mem.Allocator,
	ledger: ^Resource_Ledger = nil,
) -> (
	^Generation,
	Error,
) {
	if r == nil || revision == "" {return nil, {.Invalid, ""}}
	g, e := new(Generation, a); if e != nil {return nil, {.Allocation, ""}}
	g^ = {
			renderer  = r,
			allocator = a,
			readers   = 1,
			ledger    = ledger,
		}
	complete := false; defer {if !complete {release_generation(&g)}}
	g.revision, e = strings.clone(revision, a); if e != nil {return nil, {.Allocation, ""}}
	g.images, e = make(
		[]Asset_Texture,
		len(images),
		a,
	); if e != nil {return nil, {.Allocation, ""}}
	for image, i in images {
		if image.id == "" ||
		   image.width <= 0 ||
		   image.width > max(i32) / 4 ||
		   image.height <= 0 ||
		   i64(image.width) * i64(image.height) > i64(max(int)) / 4 ||
		   len(image.pixels) !=
			   int(image.width) * int(image.height) * 4 {return nil, {.Invalid, image.id}}
		for prior in images[:i] {if prior.id == image.id {return nil, {.Invalid, image.id}}}
		out := &g.images[i]
		out.id, e = strings.clone(image.id, a); if e != nil {return nil, {.Allocation, image.id}}
		out.width, out.height = image.width, image.height
		surface := sdl.CreateSurfaceFrom(
			image.width,
			image.height,
			.RGBA32,
			raw_data(image.pixels),
			image.width * 4,
		)
		if surface == nil {return nil, {.Resource, image.id}}
		if !resource_can_acquire(
			ledger,
		) {sdl.DestroySurface(surface); return nil, {.Invalid, image.id}}
		out.texture = sdl.CreateTextureFromSurface(r, surface); sdl.DestroySurface(surface)
		if out.texture != nil {resource_acquired(ledger)}
		if out.texture == nil ||
		   !sdl.SetTextureScaleMode(out.texture, .NEAREST) ||
		   !sdl.SetTextureBlendMode(
				   out.texture,
				   sdl.BLENDMODE_BLEND,
			   ) {return nil, {.Resource, image.id}}
	}
	complete = true; return g, {}
}
retain_generation :: proc(g: ^Generation) -> bool {
	if g == nil || g.readers == max(u64) {return false}
	g.readers += 1; return true
}
release_generation :: proc(generation: ^^Generation) {
	g := generation^; generation^ = nil; if g == nil {return}
	g.readers -= 1; if g.readers > 0 {return}
	for image in g.images {if image.texture != nil {sdl.DestroyTexture(image.texture); resource_released(g.ledger)}; delete(image.id, g.allocator)}
	for image in g.atlas_pages {if image.texture != nil {sdl.DestroyTexture(image.texture); resource_released(g.ledger)}; delete(image.id, g.allocator)}
	for region in g.atlas_regions {delete(region.image.id, g.allocator); delete(region.page_id, g.allocator)}
	delete(g.atlas_pages, g.allocator); delete(g.atlas_regions, g.allocator)
	delete(g.images, g.allocator); delete(g.revision, g.allocator); free(g, g.allocator)
}
