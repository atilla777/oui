package ui_controls

import base "../ui_base"
import "core:mem"
import "core:slice"
import "core:strings"

try_copy_frame :: proc(source: ^Frame, a: mem.Allocator) -> (Frame, bool) {
	f := Frame {
		allocator = a,
	}; complete := false; defer {if !complete {destroy_frame(&f)}}
	if !base.retain(source.stamp) {return {}, false}; f.stamp = source.stamp
	e: mem.Allocator_Error
	f.controls, e = make([]Description, len(source.controls), a); if e != nil {return {}, false}
	for c, k in source.controls {f.controls[k], e = clone_description(c, a); if e != nil {return {}, false}}
	f.scope_id, e = strings.clone(source.scope_id, a); if e != nil {return {}, false}
	f.gates, e = slice.clone(source.gates, a); if e != nil {return {}, false}
	complete = true; return f, true
}
validate_candidate :: proc(p: ^base.Publication, c: ^Candidate) -> bool {return(
		base.validate(p, c.stamp) == .None &&
		len(c.controls) == len(c.gates) &&
		c.allocator.procedure != nil \
	)}
describe_error :: proc(e: Error, stage: base.Stage = .Prepare) -> base.Error {id := e.node_id
	if id == "" {id = e.control_id}
	return {family = .Controls, stage = stage, code = u32(e.code), id = id}}
