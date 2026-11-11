package showcase_profile

import "core:encoding/json"
import "core:math"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"

MESSAGE_LIMIT :: 1024 * 1024
Request :: struct {
	protocol:                                           int,
	request_id, op, id, role, name, direction, section: string,
	duration_ms:                                        i64,
	delta_y:                                            f64,
}
// Strings are scratch-owned, valid only during the synchronous handler call.
// No legacy parser/DTO participates in this selected profile.
parse_request :: proc(line: []u8) -> (Request, bool) {
	if len(line) >= MESSAGE_LIMIT || !utf8.valid_string(string(line)) {return {}, false}
	for b in line {if b == 0 {return {}, false}}
	t := json.make_tokenizer(string(line), .JSON, true)
	open, error := json.get_token(&t)
	if error != .None || open.kind != .Open_Brace {return {}, false}
	r: Request; seen: [10]bool
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
		case "role":
			index = 4
		case "name":
			index = 5
		case "direction":
			index = 6
		case "section":
			index = 7
		case "duration_ms":
			index = 8
		case "delta_y":
			index = 9
		}
		if index < 0 || seen[index] {return {}, false}; seen[index] = true
		colon, ce := json.get_token(&t); if ce != .None || colon.kind != .Colon {return {}, false}
		v, ve := json.get_token(&t); if ve != .None {return {}, false}
		if index == 0 {
			if v.kind != .Integer || v.text != "19" {return {}, false}; r.protocol = 19
		} else if index == 8 {
			if v.kind != .Integer {return {}, false}
			n, ok := strconv.parse_i64(
				v.text,
			); if !ok || n < 0 {return {}, false}; r.duration_ms = n
		} else if index == 9 {
			if v.kind != .Integer && v.kind != .Float {return {}, false}
			n, ok := strconv.parse_f64(v.text)
			if !ok || math.is_nan(n) || math.is_inf(n) {return {}, false}; r.delta_y = n
		} else {
			if v.kind != .String {return {}, false}
			value, e := json.parse_string(v.text, .JSON, true, context.temp_allocator)
			if e != nil {return {}, false}
			s, ok := value.(string)
			if !ok ||
			   s == "" ||
			   !utf8.valid_string(s) ||
			   strings.contains_rune(s, 0) {return {}, false}
			switch index {
			case 1:
				r.request_id = s
			case 2:
				r.op = s
			case 3:
				r.id = s
			case 4:
				r.role = s
			case 5:
				r.name = s
			case 6:
				r.direction = s
			case 7:
				r.section = s
			}
		}
		separator, se := json.get_token(&t); if se != .None {return {}, false}
		if separator.kind == .Close_Brace {break}
		if separator.kind != .Comma {return {}, false}
	}
	end, ee := json.get_token(&t)
	if ee != .EOF || end.kind != .EOF || !seen[0] || !seen[1] || !seen[2] {return {}, false}
	allowed: [10]bool; allowed[0], allowed[1], allowed[2] = true, true, true
	switch r.op {
	case "select-section":
		allowed[7] = true; if !seen[7] {return {}, false}
	case "find":
		count := 0; for n in ([]int{3, 4, 5}) {if seen[n] {count += 1; allowed[n] = true}}
		if count != 1 {return {}, false}
	case "inspect", "geometry", "focus", "activate", "begin-hold":
		allowed[3] = true; if !seen[3] {return {}, false}
	case "scroll":
		allowed[3], allowed[9] = true, true; if !seen[3] || !seen[9] {return {}, false}
	case "advance-hold":
		allowed[8] = true; if !seen[8] {return {}, false}
	case "navigate":
		allowed[6] = true
		if r.direction != "forward" && r.direction != "backward" {return {}, false}
	case "capabilities",
	     "list-sections",
	     "tree",
	     "diagnostics",
	     "assert-no-errors",
	     "cancel",
	     "release-hold",
	     "cancel-hold",
	     "snapshot",
	     "set_value",
	     "drag",
	     "overlays",
	     "crop",
	     "finish-transitions":
	case:
		return {}, false
	}
	for present, n in seen {if present && !allowed[n] {return {}, false}}
	return r, true
}
