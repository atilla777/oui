package ui_hold

import base "../ui_base"
import "core:mem"
import "core:strings"

try_copy_frame :: proc(source: ^Frame, a: mem.Allocator) -> (Frame, bool) {
	f := Frame {
		allocator = a,
	}; complete := false; defer {if !complete {destroy_frame(&f)}}
	if !base.retain(source.stamp) {return {}, false}; f.stamp = source.stamp
	e: mem.Allocator_Error
	f.holds, e = make([]Description, len(source.holds), a); if e != nil {return {}, false}
	for h, k in source.holds {f.holds[k].threshold_ms = h.threshold_ms; f.holds[k].id, e = strings.clone(h.id, a); if e != nil {return {}, false}}
	f.progress, e = make([]Progress, len(source.progress), a); if e != nil {return {}, false}
	for p, k in source.progress {f.progress[k] = p; f.progress[k].id = ""; f.progress[k].id, e = strings.clone(p.id, a); if e != nil {return {}, false}}
	f.hold =
		source.hold; f.hold.id = ""; f.hold.id, e = strings.clone(source.hold.id, a); if e != nil {return {}, false}
	f.result = source.result; rebind_result(&f.result, f.hold.id)
	complete = true; return f, true
}
