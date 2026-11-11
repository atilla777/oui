package ui_rich_sdl

import base "../../ui_base"
import backend "../../ui_sdl"
import text_backend "../../ui_sdl_text"
import "core:mem"
import "core:strings"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

RGBA_Image :: backend.RGBA_Image
// A Font value has one owner: this selected rich generation, never a second
// ui_sdl_text.Generation. Source bytes live in rich_sources until all fonts close.
Adapter :: text_backend.Font
Generation :: struct {
	renderer:     ^sdl.Renderer,
	revision:     string,
	scale:        f64,
	readers:      u64,
	allocator:    mem.Allocator,
	images:       ^backend.Generation,
	rich_sources: [dynamic]Rich_Native_Source,
	rich_fonts:   [dynamic]Rich_Native_Font,
}
create :: proc(data: []u8, size, scale: f64) -> (Adapter, bool) {
	if len(data) == 0 ||
	   !base.finite(size) ||
	   size <= 0 ||
	   !base.finite(scale) ||
	   scale <= 0 ||
	   !base.finite(size * scale) ||
	   size * scale > f64(max(f32)) {return {}, false}
	stream := sdl.IOFromConstMem(
		raw_data(data),
		uint(len(data)),
	); if stream == nil {return {}, false}
	font := ttf.OpenFontIO(stream, true, f32(size * scale)); if font == nil {return {}, false}
	return {
			font = font,
			size = size,
			scale = scale,
			native_revision = ttf.GetFontGeneration(font),
		},
		true
}
destroy :: proc(f: ^Adapter) {if f.font != nil {ttf.CloseFont(f.font)}; f^ = {}}
new_generation :: proc(
	r: ^sdl.Renderer,
	revision: string,
	images: []RGBA_Image,
	scale: f64,
	a: mem.Allocator,
	error_out: ^backend.Error,
) -> (
	^Generation,
	bool,
) {
	if r == nil ||
	   revision == "" ||
	   !base.finite(scale) ||
	   scale <= 0 {return nil, creation_failure(error_out, .Invalid)}
	g, ae := new(
		Generation,
		a,
	); if ae != nil {return nil, creation_failure(error_out, .Allocation)}
	g^ = {
		renderer  = r,
		readers   = 1,
		scale     = scale,
		allocator = a,
	}
	complete := false; defer {if !complete {release_generation(&g)}}
	g.revision, ae = strings.clone(
		revision,
		a,
	); if ae != nil {return nil, creation_failure(error_out, .Allocation)}
	error: backend.Error
	g.images, error = backend.create_generation(
		r,
		revision,
		images,
		a,
	); if error.code != .None {return nil, creation_failure(error_out, error.code, error.id)}
	complete = true; return g, true
}
retain_generation :: proc(g: ^Generation) -> bool {if g == nil || g.readers == max(u64) {return(
			false \
		)}
	g.readers += 1
	return true}
release_generation :: proc(generation: ^^Generation) {
	g := generation^; generation^ = nil; if g == nil {return}
	g.readers -= 1; if g.readers > 0 {return}
	destroy_rich_fonts(g); backend.release_generation(&g.images)
	delete(g.revision, g.allocator); free(g, g.allocator)
}
Image :: struct {
	texture: ^sdl.Texture,
	rect:    sdl.FRect,
}
resolve_image :: proc(g: ^Generation, id: string) -> (Image, bool) {
	if g == nil || g.images == nil {return {}, false}
	for asset in g.images.images {if asset.id == id {return {asset.texture, {0, 0, f32(asset.width), f32(asset.height)}}, true}}
	return {}, false
}
