package ui_interaction

import base "../ui_base"
import "core:mem"
import "core:strings"

try_copy_frame :: proc(source: ^Frame, allocator: mem.Allocator) -> (Frame, bool) {
	r := Frame {
		drawable  = source.drawable,
		allocator = allocator,
		ui_scale  = source.ui_scale,
	}
	complete := false; defer {if !complete {destroy_frame(&r)}}
	if !base.retain(source.stamp) {return {}, false}
	r.stamp = source.stamp
	e: mem.Allocator_Error
	r.targets, e = make(
		[]Target_View,
		len(source.targets),
		allocator,
	); if e != nil {return {}, false}
	for n, i in source.targets {
		r.targets[i] =
			n; r.targets[i].description.id, r.targets[i].description.role, r.targets[i].parent = "", "", ""
		r.targets[i].activation_owner = ""
		r.targets[i].activation_owner, e = strings.clone(
			n.activation_owner,
			allocator,
		); if e != nil {return {}, false}
		r.targets[i].description.id, e = strings.clone(
			n.description.id,
			allocator,
		); if e != nil {return {}, false}
		r.targets[i].description.role, e = strings.clone(
			n.description.role,
			allocator,
		); if e != nil {return {}, false}
		r.targets[i].parent, e = strings.clone(n.parent, allocator); if e != nil {return {}, false}
	}
	complete = true
	return r, true
}
