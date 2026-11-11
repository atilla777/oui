package ui_custom_debug

import debug "../../ui_debug"
import inspect "../inspect"
import "core:encoding/json"
import "core:mem"
import "core:slice"

Custom_Wire_Node :: struct {
	node_id:  string,
	metadata: inspect.Metadata,
}
Request :: debug.Request
MESSAGE_LIMIT :: debug.MESSAGE_LIMIT
parse_request :: debug.parse_request
encode_gesture_projection :: proc(
	base: []u8,
	p: any,
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
Custom_Projection :: struct {
	custom_nodes: []Custom_Wire_Node,
}
custom_projection :: proc(i: ^inspect.Inspection) -> Custom_Projection {
	ns := make([dynamic]Custom_Wire_Node, context.temp_allocator)
	for d in i.views {
		append(
			&ns,
			Custom_Wire_Node {
				d.node_id,
				{d.type_id, d.revision, d.semantic_name, d.hit_description},
			},
		)
	}
	return {ns[:]}
}
// Normalize only the single top-level version token, then let the established
// strict parser enforce keys, operation shapes, duplicates and semantic actions.
parse_custom_request :: proc(line: []u8) -> (Request, bool) {
	normalized := slice.clone(line, context.temp_allocator)
	t := json.make_tokenizer(string(line), .JSON, true)
	depth, versions := 0, 0
	key_expected, protocol_key, value_expected := false, false, false
	for {
		v, e := json.get_token(&t); if e == .EOF {break}; if e != .None {return {}, false}
		if depth == 1 && value_expected {
			if protocol_key {
				if v.kind != .Integer || v.text != "15" {return {}, false}
				versions += 1
				at := int(uintptr(raw_data(v.text)) - uintptr(raw_data(line)))
				if at < 0 || at + 1 >= len(normalized) {return {}, false}
				normalized[at + 1] = '0'
			}
			value_expected = false
		}
		#partial switch v.kind {
		case .Open_Brace, .Open_Bracket:
			depth += 1; if depth == 1 {key_expected = true}
		case .Close_Brace, .Close_Bracket:
			depth -= 1
		case .Comma:
			if depth == 1 {key_expected = true}
		case .Colon:
			if depth == 1 {value_expected = true}
		case .String:
			if depth == 1 && key_expected {
				d, err := json.parse_string(v.text, .JSON, true, context.temp_allocator)
				if err != nil {return {}, false}
				protocol_key = d.(string) == "protocol"; key_expected = false
			}
		case:
		}
	}
	if versions != 1 {return {}, false}
	r, ok := parse_request(normalized); r.protocol = 15; return r, ok
}
encode_custom_projection :: proc(
	base: []u8,
	i: ^inspect.Inspection,
	observation: []u8,
	a: mem.Allocator,
) -> []u8 {
	return encode_gesture_projection(base, custom_projection(i), observation, a)
}
