package ui_scroll

import base "../ui_base"
import "core:mem"
import "core:strings"

try_copy_frame :: proc(source: ^Frame, a: mem.Allocator) -> (Frame, bool) {
	f := Frame {
		allocator = a,
	}; complete := false; defer {if !complete {destroy_frame(&f)}}
	if !base.retain(source.stamp) {return {}, false}; f.stamp = source.stamp
	e: mem.Allocator_Error
	f.regions, e = make([]Region, len(source.regions), a); if e != nil {return {}, false}
	for r, k in source.regions {
		d := &f.regions[k]; d^ = r; d.id, d.anchor_id, d.items = "", "", nil
		d.id, e = strings.clone(r.id, a); if e != nil {return {}, false}
		d.anchor_id, e = strings.clone(r.anchor_id, a); if e != nil {return {}, false}
		d.items, e = make([]Item, len(r.items), a); if e != nil {return {}, false}
		for item, j in r.items {d.items[j] = item; d.items[j].id = ""; d.items[j].id, e = strings.clone(item.id, a); if e != nil {return {}, false}}
	}
	complete = true; return f, true
}
describe_error :: proc(e: Error, stage: base.Stage = .Prepare) -> base.Error {return {
		family = .Scroll,
		stage = stage,
		code = u32(e.code),
		id = e.id,
	}}
