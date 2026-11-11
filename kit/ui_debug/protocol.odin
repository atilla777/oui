package ui_debug

import "core:encoding/json"
import "core:math"
import "core:strconv"
import "core:unicode/utf8"

MESSAGE_LIMIT :: 1024 * 1024
Request :: struct {
	extension:                                 any,
	extended_action:                           bool,
	protocol:                                  int,
	request_id, op, id, role, name, direction: string,
	duration_ms:                               i64,
	delta_y:                                   f64,
	overlays:                                  [3]bool,
}
parse_request :: proc(line: []u8) -> (Request, bool) {
	return parse_request_version(line, 10)
}
parse_request_version :: proc(line: []u8, protocol: int) -> (Request, bool) {
	if len(line) >= MESSAGE_LIMIT || !utf8.valid_string(string(line)) {return {}, false}
	for b in line {if b == 0 {return {}, false}}
	t := json.make_tokenizer(string(line), .JSON, true)
	open, error := json.get_token(&t)
	if error != .None || open.kind != .Open_Brace {return {}, false}
	r: Request
	seen: [10]bool
	for {
		key, ke := json.get_token(&t)
		if ke != .None || key.kind != .String {return {}, false}
		decoded, de := json.parse_string(key.text, .JSON, true, context.temp_allocator)
		if de != nil {return {}, false}
		name, valid := decoded.(string); if !valid {return {}, false}
		index := -1
		switch name {
		case "protocol":
			index = 0
		case "request_id":
			index = 1
		case "op":
			index = 2
		case "id":
			index = 3
		case "duration_ms":
			index = 4
		case "delta_y":
			index = 5
		case "role":
			index = 6
		case "name":
			index = 7
		case "direction":
			index = 8
		case "overlays":
			index = 9
		}
		if index < 0 || seen[index] {return {}, false}; seen[index] = true
		colon, ce := json.get_token(&t); if ce != .None || colon.kind != .Colon {return {}, false}
		v, ve := json.get_token(&t); if ve != .None {return {}, false}
		if index == 0 {
			if v.kind != .Integer ||
			   (v.text != "10" && protocol == 10) ||
			   (v.text != "16" && protocol == 16) ||
			   (v.text != "17" && protocol == 17) {return {}, false}; r.protocol = protocol
		} else if index == 4 {
			if v.kind != .Integer {return {}, false}
			n, ok := strconv.parse_i64(
				v.text,
			); if !ok || n < 0 {return {}, false}; r.duration_ms = n
		} else if index == 5 {
			if v.kind != .Integer && v.kind != .Float {return {}, false}
			n, ok := strconv.parse_f64(v.text)
			if !ok || math.is_nan(n) || math.is_inf(n) {return {}, false}; r.delta_y = n
		} else if index == 9 {
			if v.kind != .Open_Bracket {return {}, false}
			item, ie := json.get_token(&t); if ie != .None {return {}, false}
			if item.kind != .Close_Bracket {
				for {
					if item.kind != .String {return {}, false}
					value, e := json.parse_string(item.text, .JSON, true, context.temp_allocator)
					if e != nil {return {}, false}
					s, ok := value.(string); if !ok {return {}, false}
					n := -1
					switch s {case "bounds":
						n = 0; case "content":
						n = 1; case "hit":
						n = 2}
					if n < 0 || r.overlays[n] {return {}, false}; r.overlays[n] = true
					sep, sep_error := json.get_token(&t); if sep_error != .None {return {}, false}
					if sep.kind == .Close_Bracket {break}
					if sep.kind != .Comma {return {}, false}
					item, ie = json.get_token(&t); if ie != .None {return {}, false}
				}
			}
		} else {
			if v.kind != .String {return {}, false}
			value, e := json.parse_string(v.text, .JSON, true, context.temp_allocator)
			if e != nil {return {}, false}
			s, ok := value.(string); if !ok || s == "" {return {}, false}
			switch index {
			case 1:
				r.request_id = s
			case 2:
				r.op = s
			case 3:
				r.id = s
			case 6:
				r.role = s
			case 7:
				r.name = s
			case 8:
				r.direction = s
			}
		}
		separator, se := json.get_token(&t); if se != .None {return {}, false}
		if separator.kind == .Close_Brace {break}
		if separator.kind != .Comma {return {}, false}
	}
	end, ee := json.get_token(&t)
	if ee != .EOF || end.kind != .EOF || !seen[0] || !seen[1] || !seen[2] {return {}, false}
	allowed: [10]bool
	allowed[0], allowed[1], allowed[2] = true, true, true
	switch r.op {
	case "find":
		count := 0; for n in ([]int{3, 6, 7}) {if seen[n] {count += 1; allowed[n] = true}}
		if count != 1 {return {}, false}
	case "inspect", "focus", "activate", "begin":
		allowed[3] = true; if !seen[3] {return {}, false}
	case "scroll":
		allowed[3], allowed[5] = true, true; if !seen[3] || !seen[5] {return {}, false}
	case "advance":
		allowed[4] = true; if !seen[4] {return {}, false}
	case "navigate":
		allowed[8] = true
		if r.direction != "forward" && r.direction != "backward" {return {}, false}
	case "snapshot":
		allowed[9] = true
	case "finish-transitions":
		if protocol != 16 && protocol != 17 {return {}, false}
	case "capabilities",
	     "tree",
	     "diagnostics",
	     "assert_no_errors",
	     "cancel",
	     "release",
	     "hold_cancel",
	     "set_value",
	     "drag":
	case:
		return {}, false
	}
	for present, n in seen {if present && !allowed[n] {return {}, false}}
	return r, true
}
