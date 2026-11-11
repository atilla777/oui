package ui_debug
import "core:encoding/json"
import "core:mem"
Raw_Field :: struct {
	key:        string,
	start, end: int,
}
// Only offsets of already encoded fixed DTOs are read. Values (notably u64s)
// are copied as tokens, never converted through json.Value/f64.
raw_fields :: proc(data: []u8) -> ([]Raw_Field, bool) {
	t := json.make_tokenizer(string(data), .JSON, true)
	open, oe := json.get_token(&t); if oe != .None || open.kind != .Open_Brace {return nil, false}
	r := make([dynamic]Raw_Field, 0, 0, context.temp_allocator)
	key, ke := json.get_token(&t)
	if ke != .None {return nil, false}
	if key.kind == .Close_Brace {_, e := json.get_token(&t); return r[:], e == .EOF}
	for {
		if key.kind != .String {return nil, false}
		for p in r {if p.key == key.text {return nil, false}}
		colon, ce := json.get_token(&t); if ce != .None || colon.kind != .Colon {return nil, false}
		v, ve := json.get_token(&t); if ve != .None {return nil, false}
		start, end := v.offset, v.offset + len(v.text)
		if v.kind == .Open_Brace || v.kind == .Open_Bracket {
			depth := 1
			for depth > 0 {q, e := json.get_token(&t); if e != .None {return nil, false}
				if q.kind == .Open_Brace || q.kind == .Open_Bracket {depth += 1}
				if q.kind == .Close_Brace || q.kind == .Close_Bracket {depth -= 1}
				end = q.offset + len(q.text)
			}
		} else if v.kind != .String &&
		   v.kind != .Integer &&
		   v.kind != .Float &&
		   v.kind != .Null &&
		   v.kind != .True &&
		   v.kind != .False {return nil, false}
		if _, e := append(&r, Raw_Field{key.text, start, end}); e != nil {return nil, false}
		sep, se := json.get_token(&t); if se != .None {return nil, false}
		if sep.kind == .Close_Brace {_, e := json.get_token(&t); return r[:], e == .EOF}
		if sep.kind !=
		   .Comma {return nil, false}; key, ke = json.get_token(&t); if ke != .None {return nil, false}
	}
}
set_result_field :: proc(data: []u8, key: string, value: []u8, a: mem.Allocator) -> []u8 {
	top, ok := raw_fields(data); if !ok {return nil}
	for outer in top {if outer.key == `"result"` {
			inner, valid := raw_fields(data[outer.start:outer.end]); if !valid {return nil}
			for f in inner {if f.key == key {
					start, end := outer.start + f.start, outer.start + f.end
					r, e := make(
						[]u8,
						len(data) - (end - start) + len(value),
						a,
					); if e != nil {return nil}
					n := copy(
						r,
						data[:start],
					); n += copy(r[n:], value); copy(r[n:], data[end:]); return r
				}}
			comma := 0; if len(inner) > 0 {comma = 1}; at := outer.end - 1
			r, e := make(
				[]u8,
				len(data) + comma + len(key) + 1 + len(value),
				a,
			); if e != nil {return nil}
			n := copy(
				r,
				data[:at],
			); if comma > 0 {r[n] = ','; n += 1}; n += copy(r[n:], transmute([]u8)key); r[n] = ':'; n += 1; n += copy(r[n:], value); copy(r[n:], data[at:]); return r
		}}
	return nil
}
encode_result_projection :: proc(data: []u8, p: any, a: mem.Allocator) -> []u8 {
	if p == nil {return copy_bytes(data, a)}
	fields := encode(p, context.temp_allocator); if fields == nil {return nil}
	spans, ok := raw_fields(fields); if !ok {return nil}
	current := copy_bytes(data, a); if current == nil {return nil}
	for f in spans {next := set_result_field(current, f.key, fields[f.start:f.end], a); delete(current, a); if next == nil {return nil}; current = next}
	return current
}
