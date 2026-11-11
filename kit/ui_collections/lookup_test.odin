package ui_collections

import "base:runtime"
import "core:mem"
import "core:testing"

Lookup_Probe :: struct {
	allocations: int,
}
lookup_allocator :: proc(
	data: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old: rawptr,
	old_size: int,
	loc: runtime.Source_Code_Location = #caller_location,
) -> (
	[]u8,
	mem.Allocator_Error,
) {
	p := cast(^Lookup_Probe)data
	if mode == .Alloc ||
	   mode == .Alloc_Non_Zeroed ||
	   mode == .Resize ||
	   mode == .Resize_Non_Zeroed {p.allocations += 1; return nil, .Out_Of_Memory}
	return nil, nil
}
@(test)
logical_lookup_is_borrowed_and_never_allocates :: proc(t: ^testing.T) {
	f, e := prepare_collection(
		fixture_description([]Collection_Item{{"a", "A", true, true, ""}}),
		{w = 100, h = 10},
		0,
	)
	if !testing.expect(t, e.code == .None) {return}
	original := f.allocator
	defer {f.allocator = original; destroy_frame(&f)}
	probe: Lookup_Probe; f.allocator = {lookup_allocator, &probe}
	v, code := lookup_collection_item(&f, "list", "a")
	testing.expect(
		t,
		code == .Applied && v.materialized && v.in_viewport && probe.allocations == 0,
	)
}
