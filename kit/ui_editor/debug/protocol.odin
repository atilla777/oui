package ui_editor_debug

import ui ".."
import debug "../../ui_debug"
import "core:encoding/json"
import "core:slice"
import "core:strconv"
import "core:unicode/utf8"

Request :: debug.Request
MESSAGE_LIMIT :: debug.MESSAGE_LIMIT
parse_request :: debug.parse_request
parse_editor_request :: proc(line: []u8) -> (Request, bool) {
	if len(line) >= MESSAGE_LIMIT || !utf8.valid_string(string(line)) {return {}, false}
	for b in line {if b == 0 {return {}, false}}
	// Reuse the unchanged v10 schema for its ordinary operations, replacing only
	// the lexed top-level version integer in a private copy, never string content.
	normalized := slice.clone(line, context.temp_allocator)
	t := json.make_tokenizer(string(line), .JSON, true)
	depth := 0; key_expected := false; protocol_key := false; value_expected := false; versions := 0
	for {
		v, err := json.get_token(&t)
		if err == .EOF {break}; if err != .None {return {}, false}
		if depth == 1 && value_expected {
			if protocol_key {
				if v.kind != .Integer || v.text != "11" {return {}, false}
				versions += 1
				index := int(uintptr(raw_data(v.text)) - uintptr(raw_data(line)))
				if index < 0 || index + 1 >= len(normalized) {return {}, false}
				normalized[index + 1] = '0'
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
				decoded, e := json.parse_string(v.text, .JSON, true, context.temp_allocator)
				if e != nil {return {}, false}
				protocol_key = decoded.(string) == "protocol"; key_expected = false
			}
		case:
		}
	}
	if versions != 1 {return {}, false}
	if legacy, ok := parse_request(normalized); ok {legacy.protocol = 11; return legacy, true}
	t = json.make_tokenizer(string(line), .JSON, true)
	open, oe := json.get_token(&t); if oe != .None || open.kind != .Open_Brace {return {}, false}
	r := Request {
		protocol = 11,
	}
	a := ui.Action {
		source = .Agent,
	}
	seen: [9]bool
	for {
		key, ke := json.get_token(&t); if ke != .None || key.kind != .String {return {}, false}
		decoded, de := json.parse_string(
			key.text,
			.JSON,
			true,
			context.temp_allocator,
		); if de != nil {return {}, false}
		index := -1
		switch decoded.(string) {
		case "protocol":
			index = 0
		case "request_id":
			index = 1
		case "op":
			index = 2
		case "id":
			index = 3
		case "text":
			index = 4
		case "anchor":
			index = 5
		case "caret":
			index = 6
		case "direction":
			index = 7
		case "extend":
			index = 8
		}
		if index < 0 || seen[index] {return {}, false}; seen[index] = true
		colon, ce := json.get_token(&t); if ce != .None || colon.kind != .Colon {return {}, false}
		v, ve := json.get_token(&t); if ve != .None {return {}, false}
		if index == 0 {if v.kind != .Integer || v.text != "11" {return {}, false}
		} else if index == 5 || index == 6 {
			if v.kind != .Integer {return {}, false}
			n, ok := strconv.parse_i64(
				v.text,
			); if !ok || n < 0 || u64(n) > u64(max(int)) {return {}, false}
			if index == 5 {a.anchor = int(n)} else {a.caret = int(n)}
		} else if index == 8 {
			if v.kind != .True && v.kind != .False {return {}, false}; a.extend = v.kind == .True
		} else {
			if v.kind != .String {return {}, false}
			d, e := json.parse_string(
				v.text,
				.JSON,
				true,
				context.temp_allocator,
			); if e != nil {return {}, false}
			s := d.(string); if s == "" && index != 4 {return {}, false}
			switch index {case 1:
				r.request_id = s; case 2:
				r.op = s; case 3:
				r.id = s; a.id = s; case 4:
				a.text = s; case 7:
				r.direction = s}
		}
		sep, se := json.get_token(&t); if se != .None {return {}, false}
		if sep.kind == .Close_Brace {break}; if sep.kind != .Comma {return {}, false}
	}
	end, ee := json.get_token(&t); if ee != .EOF || end.kind != .EOF {return {}, false}
	allowed: [9]bool
	allowed[0], allowed[1], allowed[2], allowed[3] = true, true, true, true
	for i in 0 ..< 4 {if !seen[i] {return {}, false}}
	switch r.op {
	case "text_insert":
		a.kind = .Insert; allowed[4] = true; if !seen[4] {return {}, false}
	case "text_select":
		a.kind = .Select; allowed[5], allowed[6] = true, true
		if !seen[5] || !seen[6] {return {}, false}
	case "text_move":
		a.kind = .Move; allowed[7], allowed[8] = true, true
		if !seen[7] || !seen[8] {return {}, false}
		switch r.direction {case "left":
			a.direction = .Left; case "right":
			a.direction = .Right; case "home":
			a.direction = .Home; case "end":
			a.direction = .End; case:
			return {}, false}
	case "text_delete":
		allowed[7] = true; if !seen[7] {return {}, false}
		if r.direction ==
		   "backward" {a.kind = .Backspace} else if r.direction == "forward" {a.kind = .Delete} else {return {}, false}
	case "text_submit":
		a.kind = .Submit
	case "text_cancel":
		a.kind = .Cancel
	case:
		return {}, false
	}
	for present, i in seen {if present && !allowed[i] {return {}, false}}
	payload, allocation := new(
		ui.Action,
		context.temp_allocator,
	); if allocation != nil {return {}, false}; payload^ = a
	r.extension, r.extended_action = any{payload, typeid_of(ui.Action)}, true
	return r, true
}
