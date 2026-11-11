package ui_gestures
import base "../ui_base"
import "core:mem"
import "core:strings"
try_copy_frame :: proc(f: ^Frame, a := context.allocator) -> (Frame, bool) {
	r := f^; r.allocator, r.gestures, r.live, r.scope_id, r.stamp = a, nil, {}, "", {}
	ok := false; defer {if !ok {destroy_frame(&r)}}
	if !base.retain(f.stamp) {return {}, false}; r.stamp = f.stamp
	e: mem.Allocator_Error
	r.scope_id, e = strings.clone(f.scope_id, a); if e != nil {return {}, false}
	r.gestures, e = make([]View, len(f.gestures), a); if e != nil {return {}, false}
	for v, j in f.gestures {
		d := &r.gestures[j]; d^ = v; d.description, d.parent, d.ancestors = {}, "", nil
		copied: bool; d.description, copied = copy_description(v.description, a); if !copied {return {}, false}
		d.parent, e = strings.clone(v.parent, a); if e != nil {return {}, false}
		d.ancestors, e = make([]string, len(v.ancestors), a); if e != nil {return {}, false}
		for id, k in v.ancestors {d.ancestors[k], e = strings.clone(id, a); if e != nil {return {}, false}}
	}
	copied: bool; r.live, copied = copy_live(f.live, a); if !copied {return {}, false}
	rebind(&r.result, r.live)
	ok = true; return r, true
}
