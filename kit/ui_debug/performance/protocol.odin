package ui_performance_debug

import debug ".."
import collections "../../ui_collections/debug"
import editor "../../ui_editor/debug"
import "core:encoding/json"
import "core:slice"

Request :: debug.Request
MESSAGE_LIMIT :: debug.MESSAGE_LIMIT
parse_editor_request :: editor.parse_editor_request
parse_collections_request :: collections.parse_collections_request

// Rewrite exactly one lexed top-level version token in private scratch. Both
// unchanged strict parsers still own their operation fields and validation.
parse_performance_request :: proc(line: []u8) -> (Request, bool) {
	if len(line) >= MESSAGE_LIMIT {return {}, false}
	n := slice.clone(line, context.temp_allocator)
	t := json.make_tokenizer(string(line), .JSON, true)
	depth, count, at := 0, 0, -1
	key, want := "", false
	for {
		v, e := json.get_token(&t); if e == .EOF {break}; if e != .None {return {}, false}
		if depth == 1 && want {
			if key == "protocol" {
				if v.kind != .Integer || v.text != "18" {return {}, false}
				at = v.offset; count += 1
			}
			want = false
		}
		#partial switch v.kind {
		case .Open_Brace, .Open_Bracket:
			depth += 1
		case .Close_Brace, .Close_Bracket:
			depth -= 1
		case .Colon:
			if depth == 1 {want = true}
		case .String:
			if depth == 1 {
				d, err := json.parse_string(v.text, .JSON, true, context.temp_allocator)
				if err != nil {return {}, false}; key = d.(string)
			}
		case:
		}
	}
	if count != 1 || at < 0 || at + 1 >= len(n) {return {}, false}
	n[at + 1] = '1'
	r, ok := parse_editor_request(n)
	if !ok {n[at + 1] = '3'; r, ok = parse_collections_request(n)}
	r.protocol = 18
	return r, ok
}
