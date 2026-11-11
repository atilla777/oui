package ui_collections_debug

import ui ".."
import debug "../../ui_debug"
import inspect "../inspect"
import "core:encoding/json"
import "core:mem"
import "core:slice"
import "core:unicode/utf8"

Collection_Projection :: struct {
	logical_items:                    []inspect.Logical_Item_View,
	logical_item:                     Maybe(inspect.Logical_Item_View),
	collections:                      []inspect.Collection_View,
	logical_exact_id, scroll_to_item: bool,
}
Request :: debug.Request
MESSAGE_LIMIT :: debug.MESSAGE_LIMIT
parse_request :: debug.parse_request
encode :: debug.encode

decode_collection_id :: proc(id: string) -> (string, string, bool) {
	cursor := 0
	c, ok := ui.decode_part(id, &cursor)
	item, valid := ui.decode_part(id, &cursor)
	if !ok || !valid || c == "" || item == "" || cursor != len(id) {return "", "", false}
	canonical := ui.item_node_id(c, item, context.temp_allocator)
	return c, item, canonical == id
}

parse_collections_request :: proc(line: []u8) -> (Request, bool) {
	if len(line) >= MESSAGE_LIMIT || !utf8.valid_string(string(line)) {return {}, false}
	normalized := slice.clone(line, context.temp_allocator)
	t := json.make_tokenizer(string(line), .JSON, true)
	depth, versions := 0, 0
	key_expected, value_expected := false, false
	key := ""
	scroll := false
	for {
		v, e := json.get_token(&t); if e == .EOF {break}; if e != .None {return {}, false}
		if depth == 1 && value_expected {
			if key == "protocol" {
				if v.kind != .Integer || v.text != "13" {return {}, false}
				versions += 1; normalized[v.offset + 1] = '0'
			}
			if key == "op" && v.kind == .String {
				d, err := json.parse_string(v.text, .JSON, true, context.temp_allocator)
				if err != nil {return {}, false}
				if d.(string) == "scroll_to_item" {
					scroll = true
					for j := 0; j < len(v.text); j += 1 {normalized[v.offset + j] = ' '}
					copy(normalized[v.offset:], transmute([]u8)string(`"inspect"`))
				}
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
				if err != nil {return {}, false}; key = d.(string); key_expected = false
			}
		case:
		}
	}
	if versions != 1 {return {}, false}
	r, ok := parse_request(normalized); if !ok {return {}, false}
	r.protocol = 13
	if scroll {
		if _, _, valid := decode_collection_id(r.id); !valid {return {}, false}
		r.op = "scroll_to_item"
		r.extended_action = true
	}
	return r, true
}

// Add only explicitly selected v13 fields, preserving all legacy serializers.
encode_collection_projection :: proc(
	base: []u8,
	p: Collection_Projection,
	a: mem.Allocator,
) -> []u8 {
	return encode_result_projection(base, p, a)
}
@(private)
encode_result_projection :: proc(base: []u8, p: any, a: mem.Allocator) -> []u8 {
	t := json.make_tokenizer(string(base), .JSON, true)
	depth, closing := 0, -1
	want, in_result := false, false
	for {
		v, e := json.get_token(&t); if e == .EOF {break}; if e != .None {return nil}
		#partial switch v.kind {
		case .String:
			if depth == 1 && v.text == `"result"` {want = true}
		case .Comma:
			if depth == 1 {want = false}
		case .Open_Brace:
			if depth == 1 && want {in_result = true}; depth += 1
		case .Open_Bracket:
			depth += 1
		case .Close_Brace:
			if depth == 2 && in_result {closing = v.offset; in_result = false}; depth -= 1
		case .Close_Bracket:
			depth -= 1
		case:
		}
	}
	if closing < 0 {return nil}
	bytes := encode(p, context.temp_allocator)
	if len(bytes) < 2 {return nil}
	fields := bytes[1:len(bytes) - 1]
	result := make([]u8, len(base) + len(fields) + 1, a)
	n := copy(result, base[:closing]); result[n] = ','; n += 1
	n += copy(result[n:], fields); copy(result[n:], base[closing:])
	return result
}
