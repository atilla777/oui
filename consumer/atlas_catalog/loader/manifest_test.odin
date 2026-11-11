package loader

import "core:mem"
import "core:strings"
import "core:testing"

@(test)
manifest_rejects_schema_and_budget_faults_without_partial_owners :: proc(t: ^testing.T) {
	live: mem.Tracking_Allocator
	mem.tracking_allocator_init(
		&live,
		context.allocator,
	); defer mem.tracking_allocator_destroy(&live)
	a := mem.tracking_allocator(&live)
	for source in ([]string{`{"version":2,"pages":[],"regions":[]}`, `{"version":1,"version":1,"pages":[],"regions":[]}`, `{"version":1,"pages":[],"regions":[],"extra":0}`, `{"version":1,"pages":null,"regions":[]}`, `{"version":1,"pages":[{"id":"p","file":"p.png","file":"q.png"}],"regions":[]}`, `{"version":1,"pages":[{"id":"p","file":"p.png"},{"id":"p","file":"q.png"}],"regions":[]}`, `{"version":1,"pages":[],"regions":[{"id":"r","page":"missing","rect":[0,0,2,2]}]}`, `{"version":1,"pages":[],"regions":[{"id":"r","page":"p","rect":[0,0,1.5,2]}]}`, `{"version":1,"pages":[],"regions":[{"id":"r","page":"p","rect":[0,0,-1,2]}]}`, `{"version":1,"pages":[],"regions":[{"id":"r","page":"p","rect":[0,0,2,2],"pivot":[1.01,0]}]}`, `{"version":1,"pages":[],"regions":[{"id":"r","page":"p","rect":[0,0,2,2],"pivot":null}]}`, `{"version":1,"pages":[],"regions":[{"id":"r","page":"p","rect":[0,0,2,2],"nine_slice":{"border":[2,0,2,0],"texture_scale":1,"edges":"repeat","center_x":"stretch","center_y":"repeat","omit_center":false}}]}`, `{"version":1,"pages":[],"regions":[]} true`}) {
		m, e := parse_manifest(transmute([]u8)source, a)
		testing.expect(t, e.stage != "" && e.field != "", source)
		destroy_manifest(&m)
		testing.expect(t, len(live.allocation_map) == 0 && len(live.bad_free_array) == 0)
	}
	large := strings.repeat(" ", 1024 * 1024 + 1); defer delete(large)
	m, e := parse_manifest(
		transmute([]u8)large,
		a,
	); testing.expect(t, e.field == "input"); destroy_manifest(&m)
	m, e = parse_manifest(
		[]u8{255},
		a,
	); testing.expect(t, e.field == "input"); destroy_manifest(&m)
	pages := strings.repeat(`{"id":"p","file":"p.png"},`, 17); defer delete(pages)
	text := strings.concatenate(
		[]string{`{"version":1,"pages":[`, pages[:len(pages) - 1], `],"regions":[]}`},
	); defer delete(text)
	m, e = parse_manifest(
		transmute([]u8)text,
		a,
	); testing.expect(t, e.field == "pages_limit"); destroy_manifest(&m)
	testing.expect(t, len(live.allocation_map) == 0 && len(live.bad_free_array) == 0)
}

@(test)
manifest_strict_schema_owned_metadata_and_optionals :: proc(t: ^testing.T) {
	text := `{"version":1,"pages":[{"id":"p","file":"page.png"}],"regions":[{"id":"button","page":"p","rect":[1,2,10,12],"pivot":[0,1],"nine_slice":{"border":[1,2,3,4],"texture_scale":1,"edges":"repeat","center_x":"stretch","center_y":"repeat","omit_center":false,"padding":{"left":1,"top":2,"right":3,"bottom":4}}}]}`
	m, e := parse_manifest(transmute([]u8)text)
	testing.expect_value(t, e, Load_Error{})
	if !testing.expect(
		t,
		e.stage == "",
		"valid strict manifest must parse",
	) {return}; defer destroy_manifest(&m)
	testing.expect(t, len(m.pages) == 1 && len(m.regions) == 1)
	testing.expect_value(t, m.pages[0].file, "page.png")
	testing.expect_value(t, m.regions[0].rect, [4]int{1, 2, 10, 12})
	testing.expect(t, m.regions[0].image.source.w == 10 && m.regions[0].image.source.h == 12)
	nine, has := m.regions[0].image.nine_slice.?
	testing.expect(t, has && nine.edges == .Repeat && nine.center_y == .Repeat)
	pivot, pivot_has := m.regions[0].pivot.?
	testing.expect(t, pivot_has && pivot == ([2]f64{0, 1}))
}
