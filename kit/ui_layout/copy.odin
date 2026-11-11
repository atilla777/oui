package ui_layout

import base "../ui_base"
import "core:mem"
import "core:slice"

try_copy_frame :: proc(source: ^Frame, allocator: mem.Allocator) -> (Frame, bool) {
	r := source^
	r.nodes, r.diagnostics, r.stamp = nil, nil, {}
	r.allocator = allocator
	complete := false; defer {if !complete {destroy_frame(&r)}}
	if !base.retain(source.stamp) {return {}, false}
	r.stamp = source.stamp
	e: mem.Allocator_Error
	r.nodes, e = make(
		[]Resolved_Node,
		len(source.nodes),
		allocator,
	); if e != nil {return {}, false}
	for n, i in source.nodes {
		r.nodes[i] = n; r.nodes[i].description = {}; r.nodes[i].rows, r.nodes[i].columns = nil, nil
		d, de := try_clone_description(n.description, allocator); if de != nil {return {}, false}
		r.nodes[i].description = d
		r.nodes[i].rows, e = slice.clone(n.rows, allocator); if e != nil {return {}, false}
		r.nodes[i].columns, e = slice.clone(n.columns, allocator); if e != nil {return {}, false}
	}
	r.diagnostics, e = make(
		[dynamic]Diagnostic,
		len(source.diagnostics),
		len(source.diagnostics),
		allocator,
	); if e != nil {return {}, false}
	for d, i in source.diagnostics {
		r.diagnostics[i] = d
		if n, ok := find(&r, d.id); ok {r.diagnostics[i].id = n.description.id}
	}
	complete = true
	return r, true
}
