package ui_transitions

import "core:mem"
import "core:slice"
import "core:strings"
try_copy_frame :: proc(source: ^Frame, a := context.allocator) -> (Frame, bool) {
	if !source.bound {return {}, false}
	f, e := new_frame(source.stamp, a); if e != .None {return {}, false}
	complete := false; defer {if !complete {destroy_frame(&f)}}
	ca := mem.rollback_stack_allocator(f.storage)
	ae: mem.Allocator_Error
	f.bindings, ae = make([]string, len(source.bindings), ca); if ae != nil {return {}, false}
	for id, index in source.bindings {f.bindings[index], ae = strings.clone(id, ca); if ae != nil {return {}, false}}
	f.tracks, ae = slice.clone(source.tracks, ca); if ae != nil {return {}, false}
	for &tr in f.tracks {tr.node_id, ae = strings.clone(tr.node_id, ca); if ae != nil {return {}, false}}
	f.presences, ae = slice.clone(source.presences, ca); if ae != nil {return {}, false}
	for &presence in f.presences {presence.node_id, ae = strings.clone(presence.node_id, ca); if ae != nil {return {}, false}}
	f.entries, ae = slice.clone(source.entries, ca); if ae != nil {return {}, false}
	for &entry in f.entries {entry.id, ae = strings.clone(entry.id, ca); if ae != nil {return {}, false}}
	f.bound, f.reduced_motion, f.drawable, f.ui_scale =
		source.bound, source.reduced_motion, source.drawable, source.ui_scale
	complete = true
	return f, true
}
