package ui_gestures_debug

import ui ".."
import base "../../ui_base"
import debug "../../ui_debug"
import interaction "../../ui_interaction"
import wire "../../ui_wire"
import inspect "../inspect"
import "core:encoding/json"
import "core:mem"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"

Request :: debug.Request
MESSAGE_LIMIT :: debug.MESSAGE_LIMIT
parse_request :: debug.parse_request
encode_result_projection :: debug.encode_result_projection
Gesture_Request :: struct {
	action:        ui.Action,
	point_present: bool,
}
Gesture_State :: struct {
	owner:           ui.Description,
	source:          interaction.Source,
	phase:           ui.Phase,
	cycle:           u64,
	target_id:       string,
	target_accepted: bool,
	elapsed_ms:      i64,
	start, current:  [2]f64,
	start_offset:    f64,
	model_revision:  u64,
	reason:          ui.Cancel_Reason,
}
Gesture_Result :: struct {
	signals:      [2]ui.Signal,
	count:        int,
	code:         wire.Code,
	cycle:        u64,
	phase:        ui.Phase,
	reason:       ui.Cancel_Reason,
	has_proposal: bool,
	proposal:     ui.Drop_Proposal,
}
Gesture_Reply :: struct {
	error:  string,
	code:   wire.Code,
	cycle:  u64,
	phase:  ui.Phase,
	reason: ui.Cancel_Reason,
}
Gesture_View :: struct {
	description:  ui.Description,
	availability: wire.Code,
	actions:      bit_set[ui.Action_Kind],
	offset:       Maybe(f64),
}
Gesture_Projection :: struct {
	gesture_state:          Gesture_State,
	gesture_result:         Gesture_Result,
	gesture_model_revision: u64,
	gestures:               []Gesture_View,
	gesture:                Maybe(Gesture_View),
	gesture_reply:          Maybe(Gesture_Reply),
	gesture_actions:        bool,
}
// JSON Value numbers are f64 (integer mode is only i64). Preserve validated
// application JSON tokens for opt-in u64 cycle fidelity. Canonical encoding
// has one null placeholder; escaped user strings cannot manufacture its key.
@(private)
encode_gesture_projection :: proc(
	base: []u8,
	p: any,
	observation: []u8,
	a: mem.Allocator,
) -> []u8 {
	data := encode_result_projection(base, p, a)
	if data == nil || len(observation) == 0 {return data}
	defer delete(data, a)
	compact := make([dynamic]u8, context.temp_allocator); defer delete(compact)
	tokens := json.make_tokenizer(string(observation), .JSON, true)
	for {
		v, e := json.get_token(&tokens); if e == .EOF {break}; if e != .None {return nil}
		append(&compact, ..transmute([]u8)v.text)
	}
	// Preserve integer spelling while removing whitespace/newlines outside
	// strings: transport still emits exactly one JSON line.
	raw := compact[:]
	needle := `"observation":null`
	at := strings.index(string(data), needle)
	if at < 0 || strings.index(string(data)[at + len(needle):], needle) >= 0 {return nil}
	start := at + len(needle) - 4
	r := make([]u8, len(data) - 4 + len(raw), a)
	n := copy(r, data[:start]); n += copy(r[n:], raw); copy(r[n:], data[start + 4:])
	return r
}
gesture_projection :: proc(
	i: ^inspect.Inspection,
	ready: bool,
	id: string,
	enabled: bool,
) -> (
	Gesture_Projection,
	bool,
) {
	l := i.live; r := i.result
	code, valid := wire.code(r.code); if !valid {return {}, false}
	views, e := inspect.inspect_gestures(
		i,
		ready,
		context.temp_allocator,
	); if e != .None {return {}, false}
	p := Gesture_Projection {
		gesture_state          = {
			l.owner,
			l.source,
			l.phase,
			l.cycle,
			l.target_id,
			l.target_accepted,
			l.elapsed_ms,
			l.start,
			l.current,
			l.start_offset,
			l.model_revision,
			l.reason,
		},
		gesture_result         = {
			r.signals,
			r.count,
			code,
			r.cycle,
			r.phase,
			r.reason,
			r.has_proposal,
			r.proposal,
		},
		gesture_model_revision = i.model_revision,
		gestures               = make([]Gesture_View, len(views), context.temp_allocator),
		gesture_actions        = enabled,
	}
	for v, k in views {mapped, ok := wire.code(v.availability); if !ok {return {}, false}; p.gestures[k] = {v.description, mapped, v.actions, v.offset}}
	if !enabled {for &v in p.gestures {v.actions = {}}}
	if id != "" {for v in p.gestures {if v.description.id == id {p.gesture = v; break}}}
	return p, true
}

parse_gestures_request :: proc(line: []u8) -> (Request, bool) {
	if len(line) >= MESSAGE_LIMIT || !utf8.valid_string(string(line)) {return {}, false}
	for b in line {if b == 0 {return {}, false}}
	normalized := slice.clone(line, context.temp_allocator)
	t := json.make_tokenizer(string(line), .JSON, true)
	depth, versions := 0, 0
	key_expected, value_expected := false, false
	key, op := "", ""
	for {
		v, e := json.get_token(&t); if e == .EOF {break}; if e != .None {return {}, false}
		if depth == 1 && value_expected {
			if key ==
			   "protocol" {if v.kind != .Integer || v.text != "14" {return {}, false}; versions += 1; normalized[v.offset + 1] = '0'}
			if key == "op" &&
			   v.kind ==
				   .String {decoded, err := json.parse_string(v.text, .JSON, true, context.temp_allocator); if err != nil {return {}, false}; op = decoded.(string)}
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
			if depth == 1 &&
			   key_expected {decoded, err := json.parse_string(v.text, .JSON, true, context.temp_allocator); if err != nil {return {}, false}; key = decoded.(string); key_expected = false}
		case:
		}
	}
	if versions != 1 {return {}, false}
	if !strings.has_prefix(op, "gesture_") {
		r, ok := parse_request(normalized); r.protocol = 14; return r, ok
	}
	t = json.make_tokenizer(string(line), .JSON, true)
	open, error := json.get_token(
		&t,
	); if error != .None || open.kind != .Open_Brace {return {}, false}
	r := Request {
		protocol = 14,
	}
	g := ui.Action {
		source = .Agent,
	}
	seen: [8]bool
	for {
		k, ke := json.get_token(&t); if ke != .None || k.kind != .String {return {}, false}
		decoded, de := json.parse_string(
			k.text,
			.JSON,
			true,
			context.temp_allocator,
		); if de != nil {return {}, false}
		index := -1
		for name, i in ([8]string{"protocol", "request_id", "op", "id", "cycle", "x", "y", "duration_ms"}) {if name == decoded.(string) {index = i}}
		if index < 0 || seen[index] {return {}, false}; seen[index] = true
		colon, ce := json.get_token(&t); if ce != .None || colon.kind != .Colon {return {}, false}
		v, ve := json.get_token(&t); if ve != .None {return {}, false}
		switch index {
		case 0:
			if v.kind != .Integer || v.text != "14" {return {}, false}
		case 1, 2, 3:
			if v.kind != .String {return {}, false}
			value, e := json.parse_string(
				v.text,
				.JSON,
				true,
				context.temp_allocator,
			); if e != nil {return {}, false}
			s := value.(string); if s == "" {return {}, false}
			if index ==
			   1 {r.request_id = s}; if index == 2 {r.op = s}; if index == 3 {r.id, g.id = s, s}
		case 4:
			if v.kind != .Integer {return {}, false}
			n, ok := strconv.parse_u64(v.text); if !ok || n == 0 {return {}, false}; g.cycle = n
		case 5, 6:
			if v.kind != .Integer && v.kind != .Float {return {}, false}
			n, ok := strconv.parse_f64(
				v.text,
			); if !ok || !base.finite(n) {return {}, false}; g.point[index - 5] = n
		case 7:
			if v.kind != .Integer {return {}, false}
			n, ok := strconv.parse_i64(
				v.text,
			); if !ok || n < 0 {return {}, false}; g.duration_ms = n
		}
		separator, se := json.get_token(&t); if se != .None {return {}, false}
		if separator.kind == .Close_Brace {break}; if separator.kind != .Comma {return {}, false}
	}
	_, ee := json.get_token(
		&t,
	); if ee != .EOF || !seen[0] || !seen[1] || !seen[2] {return {}, false}
	allowed: [8]bool; allowed[0], allowed[1], allowed[2] = true, true, true
	switch r.op {
	case "gesture_begin":
		g.kind = .Begin; allowed[3], allowed[5], allowed[6] = true, true, true
		if !seen[3] || seen[5] != seen[6] {return {}, false}
	case "gesture_aim":
		g.kind = .Aim; allowed[3], allowed[4] = true, true
		if !seen[3] || !seen[4] {return {}, false}
	case "gesture_move":
		g.kind = .Move; allowed[4], allowed[5], allowed[6] = true, true, true
		if !seen[4] || !seen[5] || !seen[6] {return {}, false}
	case "gesture_advance":
		g.kind = .Advance; allowed[4], allowed[7] = true, true
		if !seen[4] || !seen[7] {return {}, false}
	case "gesture_end", "gesture_cancel":
		g.kind = .End; if r.op == "gesture_cancel" {g.kind, g.reason = .Cancel, .Explicit}
		allowed[4] = true; if !seen[4] {return {}, false}
	case:
		return {}, false
	}
	for present, i in seen {if present && !allowed[i] {return {}, false}}
	payload, allocation := new(
		Gesture_Request,
		context.temp_allocator,
	); if allocation != nil {return {}, false}; payload^ = {g, seen[5]}
	r.extension, r.extended_action = any{payload, typeid_of(Gesture_Request)}, true
	return r, true
}
