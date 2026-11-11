package ui_debug

import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:testing"

Observation_Fault :: struct {
	backing:       mem.Allocator,
	calls, refuse: int,
}

@(test)
checked_observation_partial_malformed_and_previous_conventions :: proc(t: ^testing.T) {
	live: mem.Tracking_Allocator
	mem.tracking_allocator_init(
		&live,
		context.allocator,
	); defer mem.tracking_allocator_destroy(&live)
	a := mem.tracking_allocator(&live)
	for source in ([]string{`["icon",`, `{"x":["a"],"y":`, `{"x":"a","x":"b"}`, `{"x":[{"y":"z"}]`, `{"x":"unterminated`, `["a"] false`}) {
		v, e := parse_checked_observation(source, a)
		testing.expect(t, e != .None && v == nil)
		json.destroy_value(v, a)
		testing.expect(t, len(live.allocation_map) == 0 && len(live.bad_free_array) == 0)
	}
	for source in ([]string{`null`, `[]`, `{}`, `{"x":[true,false,null,123,0.5,"a\\b\n\u00e9"]}`, `{id:"icon"}`, `['icon']`, `[1,2,]`, `/* previous JSON5 conventions */ {id:'icon',values:[1,2,],}`}) {
		v, e := parse_checked_observation(source, a)
		old, oe := json.parse_string(source, allocator = a)
		testing.expect(
			t,
			e == .None && oe == .None,
			fmt.tprintf("%s new=%v old=%v", source, e, oe),
		)
		encoded, ee := json.marshal(
			v,
			{sort_maps_by_key = true},
			a,
		); original, pe := json.marshal(old, {sort_maps_by_key = true}, a)
		testing.expect(t, ee == nil && pe == nil && string(encoded) == string(original))
		delete(encoded, a); delete(original, a)
		json.destroy_value(v, a); json.destroy_value(old, a)
		testing.expect(t, len(live.allocation_map) == 0 && len(live.bad_free_array) == 0)
	}
}
observation_fault :: proc(
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
	f := cast(^Observation_Fault)data
	if size > 0 &&
	   (mode == .Alloc ||
			   mode == .Alloc_Non_Zeroed ||
			   mode == .Resize ||
			   mode == .Resize_Non_Zeroed) {
		f.calls += 1
		if f.calls == f.refuse {return nil, .Out_Of_Memory}
	}
	return f.backing.procedure(f.backing.data, mode, size, alignment, old, old_size, loc)
}
@(test)
checked_observation_every_allocation_refusal_cannot_lose_array_elements :: proc(t: ^testing.T) {
	live: mem.Tracking_Allocator
	mem.tracking_allocator_init(
		&live,
		context.allocator,
	); defer mem.tracking_allocator_destroy(&live)
	f := Observation_Fault {
		backing = mem.tracking_allocator(&live),
	}
	a := mem.Allocator{observation_fault, &f}
	for source in ([]string{`["icon"]`, `{"pages":[{"id":"p","size":[2,2]}],"regions":[{"id":"icon","pivot":[0.5,1]}]}`}) {
		requests := 0
		for n := 0; n <= requests; n += 1 {
			f.calls, f.refuse = 0, n
			v, e := parse_checked_observation(source, a)
			if n ==
			   0 {testing.expect(t, e == .None); requests = f.calls} else {testing.expect(t, e != .None && v == nil, "allocation refusal must not become successful partial JSON")}
			json.destroy_value(v, a)
			testing.expect(
				t,
				len(live.allocation_map) == 0 && len(live.bad_free_array) == 0,
				"partial key/value ownership must be cleaned",
			)
			// Reclaim leaked blocks only in this RED regression; GREEN must have
			// none. This keeps a failed test independent of later fault indices.
			for ptr in live.allocation_map {mem.free(ptr, context.allocator)}
			mem.tracking_allocator_clear(&live)
		}
	}
}
