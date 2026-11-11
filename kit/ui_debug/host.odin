package ui_debug

import base "../ui_base"
import inspect "../ui_inspect"
import wire "../ui_wire"
import "core:encoding/json"
import "core:mem"

// One statically selected host codec, not a registry. Callbacks are synchronous,
// non-reentrant and never retain Request strings/extension data (scratch-owned).
// Capture owns its common inspection and observation. release destroys only the
// caller's selected typed bundle; wire projections borrow that bundle until then.
Capture :: struct {
	inspection:        inspect.Inspection,
	observation:       []u8,
	error:             string,
	nodes:             []Wire_Node,
	frame:             Frame_Metadata,
	family:            wire.Frame_Family,
	fields:            Encoded_Value,
	required_protocol: int,
	owner:             rawptr,
	release:           proc(owner: rawptr, a: mem.Allocator),
}
Action_Reply :: struct {
	error:  string,
	fields: Encoded_Value,
}
Debug_Action :: struct {
	kind:        inspect.Action,
	id:          string,
	backwards:   bool,
	delta_y:     f64,
	duration_ms: i64,
}
Snapshot_Options :: struct {
	overlays: [3]bool,
}
Snapshot_Reply :: struct {
	path, error: string,
}
Capabilities :: struct {
	actions:            [inspect.Action]bool,
	snapshot, overlays: bool,
}
Host :: struct {
	serve:             proc(user: rawptr, line: []u8, a: mem.Allocator) -> []u8,
	user:              rawptr,
	allowed:           bool,
	protocol:          int,
	capabilities:      Capabilities,
	parse:             proc(line: []u8) -> (Request, bool),
	capture:           proc(user: rawptr, a: mem.Allocator) -> Capture,
	execute:           proc(user: rawptr, action: Debug_Action) -> Action_Reply,
	execute_extension: proc(user: rawptr, r: Request, a: mem.Allocator) -> Action_Reply,
	query:             proc(
		user: rawptr,
		c: ^Capture,
		r: Request,
		result: ^Result,
	) -> (
		handled: bool,
		error: string,
	),
	snapshot:          proc(
		user: rawptr,
		options: Snapshot_Options,
		a: mem.Allocator,
	) -> Snapshot_Reply,
}
Error :: struct {
	code, id, phase: string,
}
Frame_Metadata :: struct {
	drawable:                          base.Extent,
	ui_scale:                          f64,
	theme_revision, resource_revision: string,
	theme_provenance:                  bool,
	modal, layers:                     Encoded_Value,
	groups, paint:                     Encoded_Value,
	hold, hold_result:                 Encoded_Value,
}
Action_Status :: struct {
	capability, suitable: bool,
	code:                 wire.Code,
}
Wire_Node :: struct {
	parent_index:                               Maybe(int),
	children:                                   []int,
	structural_role:                            wire.Role,
	role, name, source_hint:                    string,
	resolved:                                   wire.Resolved_Node,
	presentation, text, scroll, progress, hold: Encoded_Value,
	selected:                                   Maybe(bool),
	actions:                                    [inspect.Action]Action_Status,
}
Result :: struct {
	frame:        Frame_Metadata,
	capabilities: Capabilities,
	family:       wire.Frame_Family,
	indices:      []int,
	nodes:        []Wire_Node,
	diagnostics:  []inspect.Diagnostic_Record,
	strict:       Maybe(inspect.Strict_Result),
	observation:  json.Value,
	path:         string,
}
Reply :: struct {
	protocol:                                     int,
	request_id:                                   string,
	ok:                                           bool,
	error:                                        Error,
	ready, historical:                            bool,
	model_revision, published_revision, frame_id: u64,
	result:                                       Result,
}
destroy_capture :: proc(c: ^Capture, a: mem.Allocator) {
	destroy_projection(c.nodes, &c.frame, c.fields, a)
	if c.release != nil {c.release(c.owner, a)}
	inspect.destroy_inspection(&c.inspection); delete(c.observation, a); c^ = {}
}
destroy_projection :: proc(
	nodes: []Wire_Node,
	frame: ^Frame_Metadata,
	fields: Encoded_Value,
	a: mem.Allocator,
) {
	for n in nodes {for b in ([5]Encoded_Value{n.presentation, n.text, n.scroll, n.progress, n.hold}) {delete(([]u8)(b), a)}}; delete(nodes, a)
	for b in ([7]Encoded_Value{frame.modal, frame.layers, frame.groups, frame.paint, frame.hold, frame.hold_result, fields}) {delete(([]u8)(b), a)}
	frame^ = {}
}
// Explicit descriptor supplies historical semantic role/description. New layout
// Kind.Content is not silently exported as a new wire enum.
node_projection :: proc(
	i: ^inspect.Inspection,
	id: string,
	d: wire.Node,
	selected_actions: Maybe([inspect.Action]Action_Status) = nil,
) -> (
	Wire_Node,
	bool,
) {
	v, e := inspect.inspect(i, id); if e != .None || d.id != id {return {}, false}
	n := v.resolved
	w := Wire_Node {
		parent_index    = v.parent_index,
		children        = v.children,
		structural_role = d.role,
		role            = v.role,
		name            = v.name,
		source_hint     = v.source_hint,
	}
	code := wire.Code.Invalid_Action
	if v.target !=
	   nil {var_ok: bool; code, var_ok = wire.code(v.target.availability); if !var_ok {return {}, false}}
	w.resolved = {
		rows         = n.rows,
		columns      = n.columns,
		description  = d,
		bounds       = n.bounds,
		content      = n.content,
		clip         = n.clip,
		paint_clip   = n.paint_clip,
		measured     = n.measured,
		style        = d.style,
		enabled      = n.enabled,
		visible      = n.visible,
		focused      = v.focused,
		hovered      = v.hovered,
		pressed      = v.pressed,
		availability = code,
	}
	if actions, provided := selected_actions.?; provided {w.actions = actions; return w, true}
	for action in inspect.Action {
		s := inspect.action_status(i, id, action); mapped, ok := wire.code(s.code)
		if action == .Focus || action == .Activate {s.suitable = d.role == .Button}
		if action == .Navigate ||
		   action == .Cancel ||
		   action == .Release ||
		   action == .Advance ||
		   action == .Hold_Cancel {s.suitable = true}
		// Selected owners replace their action statuses explicitly, never expose
		// Activation_Required as a new wire value in a supposedly old profile.
		if !ok && s.capability {return {}, false}
		w.actions[action] = {s.capability, s.suitable, mapped}
	}
	return w, true
}
