package ui_style

import "core:mem"
import "core:strings"

// Borrowed typed metadata. Atlas coordinates never participate in layout.
Atlas_Page_Metadata :: struct {
	id:   string,
	size: [2]int,
}
Atlas_Region :: struct {
	image:   Image_Metadata,
	page_id: string,
	rect:    [4]int,
	pivot:   Maybe([2]f64),
}
Atlas_Catalog :: struct {
	revision: string,
	pages:    []Atlas_Page_Metadata,
	regions:  []Atlas_Region,
}
Atlas_Error :: struct {
	page, region, field: string,
}

atlas_pivot :: proc(region: Atlas_Region) -> Maybe([2]f64) {return region.pivot}

// The returned catalog is owned by the supplied allocator, including its IDs.
atlas_resources :: proc(
	catalog: Atlas_Catalog,
	allocator := context.allocator,
) -> (
	Resource_Catalog,
	bool,
) {
	if _, ok := validate_atlas(catalog); !ok {return {}, false}
	r: Resource_Catalog
	ok := false
	defer {if !ok {destroy_atlas_resources(&r, allocator)}}
	e: mem.Allocator_Error
	r.revision, e = strings.clone(catalog.revision, allocator)
	if e != nil {return {}, false}
	r.images, e = make([]Image_Metadata, len(catalog.regions), allocator)
	if e != nil {return {}, false}
	for region, i in catalog.regions {
		r.images[i].source = region.image.source
		r.images[i].nine_slice = region.image.nine_slice
		r.images[i].id, e = strings.clone(region.image.id, allocator)
		if e != nil {return {}, false}
	}
	ok = true
	return r, true
}
destroy_atlas_resources :: proc(resources: ^Resource_Catalog, allocator := context.allocator) {
	for image in resources.images {delete(image.id, allocator)}
	delete(resources.images, allocator)
	delete(resources.revision, allocator)
	resources^ = {}
}

validate_atlas :: proc(catalog: Atlas_Catalog) -> (Atlas_Error, bool) {
	if catalog.revision == "" {return {field = "revision"}, false}
	for p, i in catalog.pages {
		if p.id == "" {return {field = "page.id"}, false}
		for prior in catalog.pages[:i] {if prior.id == p.id {return {page = p.id, field = "page.id"}, false}}
		if p.size[0] <= 0 || p.size[1] <= 0 {return {page = p.id, field = "size"}, false}
	}
	for r, i in catalog.regions {
		e := Atlas_Error{r.page_id, r.image.id, "id"}
		if r.image.id == "" {return e, false}
		for prior in catalog.regions[:i] {if prior.image.id == r.image.id {return e, false}}
		page: ^Atlas_Page_Metadata
		for &p in catalog.pages {if p.id == r.page_id {page = &p; break}}
		if page == nil {e.field = "page"; return e, false}
		x, y, w, h := r.rect[0], r.rect[1], r.rect[2], r.rect[3]
		if x < 0 ||
		   y < 0 ||
		   w <= 0 ||
		   h <= 0 ||
		   x > page.size[0] ||
		   y > page.size[1] ||
		   w > page.size[0] - x ||
		   h > page.size[1] - y {
			e.field = "rect"; return e, false
		}
		if r.image.source != (Extent{f64(w), f64(h)}) {e.field = "source"; return e, false}
		if !valid_image_metadata(r.image) {e.field = "nine_slice"; return e, false}
		if pivot, has := r.pivot.?; has {
			for v in pivot {if !finite_nonnegative(v) || v > 1 {e.field = "pivot"; return e, false}}
		}
	}
	return {}, true
}
