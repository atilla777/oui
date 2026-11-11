package ui_layers_debug
import layers ".."
import debug "../../ui_debug"
import common "../../ui_inspect"
import "core:mem"
project_frame :: proc(f: ^layers.Frame, m: ^debug.Frame_Metadata, a: mem.Allocator) -> bool {
	if f.layers.base_root_id !=
	   "" {m.layers = debug.Encoded_Value(debug.encode(f.layers, a)); if m.layers == nil {return false}}
	m.groups = debug.Encoded_Value(debug.encode(f.groups[:], a)); if m.groups == nil {return false}
	m.paint = debug.Encoded_Value(debug.encode(f.paint[:], a)); return m.paint != nil
}
cancel_status :: proc(i: ^common.Inspection, f: ^layers.Frame) -> debug.Action_Status {
	r := debug.Action_Status {
		capability = i.capabilities[.Cancel],
		suitable   = true,
		code       = .Invalid_Action,
	}
	if r.capability {if !common.is_ready(i) {r.code = .Not_Ready} else if len(f.layers.modals) > 0 && f.layers.modals[len(f.layers.modals) - 1].cancel_allowed {r.code = .Applied}}
	return r
}
