package ui_rich_debug

import ui ".."
import base "../../ui_base"
import debug "../../ui_debug"
import inspect "../inspect"
import "core:encoding/json"
import "core:mem"
import "core:slice"
import "core:strings"
import "core:unicode/utf8"

Rich_Wire_Node :: struct {
	node_id:                                                   string,
	family_revision:                                           u32,
	source_space, decoded_space, range_unit, range_convention: string,
	source, decoded, alt_text:                                 string,
	runs:                                                      []ui.Rich_Run,
	mappings:                                                  []ui.Rich_Mapping,
	tags:                                                      []ui.Text_Source_Range,
	lines:                                                     []ui.Rich_Line,
	natural_extent:                                            base.Extent,
	content_width:                                             f64,
	visible_line_count:                                        int,
	hidden, ellipsized, ellipsis_unavailable:                  bool,
	coverage:                                                  []ui.Rich_Coverage,
	font_chains:                                               []ui.Rich_Chain_View,
}
Request :: debug.Request
MESSAGE_LIMIT :: debug.MESSAGE_LIMIT
parse_request :: debug.parse_request
encode :: debug.encode
rich_node_projection :: proc(i: ^inspect.Inspection, id: string) -> []Rich_Wire_Node {
	nodes := make([dynamic]Rich_Wire_Node, context.temp_allocator)
	for b in i.rich_blocks {
		if id != "" && b.node_id != id {continue}
		append(
			&nodes,
			Rich_Wire_Node {
				b.node_id,
				1,
				"source markup",
				"decoded text",
				"UTF-8 bytes",
				"[start,end)",
				b.document.source,
				b.document.decoded,
				b.document.alt_text,
				b.document.runs[:],
				b.document.mappings[:],
				b.document.tags[:],
				b.lines[:],
				b.natural_extent,
				b.content_width,
				b.visible_line_count,
				b.hidden,
				b.ellipsized,
				b.ellipsis_unavailable,
				b.coverage,
				b.font_chains,
			},
		)
	}
	return nodes[:]
}
encode_rich_projection :: proc(base: []u8, nodes: []Rich_Wire_Node, a: mem.Allocator) -> []u8 {
	// Insert only into the serialized top-level result object. Do not round-trip
	// JSON numbers through json.Float: frame/state revisions are exact u64s.
	t := json.make_tokenizer(string(base), .JSON, true)
	depth, opening, closing := 0, -1, -1
	want, in_result := false, false
	for {
		v, e := json.get_token(&t); if e == .EOF {break}; if e != .None {return nil}
		#partial switch v.kind {
		case .String:
			if depth == 1 && v.text == `"result"` {want = true}
		case .Comma:
			if depth == 1 {want = false}
		case .Open_Brace:
			if depth == 1 && want {in_result = true; opening = v.offset}; depth += 1
		case .Open_Bracket:
			depth += 1
		case .Close_Brace:
			if depth == 2 && in_result {closing = v.offset; in_result = false}; depth -= 1
		case .Close_Bracket:
			depth -= 1
		case:
		}
	}
	if opening < 0 || closing < 0 {return nil}
	bytes := encode(nodes, context.temp_allocator); if bytes == nil {return nil}
	prefix := `"rich_nodes":`
	if len(strings.trim_space(string(base[opening + 1:closing]))) > 0 {prefix = `,"rich_nodes":`}
	result := make([]u8, len(base) + len(prefix) + len(bytes), a)
	p := copy(
		result,
		base[:closing],
	); p += copy(result[p:], transmute([]u8)prefix); p += copy(result[p:], bytes); copy(result[p:], base[closing:])
	return result
}

parse_rich_request :: proc(line: []u8) -> (Request, bool) {
	if len(line) >= MESSAGE_LIMIT || !utf8.valid_string(string(line)) {return {}, false}
	normalized := slice.clone(line, context.temp_allocator)
	t := json.make_tokenizer(string(line), .JSON, true)
	depth, versions := 0, 0
	key_expected, protocol_key, value_expected := false, false, false
	for {
		v, e := json.get_token(&t); if e == .EOF {break}; if e != .None {return {}, false}
		if depth == 1 && value_expected {
			if protocol_key {
				if v.kind != .Integer || v.text != "12" {return {}, false}
				versions += 1
				index := int(uintptr(raw_data(v.text)) - uintptr(raw_data(line)))
				if index < 0 ||
				   index + 1 >= len(normalized) {return {}, false}; normalized[index + 1] = '0'
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
				d, err := json.parse_string(
					v.text,
					.JSON,
					true,
					context.temp_allocator,
				); if err != nil {return {}, false}
				protocol_key = d.(string) == "protocol"; key_expected = false
			}
		case:
		}
	}
	if versions != 1 {return {}, false}
	r, ok := parse_request(normalized); if !ok {return {}, false}; r.protocol = 12; return r, true
}
