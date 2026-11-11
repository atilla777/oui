package ui_debug

import inspect "../ui_inspect"
import "core:encoding/json"
import "core:mem"
import "core:strings"

encode :: proc(value: any, a: mem.Allocator) -> []u8 {
	if data, handled := encode_dto(value, a); handled {return data}
	data, e := json.marshal(
		value,
		{use_enum_names = true},
		a,
	); if e != nil {return nil}; return data
}
error_reply :: proc(id, code: string, a: mem.Allocator, protocol := 10) -> []u8 {
	v := struct {
		protocol:   int,
		request_id: string,
		ok:         bool,
		error:      Error,
	}{protocol, id, false, {code = code}}
	r := encode(v, a); if len(r) + 1 <= MESSAGE_LIMIT {return r}; delete(r, a)
	v.error.code = "Message_Too_Large"; r = encode(v, a); if len(r) + 1 <= MESSAGE_LIMIT {return r}; delete(r, a)
	v.request_id = ""; return encode(v, a)
}
// Insert typed selected fields without parsing/re-encoding numeric values. This
// is the previous result-object insertion algorithm, not an extension registry.
encode_observation :: proc(data, observation: []u8, a: mem.Allocator) -> []u8 {
	if len(observation) == 0 {return encode_result_projection(data, nil, a)}
	compact := make([dynamic]u8, 0, 0, context.temp_allocator); defer delete(compact)
	t := json.make_tokenizer(string(observation), .JSON, true)
	for {v, e := json.get_token(&t); if e == .EOF {break}; if e != .None {return nil}; if _, ae := append(&compact, ..transmute([]u8)v.text); ae != nil {return nil}}
	needle := `"observation":null`; at := strings.index(string(data), needle)
	if at < 0 || strings.index(string(data)[at + len(needle):], needle) >= 0 {return nil}
	start :=
		at +
		len(needle) -
		4; r, e := make([]u8, len(data) - 4 + len(compact), a); if e != nil {return nil}
	n := copy(
		r,
		data[:start],
	); n += copy(r[n:], compact[:]); copy(r[n:], data[start + 4:]); return r
}
bounded_reply :: proc(
	reply: Reply,
	fields, action_fields: Encoded_Value,
	raw_observation: []u8,
	a: mem.Allocator,
) -> []u8 {
	data := encode(reply, a)
	if data != nil &&
	   fields != nil {old := data; data = encode_result_projection(old, fields, a); delete(old, a)}
	if data != nil &&
	   action_fields !=
		   nil {old := data; data = encode_result_projection(old, action_fields, a); delete(old, a)}
	if data != nil &&
	   len(raw_observation) >
		   0 {old := data; data = encode_observation(old, raw_observation, a); delete(old, a)}
	if data == nil {return error_reply(reply.request_id, "Encoding_Failed", a, reply.protocol)}
	if len(data) + 1 >
	   MESSAGE_LIMIT {delete(data, a); return error_reply(reply.request_id, "Message_Too_Large", a, reply.protocol)}
	return data
}
handle_line :: proc(host: ^Host, line: []u8, a: mem.Allocator) -> []u8 {
	protocol := host.protocol; if protocol == 0 {protocol = 10}
	parser := host.parse; if parser == nil {parser = parse_request}
	r, valid := parser(line)
	if !(ODIN_DEBUG || #config(UI_DEMO_TEST, false)) ||
	   !host.allowed {return error_reply(r.request_id, "Forbidden", a, protocol)}
	if protocol < 10 ||
	   protocol > 18 ||
	   (protocol != 10 &&
			   host.parse ==
				   nil) {return error_reply(r.request_id, "Invalid_Profile", a, protocol)}
	if !valid ||
	   r.protocol != protocol {return error_reply(r.request_id, "Invalid_Request", a, protocol)}
	if host.serve != nil {return host.serve(host.user, line, a)}
	if host.capture == nil {return error_reply(r.request_id, "Not_Ready", a, protocol)}
	c := host.capture(host.user, a); defer destroy_capture(&c, a)
	if e := projection_error(&c, protocol);
	   e != "" {return error_reply(r.request_id, e, a, protocol)}
	if c.error != "" {return error_reply(r.request_id, c.error, a, protocol)}
	if c.required_protocol != 0 &&
	   c.required_protocol !=
		   protocol {return error_reply(r.request_id, "Unsupported_Projection", a, protocol)}
	action: inspect.Action; mutating := true
	switch r.op {
	case "focus":
		action = .Focus
	case "activate":
		action = .Activate
	case "begin":
		action = .Begin
	case "navigate":
		action = .Navigate
	case "scroll":
		action = .Scroll_By
	case "cancel":
		action = .Cancel
	case "release":
		action = .Release
	case "hold_cancel":
		action = .Hold_Cancel
	case "advance":
		action = .Advance
	case:
		mutating = false
	}
	outcome: Action_Reply
	defer delete(([]u8)(outcome.fields), a)
	// Selected read-only gates (notably protocol16 Interactive_Clock) must
	// refuse before callback/capability dispatch. The same pure projection
	// hook observes the fresh pair again after the single accepted mutation.
	if (mutating || r.extended_action) && host.query != nil {
		preflight := Result {
			frame        = c.frame,
			capabilities = host.capabilities,
			family       = c.family,
		}
		_, code := host.query(host.user, &c, r, &preflight)
		if code != "" {return error_reply(r.request_id, code, a, protocol)}
	}
	if mutating || r.extended_action {
		supported := host.execute != nil && host.capabilities.actions[action]
		if r.extended_action {supported = host.execute_extension != nil}
		if !supported {outcome.error = "Unsupported_Action"} else if !c.inspection.ready {outcome.error = "Not_Ready"} else {
			if r.extended_action {outcome = host.execute_extension(host.user, r, a)} else {outcome = host.execute(host.user, {action, r.id, r.direction == "backward", r.delta_y, r.duration_ms})}
			// Never retry a mutation after an unknown/failed rebuild or transport.
			destroy_capture(&c, a); c = host.capture(host.user, a)
			if e := projection_error(&c, protocol);
			   e != "" {return error_reply(r.request_id, e, a, protocol)}
			if c.error != "" {return error_reply(r.request_id, c.error, a, protocol)}
			if c.required_protocol != 0 &&
			   c.required_protocol !=
				   protocol {return error_reply(r.request_id, "Unsupported_Projection", a, protocol)}
		}
	}
	i := &c.inspection
	reply := Reply {
		protocol = protocol,
		request_id = r.request_id,
		ready = i.ready,
		historical = i.historical,
		model_revision = i.model_revision,
		published_revision = i.published_revision,
		frame_id = i.frame.id,
		result = {frame = c.frame, capabilities = host.capabilities, family = c.family},
		error = {code = outcome.error},
	}
	raw: []u8
	if len(c.observation) > 0 {
		v: json.Value; e: json.Error
		if protocol ==
		   10 {v, e = parse_checked_observation(string(c.observation), context.temp_allocator)} else {v, e = json.parse(string(c.observation), allocator = context.temp_allocator)}
		if e != nil {return error_reply(r.request_id, "Encoding_Failed", a, protocol)}
		if protocol == 14 ||
		   protocol == 15 ||
		   protocol == 16 ||
		   protocol == 17 {raw = c.observation} else {reply.result.observation = v}
	}
	if !mutating && !r.extended_action {
		handled := false
		if host.query !=
		   nil {handled, reply.error.code = host.query(host.user, &c, r, &reply.result)}
		if !handled {
			switch r.op {
			case "capabilities":
			case "find":
				q := inspect.Query{.ID, r.id}
				if r.role != "" {q = {.Role, r.role}} else if r.name != "" {q = {.Name, r.name}}
				e: inspect.Inspect_Error
				reply.result.indices, e = inspect.find(i, q, context.temp_allocator)
				if e != .None {reply.error.code = inspect.error_name(e)}
			case "inspect":
				found := false
				for n in c.nodes {if n.resolved.description.id == r.id {reply.result.nodes = []Wire_Node{n}; found = true; break}}
				if !found {reply.error.code = "Not_Found"}
			case "tree":
				reply.result.nodes = c.nodes
			case "diagnostics":
				reply.result.diagnostics = i.diagnostics
			case "assert_no_errors":
				s := inspect.strict_result(i); reply.result.strict = s
				if !s.ok {reply.error.code = "Strict_Failed"}
			case "snapshot":
				if !host.capabilities.snapshot ||
				   host.snapshot ==
					   nil {reply.error.code = "Unsupported_Action"} else if !i.ready {reply.error.code = "Not_Ready"} else if (r.overlays[0] || r.overlays[1] || r.overlays[2]) && !host.capabilities.overlays {reply.error.code = "Unsupported_Action"} else {
					s := host.snapshot(
						host.user,
						{r.overlays},
						a,
					); reply.result.path, reply.error.code = s.path, s.error; defer delete(s.path, a)
					reply.ok =
						reply.error.code == ""; return bounded_reply(reply, c.fields, nil, raw, a)
				}
			case "set_value", "drag":
				reply.error.code = "Unsupported_Action"
			case:
				reply.error.code = "Unsupported_Action"
			}
		}
	}
	if (mutating || r.extended_action) &&
	   host.query !=
		   nil {_, e := host.query(host.user, &c, r, &reply.result); if e != "" {reply.error.code = e}}
	reply.ok = reply.error.code == ""
	if !reply.ok {reply.error.id = r.id; reply.error.phase = "published_frame" if i.ready else "update"}
	return bounded_reply(reply, c.fields, outcome.fields, raw, a)
}
