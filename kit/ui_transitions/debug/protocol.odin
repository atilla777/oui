package ui_transitions_debug

import debug "../../ui_debug"
import inspect "../inspect"
import "core:mem"

Request :: debug.Request
parse_transition_request :: proc(line: []u8) -> (Request, bool) {
	r, ok := debug.parse_request_version(line, 16)
	if r.op == "advance" || r.op == "finish-transitions" {r.extended_action = true}
	return r, ok
}

Transition_Projection :: struct {
	transition:           inspect.Transition_Inspection,
	visual_nodes:         []inspect.Visual_View,
	transition_test_time: bool,
}
transition_projection :: proc(
	i: ^inspect.Inspection,
	version: u64,
	test_time: bool,
) -> Transition_Projection {
	nodes := make([]inspect.Visual_View, len(i.entries), context.temp_allocator)
	for n, k in i.entries {nodes[k], _ = inspect.inspect_visual(i, n.id)}
	return {inspect.inspect_transitions(i, version), nodes, test_time}
}
encode_transition_projection :: proc(
	base: []u8,
	p: Transition_Projection,
	observation: []u8,
	a: mem.Allocator,
) -> []u8 {
	data := debug.encode_result_projection(
		base,
		p,
		a,
	); if data == nil {return nil}; defer delete(data, a)
	return debug.encode_observation(data, observation, a)
}
