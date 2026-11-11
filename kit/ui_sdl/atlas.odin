package ui_sdl

import style "../ui_style"
import "core:mem"
import "core:strings"
import sdl "vendor:sdl3"

Decoded_Atlas_Page :: struct {
	page_id:       string,
	width, height: i32,
	pixels:        []u8,
}
// D1-A1: the former atlas page/region binding, without text/font ownership.
create_atlas_generation :: proc(
	r: ^sdl.Renderer,
	catalog: style.Atlas_Catalog,
	pages: []Decoded_Atlas_Page,
	a: mem.Allocator,
	ledger: ^Resource_Ledger = nil,
) -> (
	^Generation,
	Error,
) {
	if _, ok := style.validate_atlas(catalog); !ok {return nil, {code = .Invalid}}
	if len(pages) != len(catalog.pages) {return nil, {code = .Invalid}}
	images, ae := make(
		[]RGBA_Image,
		len(pages),
		a,
	); if ae != nil {return nil, {code = .Allocation}}; defer delete(images, a)
	for p, i in pages {
		for prior in pages[:i] {if prior.page_id == p.page_id {return nil, {.Invalid, p.page_id}}}
		found := false
		for meta in catalog.pages {if meta.id == p.page_id {found = meta.size == ([2]int{int(p.width), int(p.height)})}}
		if !found {return nil, {.Invalid, p.page_id}}; images[i] = {p.page_id, p.width, p.height, p.pixels}
	}
	g, e := create_generation(
		r,
		catalog.revision,
		images,
		a,
		ledger,
	); if e.code != .None {return nil, e}
	complete := false; defer {if !complete {release_generation(&g)}}
	g.atlas_pages = g.images; g.images = nil
	g.atlas_regions, ae = make(
		[]style.Atlas_Region,
		len(catalog.regions),
		a,
	); if ae != nil {return nil, {code = .Allocation}}
	for region, i in catalog.regions {
		out := &g.atlas_regions[i]
		out.rect, out.pivot = region.rect, region.pivot
		out.image.source, out.image.nine_slice = region.image.source, region.image.nine_slice
		out.image.id, ae = strings.clone(
			region.image.id,
			a,
		); if ae != nil {return nil, {code = .Allocation}}
		out.page_id, ae = strings.clone(
			region.page_id,
			a,
		); if ae != nil {return nil, {code = .Allocation}}
	}
	complete = true; return g, {}
}

@(private)
Resolved_Image :: struct {
	texture:  ^sdl.Texture,
	rect:     sdl.FRect,
	metadata: style.Image_Metadata,
	atlas:    bool,
}
@(private)
resolve_image :: proc(g: ^Generation, id: string) -> (Resolved_Image, bool) {
	if g == nil {return {}, false}
	for region in g.atlas_regions {if region.image.id == id {
			for page in g.atlas_pages {if page.id == region.page_id {
					return {
							page.texture,
							{
								f32(region.rect[0]),
								f32(region.rect[1]),
								f32(region.rect[2]),
								f32(region.rect[3]),
							},
							region.image,
							true,
						},
						true
				}}
			return {}, false
		}}
	for image in g.images {if image.id == id {return {image.texture, {0, 0, f32(image.width), f32(image.height)}, {id = image.id, source = {f64(image.width), f64(image.height)}}, false}, true}}
	return {}, false
}
