package app

import "base:runtime"
import "core:mem"
import "core:testing"
import sdl "vendor:sdl3"

// Freed storage is zeroed and quarantined until the fixture ends, so borrowed
// IDs cannot accidentally appear valid merely because malloc retained bytes.
Focus_Allocator :: struct {
	backing: mem.Allocator,
	sizes:   map[rawptr]int,
	freed:   [dynamic]rawptr,
}
focus_allocator :: proc(
	data: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old: rawptr,
	old_size: int,
	loc: runtime.Source_Code_Location,
) -> (
	[]u8,
	mem.Allocator_Error,
) {
	q := cast(^Focus_Allocator)data
	if mode == .Free && old != nil {
		if n, found := q.sizes[old];
		   found {mem.zero(old, n); delete_key(&q.sizes, old); append(&q.freed, old); return nil, nil}
	}
	result, e := q.backing.procedure(q.backing.data, mode, size, alignment, old, old_size, loc)
	if e == nil &&
	   len(result) > 0 &&
	   (mode == .Alloc ||
			   mode == .Alloc_Non_Zeroed ||
			   mode == .Resize ||
			   mode == .Resize_Non_Zeroed) {
		if old != nil {delete_key(&q.sizes, old)}
		q.sizes[raw_data(result)] = len(result)
	}
	return result, e
}
@(test)
c03_focus_id_is_rebound_before_old_interaction_storage_is_destroyed :: proc(t: ^testing.T) {
	backing := context.allocator
	q := Focus_Allocator {
		backing = backing,
		sizes   = make(map[rawptr]int, backing),
		freed   = make([dynamic]rawptr, backing),
	}
	defer {for p in q.freed {free(p, backing)}; delete(q.sizes); delete(q.freed)}
	context.allocator = {focus_allocator, &q}; defer {context.allocator = backing}
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Diagnostics_Performance) {return}
	testing.expect(t, dispatch(&f.s, {.Focus, "name/apply", .Agent, false}))
	testing.expect(
		t,
		f.s.runtime.interaction.focus_id == "name/apply",
		"combined publisher cannot retain an old frame's freed focus ID",
	)
	page_key(&f.s, sdl.K_TAB)
	testing.expect(t, f.s.runtime.interaction.focus_id == "name/cancel")
}
