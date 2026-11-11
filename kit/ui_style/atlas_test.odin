package ui_style

import "core:mem"
import "core:testing"

@(test)
atlas_owned_resources_explicit_pivot_and_failure_cleanup :: proc(t: ^testing.T) {
	pages := [1]Atlas_Page_Metadata{{"page", {16, 16}}}
	regions := [1]Atlas_Region {
		{
			image = {id = "icon", source = {8, 8}},
			page_id = "page",
			rect = {4, 4, 8, 8},
			pivot = [2]f64{0, 1},
		},
	}
	c := Atlas_Catalog{"rev", pages[:], regions[:]}
	p, has := atlas_pivot(regions[0]).?
	testing.expect(t, has && p == ([2]f64{0, 1}))
	testing.expect(t, atlas_pivot(Atlas_Region{}) == nil)
	live: mem.Tracking_Allocator
	mem.tracking_allocator_init(&live, context.allocator)
	defer mem.tracking_allocator_destroy(&live)
	fault := Copy_Allocation_Fault {
		backing = mem.tracking_allocator(&live),
	}
	a := mem.Allocator{copy_allocation_fault, &fault}
	r, ok := atlas_resources(c, a)
	if !testing.expect(t, ok, "valid atlas produces an owned legacy catalog") {return}
	requests := fault.requests
	testing.expect(t, len(r.images) == 1 && r.images[0] == regions[0].image && r.revision == "rev")
	testing.expect(t, raw_data(r.images[0].id) != raw_data(regions[0].image.id))
	destroy_atlas_resources(&r, a)
	for n in 1 ..= requests {
		fault.requests, fault.refuse = 0, n
		r, ok = atlas_resources(c, a)
		testing.expect(t, !ok && r.revision == "" && len(r.images) == 0)
		destroy_atlas_resources(&r, a)
		testing.expect(t, len(live.allocation_map) == 0 && len(live.bad_free_array) == 0)
	}
}

@(test)
atlas_rejects_invalid_metadata_without_reinterpreting_layout :: proc(t: ^testing.T) {
	pages := [2]Atlas_Page_Metadata{{"p", {10, 10}}, {"p", {10, 10}}}
	r := Atlas_Region {
		image = {id = "i", source = {10, 10}},
		page_id = "p",
		rect = {0, 0, 10, 10},
	}
	regions := [2]Atlas_Region{r, r}
	_, ok := validate_atlas({"rev", pages[:], regions[:1]})
	testing.expect(t, !ok)
	_, ok = validate_atlas({"rev", pages[:1], regions[:]})
	testing.expect(t, !ok)
	for bad in ([]Atlas_Region{{image = r.image, page_id = "missing", rect = r.rect}, {image = r.image, page_id = "p", rect = {-1, 0, 10, 10}}, {image = r.image, page_id = "p", rect = {0, 0, 0, 10}}, {image = r.image, page_id = "p", rect = r.rect, pivot = [2]f64{0, 1.01}}, {image = r.image, page_id = "p", rect = r.rect, pivot = [2]f64{-0.01, 0}}, {image = r.image, page_id = "p", rect = r.rect, pivot = [2]f64{transmute(f64)u64(0x7ff8000000000000), 0}}}) {
		regions[0] = bad
		_, ok = validate_atlas({"rev", pages[:1], regions[:1]})
		testing.expect(t, !ok)
	}
	regions[0] = r
	regions[0].image.nine_slice = Nine_Slice_Metadata {
		border        = {8, 0, 8, 0},
		texture_scale = 1,
	}
	e, accepted := validate_atlas({"rev", pages[:1], regions[:1]})
	testing.expect(t, !accepted && e.field == "nine_slice")
}

@(test)
atlas_validation_source_local_and_addressed :: proc(t: ^testing.T) {
	pages := [1]Atlas_Page_Metadata{{"page", {32, 16}}}
	regions := [2]Atlas_Region {
		{image = {id = "left", source = {8, 10}}, page_id = "page", rect = {0, 1, 8, 10}},
		{image = {id = "right", source = {12, 16}}, page_id = "page", rect = {20, 0, 12, 16}},
	}
	c := Atlas_Catalog{"rev", pages[:], regions[:]}
	e, ok := validate_atlas(c)
	testing.expect(t, ok, "valid named regions on one page must be accepted")
	testing.expect_value(t, e, Atlas_Error{})
	regions[1].rect[0] = max(int)
	e, ok = validate_atlas(c)
	testing.expect(t, !ok)
	testing.expect_value(t, e, Atlas_Error{"page", "right", "rect"})
	regions[1].rect[0] = 20
	regions[1].image.source.w = 13
	e, ok = validate_atlas(c)
	testing.expect(t, !ok)
	testing.expect_value(t, e.field, "source")
}
