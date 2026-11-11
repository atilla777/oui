package main

import app "../ui_showcase/app"
import "core:encoding/json"
import "core:fmt"
import "core:mem"
import profile "profile"
import debug "ui:ui_debug"
import inspect "ui:ui_inspect"
import backend "ui:ui_sdl"

#assert(app.TOOLS, "ui_showcase_tools requires -define:UI_SHOWCASE_TOOLS=true")

Host :: struct {
	last_failure:       struct {
		code:                     string,
		epoch, attempt, revision: u64,
	},
	native_surfaces:    backend.Resource_Ledger,
	snapshot_index:     u64,
	snapshot_fault:     string,
	shell:              ^app.Shell,
	allowed, test_time: bool,
	run:                string,
}
minimal_error :: proc(id, code: string, a: mem.Allocator) -> []u8 {
	value := struct {
		protocol:   int,
		request_id: string,
		ok:         bool,
		error:      Error,
	}{19, id, false, {code, "", "request"}}
	data, error := json.marshal(value, allocator = a)
	if error != nil {return nil}
	if len(data) + 1 <= profile.MESSAGE_LIMIT {return data}; delete(data, a)
	value.request_id, value.error.code = "", "Message_Too_Large"
	data, error = json.marshal(value, allocator = a); if error != nil {return nil}; return data
}
encode_reply :: proc(
	h: ^Host,
	r: profile.Request,
	result: any,
	code, phase: string,
	a: mem.Allocator,
) -> []u8 {
	v := make_reply(h, r, result, code, phase)
	data := debug.encode_object(
		[]debug.Object_Field {
			{"protocol", v.protocol},
			{"request_id", v.request_id},
			{"ok", v.ok},
			{"error", v.error},
			{"ready", v.ready},
			{"historical", v.historical},
			{"section", v.section},
			{"screen_epoch", v.screen_epoch},
			{"frame_id", v.frame_id},
			{"model_revision", v.model_revision},
			{"published_revision", v.published_revision},
			{"result", result},
		},
		a,
	)
	if data == nil {return minimal_error(r.request_id, "Encoding_Failed", a)}
	if len(data) + 1 >
	   profile.MESSAGE_LIMIT {delete(data, a); return minimal_error(r.request_id, "Message_Too_Large", a)}
	return data
}
handle_line :: proc(user: rawptr, line: []u8, a: mem.Allocator) -> []u8 {
	h := cast(^Host)user
	r, valid := profile.parse_request(line)
	when !(ODIN_DEBUG ||
		#config(UI_DEMO_TEST, false)) {return minimal_error(r.request_id, "Forbidden", a)}
	if h == nil || !h.allowed {return minimal_error(r.request_id, "Forbidden", a)}
	if !valid {return minimal_error(r.request_id, "Invalid_Request", a)}
	if r.op != "capabilities" && r.op != "list-sections" {
		if error := metadata_error(h); error != "" {
			if h.shell != nil {remember_failure(h, error)}
			return encode_reply(h, r, nil, error, "published_frame", a)
		}
	}
	switch r.op {
	case "set_value", "drag", "overlays", "crop", "finish-transitions":
		return encode_reply(h, r, nil, "Unsupported_Action", "request", a)
	case "capabilities":
		section := ""; if h.shell != nil {section = app.section_id(h.shell.model.page)}
		return encode_reply(h, r, struct {
				operations, unsupported: []string,
				test_time:               bool,
				section:                 string,
			}{OPERATIONS, UNSUPPORTED, h.test_time, section}, "", "published_frame", a)
	case "list-sections":
		return encode_reply(h, r, struct {
				sections: []Section,
			}{section_inventory(h)}, "", "published_frame", a)
	case "select-section":
		if h.shell == nil {return encode_reply(h, r, nil, "Not_Ready", "update", a)}
		if !app.begin_tool_record(
			h.shell,
			r.request_id,
			r.op,
			r.section,
			.Agent,
		) {app.block(&h.shell.runtime); return encode_reply(h, r, nil, "Allocation", "update", a)}
		before := h.shell.model.effects
		x := app.request_section(h.shell, r.section, .Agent)
		app.finish_tool_record(&h.shell.runtime, app.tool_code_name(x.code))
		code := ""; if x.code != .Applied {code = fmt.tprintf("%v", x.code)} else if !x.ready {code = "Not_Ready"}
		result := struct {
			selection: struct {
				requested, current, status: string,
			},
			using _:   Action_Result,
		}{}
		result.selection.requested, result.selection.current, result.selection.status =
			r.section, app.section_id(h.shell.model.page), x.status
		result.dispatch = {fmt.tprintf("%v", x.code), r.section, "Agent", x.sequence, false}
		result.application = {x.application_status, ""}
		result.effects_before, result.effects_after, result.observation =
			before, h.shell.model.effects, observation(h)
		return encode_reply(h, r, result, code, "update", a)
	case "focus",
	     "navigate",
	     "activate",
	     "cancel",
	     "scroll",
	     "begin-hold",
	     "advance-hold",
	     "release-hold",
	     "cancel-hold":
		if h.shell == nil {return encode_reply(h, r, nil, "Not_Ready", "update", a)}
		if !app.begin_tool_record(
			h.shell,
			r.request_id,
			r.op,
			r.id,
			.Agent,
		) {app.block(&h.shell.runtime); return encode_reply(h, r, nil, "Allocation", "update", a)}
		x := app.execute_tool_action(
			h.shell,
			{
				op = r.op,
				id = r.id,
				backwards = r.direction == "backward",
				delta_y = r.delta_y,
				duration_ms = r.duration_ms,
				test_time = h.test_time,
			},
		)
		app.finish_tool_record(&h.shell.runtime, x.code)
		code := ""; if x.code != "Applied" {code = x.code} else if !x.ready {code = "Not_Ready"}
		result := Action_Result {
			{x.code, r.id, "Agent", x.sequence, x.has_event},
			{x.application, ""},
			x.effects_before,
			x.effects_after,
			observation(h),
		}
		return encode_reply(h, r, result, code, "update", a)
	}
	reader, ready := selected_reader(h)
	if r.op == "diagnostics" || r.op == "assert-no-errors" {
		diagnostics, strict := current_diagnostics(h, reader, ready)
		code := ""; if r.op == "assert-no-errors" && !strict {code = "Strict_Failed"}
		return encode_reply(h, r, struct {
				diagnostics: []inspect.Diagnostic_Record,
				strict_ok:   bool,
			}{diagnostics, strict}, code, "published_frame", a)
	}
	if reader == nil {return encode_reply(h, r, nil, "Not_Ready", "published_frame", a)}
	i := reader.tools.inspection; i.ready, i.historical = ready, !ready
	switch r.op {
	case "tree":
		nodes := make([]Node, len(i.frame.nodes), context.temp_allocator)
		for n, k in i.frame.nodes {nodes[k], _ = node_projection(reader, ready, n.description.id)}
		return encode_reply(h, r, struct {
				nodes:       []Node,
				observation: app.Tool_Observation,
			}{nodes, observation(h)}, "", "published_frame", a)
	case "find":
		query := inspect.Query {
			kind         = .ID,
			exact_string = r.id,
		}
		if r.role != "" {query.kind, query.exact_string = .Role, r.role}
		if r.name != "" {query.kind, query.exact_string = .Name, r.name}
		matches, error := inspect.find(&i, query, context.temp_allocator)
		if error != .None {return encode_reply(h, r, nil, "Allocation", "published_frame", a)}
		ids := make([]string, len(matches), context.temp_allocator)
		for index, k in matches {ids[k] = i.frame.nodes[index].description.id}
		return encode_reply(h, r, struct {
				ids: []string,
			}{ids}, "", "published_frame", a)
	case "inspect", "geometry":
		node, found := node_projection(reader, ready, r.id)
		if !found {return encode_reply(h, r, nil, "Not_Found", "published_frame", a)}
		if r.op == "geometry" {
			result := struct {
				id:                                string,
				bounds, content, clip, paint_clip: type_of(node.bounds),
				drawable:                          type_of(i.frame.drawable),
				ui_scale:                          f64,
			} {
				r.id,
				node.bounds,
				node.content,
				node.clip,
				node.paint_clip,
				i.frame.drawable,
				i.frame.ui_scale,
			}
			return encode_reply(h, r, result, "", "published_frame", a)
		}
		return encode_reply(h, r, struct {
				node: Node,
			}{node}, "", "published_frame", a)
	case "diagnostics", "assert-no-errors":
		strict := inspect.strict_result(&i).ok
		diagnostics := i.diagnostics
		if h.shell.runtime.error != .None {
			extra := make(
				[]inspect.Diagnostic_Record,
				len(diagnostics) + 1,
				context.temp_allocator,
			)
			copy(extra, diagnostics)
			extra[len(diagnostics)] = {
				code             = fmt.tprintf("%v", h.shell.runtime.error),
				severity         = .Error,
				phase            = .update,
				attempt_revision = h.shell.model.revision,
			}
			diagnostics, strict = extra, false
		}
		code := ""; if r.op == "assert-no-errors" && !strict {code = "Strict_Failed"}
		return encode_reply(h, r, struct {
				diagnostics: []inspect.Diagnostic_Record,
				strict_ok:   bool,
			}{diagnostics, strict}, code, "published_frame", a)
	case "snapshot":
		path, error := capture_snapshot(h, a); defer delete(path, a)
		if error !=
		   "" {remember_failure(h, error); return encode_reply(h, r, nil, error, "snapshot", a)}
		return encode_reply(h, r, struct {
				path, manifest, image: string,
			}{path, "snapshot.json", "screenshot.bmp"}, "", "snapshot", a)
	}
	return minimal_error(r.request_id, "Invalid_Request", a)
}
