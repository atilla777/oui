package ui_accessibility_debug

import base "../../ui_base"
import debug "../../ui_debug"
import ui "../../ui_transitions"
import td "../../ui_transitions/debug"
import inspect "../inspect"
import "core:encoding/json"
import "core:mem"
import "core:strings"

Frame_Metadata :: debug.Frame_Metadata
Capabilities :: debug.Capabilities
Wire_Node :: debug.Wire_Node
Error :: debug.Error
Snapshot_Metadata :: debug.Snapshot_Metadata
Transition_Projection :: td.Transition_Projection
encode :: debug.encode
error_reply :: debug.error_reply
MESSAGE_LIMIT :: debug.MESSAGE_LIMIT
node_projection :: proc(c: ^Accessibility_Capture, id: string) -> (Wire_Node, bool) {for n in c.nodes {if n.resolved.description.id ==
		   id {return n, true}}
	return {}, false}

Accessibility_Projection :: struct {
	policy:          inspect.Accessibility_Policy,
	policy_revision: u64,
	records:         []inspect.Accessibility_Record,
	strict:          inspect.Accessibility_Strict_Result,
	strict_selected: bool,
}
Accessibility_Result :: struct {
	frame:         Frame_Metadata,
	capabilities:  Capabilities,
	nodes:         []Wire_Node,
	indices:       []int,
	diagnostics:   []inspect.Diagnostic_Record,
	accessibility: Accessibility_Projection,
	transitions:   Transition_Projection,
	observation:   json.Value,
	path:          string,
}
Accessibility_Reply :: struct {
	protocol:                                     int,
	request_id:                                   string,
	ok:                                           bool,
	error:                                        Error,
	ready, historical:                            bool,
	frame_id, model_revision, published_revision: u64,
	result:                                       Accessibility_Result,
}
Accessibility_Snapshot_Document :: struct {
	protocol:                                     int,
	frame_id, model_revision, published_revision: u64,
	result:                                       Accessibility_Result,
	drawable, window_size, window_to_drawable:    base.Extent,
	ui_scale:                                     f64,
	backend, build_revision:                      string,
	build_dirty:                                  bool,
}
encode_accessibility_result :: proc(v: Accessibility_Result, a: mem.Allocator) -> []u8 {
	return debug.encode_object(
		[]debug.Object_Field {
			{"frame", v.frame},
			{"capabilities", v.capabilities},
			{"nodes", v.nodes},
			{"indices", v.indices},
			{"diagnostics", v.diagnostics},
			{"accessibility", v.accessibility},
			{"transitions", v.transitions},
			{"observation", v.observation},
			{"path", v.path},
		},
		a,
	)
}
accessibility_result :: proc(c: ^Accessibility_Capture, h: ^Host) -> Accessibility_Result {
	i := &c.assessment.inspection; i.capabilities = h.capabilities.actions
	return {
		frame = c.frame,
		capabilities = h.capabilities,
		diagnostics = i.diagnostics,
		accessibility = {
			c.assessment.policy,
			c.assessment.policy_revision,
			c.assessment.records,
			inspect.accessibility_strict_result(&c.assessment),
			c.strict_accessibility,
		},
		transitions = c.transitions,
	}
}
// Validate raw observation without converting u64 tokens through json.Value/f64.
encode_accessibility_document :: proc(document: any, observation: []u8, a: mem.Allocator) -> []u8 {
	base: []u8
	switch v in document {
	case Accessibility_Reply:
		r := encode_accessibility_result(v.result, context.temp_allocator)
		if r == nil {return nil}
		base = debug.encode_object(
			[]debug.Object_Field {
				{"protocol", v.protocol},
				{"request_id", v.request_id},
				{"ok", v.ok},
				{"error", v.error},
				{"ready", v.ready},
				{"historical", v.historical},
				{"frame_id", v.frame_id},
				{"model_revision", v.model_revision},
				{"published_revision", v.published_revision},
				{"result", debug.Encoded_Value(r)},
			},
			a,
		)
	case Accessibility_Snapshot_Document:
		r := encode_accessibility_result(v.result, context.temp_allocator)
		if r == nil {return nil}
		base = debug.encode_object(
			[]debug.Object_Field {
				{"protocol", v.protocol},
				{"frame_id", v.frame_id},
				{"model_revision", v.model_revision},
				{"published_revision", v.published_revision},
				{"result", debug.Encoded_Value(r)},
				{"drawable", v.drawable},
				{"window_size", v.window_size},
				{"window_to_drawable", v.window_to_drawable},
				{"ui_scale", v.ui_scale},
				{"backend", v.backend},
				{"build_revision", v.build_revision},
				{"build_dirty", v.build_dirty},
			},
			a,
		)
	case:
		return nil
	}
	if base == nil {return nil}; defer delete(base, a)
	_, e := json.parse(
		string(observation),
		allocator = context.temp_allocator,
	); if e != nil {return nil}
	compact := make([dynamic]u8, context.temp_allocator); defer delete(compact)
	tokens := json.make_tokenizer(string(observation), .JSON, true)
	for {v, error := json.get_token(&tokens); if error == .EOF {break}; if error != .None {return nil}; append(&compact, ..transmute([]u8)v.text)}
	needle := `"observation":null`; at := strings.index(string(base), needle)
	if at < 0 || strings.index(string(base)[at + len(needle):], needle) >= 0 {return nil}
	start := at + len(needle) - 4
	data, error := make([]u8, len(base) - 4 + len(compact), a); if error != nil {return nil}
	n := copy(
		data,
		base[:start],
	); n += copy(data[n:], compact[:]); copy(data[n:], base[start + 4:]); return data
}
handle_accessibility :: proc(h: ^Host, line: []u8, a: mem.Allocator) -> []u8 {
	r, valid := parse_accessibility_request(line)
	if !(ODIN_DEBUG || #config(UI_DEMO_TEST, false)) ||
	   !h.allowed {return error_reply(r.request_id, "Forbidden", a, 17)}
	if !valid {return error_reply(r.request_id, "Invalid_Request", a, 17)}
	if h.capture_accessibility == nil {return error_reply(r.request_id, "Not_Ready", a, 17)}
	c := h.capture_accessibility(h.user, a); defer destroy_accessibility_capture(&c, a)
	owned_path: string; defer delete(owned_path, a)
	if c.error != "" {return error_reply(r.request_id, c.error, a, 17)}
	if !accessibility_capture_valid(
		&c,
	) {return error_reply(r.request_id, "Metadata_Mismatch", a, 17)}
	mutating := false; action: inspect.Action
	switch r.op {case "focus":
		action, mutating = .Focus, true; case "activate":
		action, mutating = .Activate, true; case "begin":
		action, mutating = .Begin, true; case "release":
		action, mutating = .Release, true; case "hold_cancel":
		action, mutating = .Hold_Cancel, true; case "cancel":
		action, mutating = .Cancel, true; case "navigate":
		action, mutating = .Navigate, true; case "scroll":
		action, mutating = .Scroll_By, true}
	transition := r.op == "advance" || r.op == "finish-transitions"; outcome := ""
	if mutating || transition {
		if !c.assessment.inspection.ready ||
		   c.assessment.inspection.historical {outcome = "Not_Ready"} else if transition && !h.transition_test_time {outcome = "Interactive_Clock"} else if transition {
			if h.execute_transition == nil {outcome = "Unsupported_Action"} else {step := ui.Step {
					delta_ms = r.duration_ms,
				}; if r.op ==
				   "finish-transitions" {step.kind = .Finish_All}; outcome = h.execute_transition(h.user, step).error}
		} else if !h.capabilities.actions[action] ||
		   h.execute ==
			   nil {outcome = "Unsupported_Action"} else {outcome = h.execute(h.user, {kind = action, id = r.id, backwards = r.direction == "backward", delta_y = r.delta_y}).error}
		destroy_accessibility_capture(&c, a); c = h.capture_accessibility(h.user, a)
		if c.error != "" {return error_reply(r.request_id, c.error, a, 17)}
	}
	i := &c.assessment.inspection
	if !accessibility_capture_valid(
		&c,
	) {return error_reply(r.request_id, "Metadata_Mismatch", a, 17)}
	reply := Accessibility_Reply {
		protocol           = 17,
		request_id         = r.request_id,
		ready              = i.ready,
		historical         = i.historical,
		frame_id           = i.frame.id,
		model_revision     = i.model_revision,
		published_revision = i.published_revision,
		result             = accessibility_result(&c, h),
	}
	reply.error.code = outcome
	if !mutating && !transition {
		switch r.op {
		case "capabilities", "diagnostics":
		case "tree":
			reply.result.nodes = make([]Wire_Node, len(i.frame.nodes), context.temp_allocator)
			for n, k in i.frame.nodes {v, found := node_projection(&c, n.description.id); if !found {return error_reply(r.request_id, "Metadata_Mismatch", a, 17)}; reply.result.nodes[k] = v}
		case "inspect":
			_, error := inspect.inspect(i, r.id)
			if error !=
			   .None {reply.error.code = inspect.error_name(error)} else {v, found := node_projection(&c, r.id); if !found {return error_reply(r.request_id, "Metadata_Mismatch", a, 17)}; reply.result.nodes = []Wire_Node{v}}
		case "find":
			q := inspect.Query{.ID, r.id}
			if r.role != "" {q = {.Role, r.role}} else if r.name != "" {q = {.Name, r.name}}
			error: inspect.Inspect_Error
			reply.result.indices, error = inspect.find(i, q, context.temp_allocator)
			if error != .None {reply.error.code = inspect.error_name(error)}
		case "assert_no_errors":
			ok := inspect.strict_result(i).ok
			if c.strict_accessibility {ok = inspect.accessibility_strict_result(&c.assessment).ok}
			if !ok {reply.error.code = "Strict_Failed"}
		case "snapshot":
			if !i.ready ||
			   i.historical {reply.error.code = "Not_Ready"} else if h.snapshot == nil || !h.capabilities.snapshot || r.overlays[0] || r.overlays[1] || r.overlays[2] {reply.error.code = "Unsupported_Action"} else {
				s := h.snapshot(h.user, {r.overlays}, a); owned_path = s.path
				destroy_accessibility_capture(&c, a); c = h.capture_accessibility(h.user, a)
				if c.error != "" {return error_reply(r.request_id, c.error, a, 17)}
				if !accessibility_capture_valid(
					&c,
				) {return error_reply(r.request_id, "Metadata_Mismatch", a, 17)}
				i = &c.assessment.inspection
				reply.ready, reply.historical = i.ready, i.historical
				reply.frame_id, reply.model_revision, reply.published_revision =
					i.frame.id, i.model_revision, i.published_revision
				reply.result = accessibility_result(
					&c,
					h,
				); reply.result.path, reply.error.code = owned_path, s.error
			}
		case:
			reply.error.code = "Unsupported_Action"
		}
	}
	reply.ok = reply.error.code == ""
	data := encode_accessibility_document(reply, c.observation, a)
	if data == nil {return error_reply(r.request_id, "Encoding_Failed", a, 17)}
	if len(data) + 1 >
	   MESSAGE_LIMIT {delete(data, a); return error_reply(r.request_id, "Message_Too_Large", a, 17)}
	return data
}
encode_accessibility_snapshot :: proc(
	c: ^Accessibility_Capture,
	h: ^Host,
	metadata: Snapshot_Metadata,
	a: mem.Allocator,
) -> []u8 {
	if !accessibility_capture_valid(c) {return nil}
	i := &c.assessment.inspection
	if c.error != "" ||
	   !i.ready ||
	   i.historical ||
	   metadata.window_size.w <= 0 ||
	   metadata.window_size.h <= 0 ||
	   i.model_revision != i.published_revision {return nil}
	r := accessibility_result(
		c,
		h,
	); r.nodes = make([]Wire_Node, len(i.frame.nodes), context.temp_allocator)
	for n, k in i.frame.nodes {v, found := node_projection(c, n.description.id); if !found {return nil}; r.nodes[k] = v}
	f := &i.frame
	return encode_accessibility_document(
		Accessibility_Snapshot_Document {
			17,
			f.id,
			i.model_revision,
			i.published_revision,
			r,
			f.drawable,
			metadata.window_size,
			{f.drawable.w / metadata.window_size.w, f.drawable.h / metadata.window_size.h},
			f.ui_scale,
			metadata.backend,
			metadata.build_revision,
			metadata.build_dirty,
		},
		c.observation,
		a,
	)
}

@(private)
accessibility_capture_valid :: proc(c: ^Accessibility_Capture) -> bool {
	i := &c.assessment.inspection; f := &i.frame
	// Borrow only: reuse the common wire/common-frame binding checks without
	// transferring ownership or destroying this temporary view.
	projected := debug.Capture {
		inspection = i^,
		frame      = c.frame,
		nodes      = c.nodes,
	}
	if debug.projection_error(&projected, 17) != "" {return false}
	if i.ready && !inspect.is_ready(i) {return false}
	if len(f.nodes) == 0 ||
	   len(c.assessment.records) == 0 ||
	   i.model_revision < i.published_revision ||
	   (i.ready && (i.historical || i.model_revision != i.published_revision)) {return false}
	for r in c.assessment.records {
		if r.frame_id != f.id ||
		   r.model_revision != i.model_revision ||
		   r.published_revision != i.published_revision ||
		   r.transition_version != c.assessment.transition_version ||
		   r.policy_revision != c.assessment.policy_revision ||
		   r.minimum_contrast != c.assessment.policy.minimum_contrast ||
		   r.minimum_target != c.assessment.policy.minimum_target {return false}
	}
	return true
}
