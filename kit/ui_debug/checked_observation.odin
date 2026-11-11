package ui_debug

import "core:encoding/json"
import "core:mem"
import "core:strings"

@(private)
parse_checked_observation :: proc(
	data: string,
	allocator: mem.Allocator,
) -> (
	json.Value,
	json.Error,
) {
	p := Observation_Parser {
		scanner   = json.make_tokenizer(data),
		allocator = allocator,
	}
	observation_next(&p)
	v, e := observation_value(&p)
	if e != .None {return nil, e}
	if p.error != .None || p.token.kind != .EOF {
		json.destroy_value(v, allocator)
		return nil, .Unexpected_Token
	}
	return v, .None
}

// Private to the two v10 observation consumers, not a general parser API.
// The standard JSON5 tokenizer/scalar decoder preserves the former conventions.
@(private)
Observation_Parser :: struct {
	scanner:   json.Tokenizer,
	token:     json.Token,
	error:     json.Error,
	allocator: mem.Allocator,
}
@(private)
observation_next :: proc(p: ^Observation_Parser) {
	if p.error != .None {return}
	token, e := json.get_token(&p.scanner)
	// The installed JSON5 tokenizer leaves this diagnostic set on a valid
	// single-quoted String; its parser accepts that token. Preserve that
	// convention, not arbitrary Invalid tokens or unterminated literals.
	if e == .Illegal_Character &&
	   token.kind == .String &&
	   len(token.text) >= 2 &&
	   token.text[0] == '\'' {e = .None}
	p.token = token
	if e != .EOF {p.error = e}
}
@(private)
observation_value :: proc(p: ^Observation_Parser) -> (json.Value, json.Error) {
	if p.error != .None {return nil, p.error}
	#partial switch p.token.kind {
	case .Open_Bracket:
		return observation_array(p)
	case .Open_Brace:
		return observation_object(p)
	case .Null, .True, .False, .Integer, .Float, .String, .Infinity, .NaN:
		v, e := json.parse_string(p.token.text, allocator = p.allocator)
		if e != .None {return nil, e}
		observation_next(p)
		if p.error != .None {json.destroy_value(v, p.allocator); return nil, p.error}
		return v, .None
	case:
		return nil, .Unexpected_Token
	}
}
@(private)
observation_array :: proc(p: ^Observation_Parser) -> (json.Value, json.Error) {
	a: json.Array
	a.allocator = p.allocator
	complete := false
	defer {if !complete {json.destroy_value(json.Value(a), p.allocator)}}
	observation_next(p)
	for p.token.kind != .Close_Bracket {
		v, e := observation_value(p)
		if e != .None {return nil, e}
		if _, ae := append(&a, v);
		   ae != nil {json.destroy_value(v, p.allocator); return nil, .Out_Of_Memory}
		if p.token.kind == .Close_Bracket {break}
		if p.token.kind != .Comma {return nil, .Unexpected_Token}
		observation_next(p)
	}
	observation_next(p)
	if p.error != .None {return nil, p.error}
	complete = true
	return a, .None
}
@(private)
observation_object :: proc(p: ^Observation_Parser) -> (json.Value, json.Error) {
	o := make(json.Object, allocator = p.allocator)
	complete := false
	defer {if !complete {json.destroy_value(json.Value(o), p.allocator)}}
	observation_next(p)
	for p.token.kind != .Close_Brace {
		if p.error != .None {return nil, p.error}
		key: string
		if p.token.kind == .String {
			v, e := json.parse_string(p.token.text, allocator = p.allocator)
			if e != .None {return nil, e}
			key = string(v.(json.String))
		} else if p.token.kind == .Ident {
			var_error: mem.Allocator_Error
			key, var_error = strings.clone(p.token.text, p.allocator)
			if var_error != nil {return nil, .Out_Of_Memory}
		} else {return nil, .Expected_String_For_Object_Key}
		stored := false
		defer {if !stored {delete(key, p.allocator)}}
		if key in o {return nil, .Duplicate_Object_Key}
		observation_next(p)
		if p.error != .None {return nil, p.error}
		if p.token.kind != .Colon {return nil, .Expected_Colon_After_Key}
		observation_next(p)
		v, e := observation_value(p)
		if e != .None {return nil, e}
		if ae := reserve(&o, len(o) + 1);
		   ae != nil {json.destroy_value(v, p.allocator); return nil, .Out_Of_Memory}
		o[key] = v; stored = true
		if p.token.kind == .Close_Brace {break}
		if p.token.kind != .Comma {return nil, .Unexpected_Token}
		observation_next(p)
	}
	observation_next(p)
	if p.error != .None {return nil, p.error}
	complete = true
	return o, .None
}
