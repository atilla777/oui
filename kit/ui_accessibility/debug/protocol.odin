package ui_accessibility_debug

import debug "../../ui_debug"
import transitions "../../ui_transitions"
import td "../../ui_transitions/debug"
import inspect "../inspect"
import "core:mem"

Accessibility_Capture :: struct {
	nodes:                []debug.Wire_Node,
	frame:                debug.Frame_Metadata,
	transitions:          td.Transition_Projection,
	owner:                rawptr,
	release:              proc(owner: rawptr, a: mem.Allocator),
	assessment:           inspect.Accessibility_Inspection,
	observation:          []u8,
	strict_accessibility: bool,
	error:                string,
}
destroy_accessibility_capture :: proc(
	c: ^Accessibility_Capture,
	a: mem.Allocator,
) {debug.destroy_projection(c.nodes, &c.frame, nil, a); if c.release != nil {c.release(c.owner, a)}
	inspect.destroy_accessibility_inspection(&c.assessment)
	delete(c.observation, a)
	c^ = {}}
Request :: debug.Request
Host :: struct {
	user:                          rawptr,
	allowed, transition_test_time: bool,
	capabilities:                  debug.Capabilities,
	capture_accessibility:         proc(user: rawptr, a: mem.Allocator) -> Accessibility_Capture,
	execute:                       proc(
		user: rawptr,
		action: debug.Debug_Action,
	) -> debug.Action_Reply,
	execute_transition:            proc(
		user: rawptr,
		step: transitions.Step,
	) -> debug.Action_Reply,
	snapshot:                      proc(
		user: rawptr,
		options: debug.Snapshot_Options,
		a: mem.Allocator,
	) -> debug.Snapshot_Reply,
}
parse_request_version :: debug.parse_request_version
transport :: proc(h: ^Host) -> debug.Host {return {
		user = h,
		allowed = h.allowed,
		protocol = 17,
		parse = parse_accessibility_request,
		serve = proc(
			user: rawptr,
			line: []u8,
			a: mem.Allocator,
		) -> []u8 {return handle_accessibility(cast(^Host)user, line, a)},
	}}
parse_accessibility_request :: proc(line: []u8) -> (Request, bool) {return parse_request_version(
		line,
		17,
	)}
