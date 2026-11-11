package ui_controls_debug
import controls ".."
import debug "../../ui_debug"
import common "../../ui_inspect"
import interaction "../../ui_interaction"
import wire "../../ui_wire"
semantic :: proc(f: ^controls.Frame, node_id: string) -> (common.Semantic, bool) {
	for c in f.controls {if c.node_id == node_id {v, ok := controls.inspect_control(f, c.id); if ok {return {node_id, v.role, c.label, ""}, true}}}; return {}, false
}
// Popup cancel priority precedes the containing dialog, even when refused.
cancel_status :: proc(
	i: ^common.Inspection,
	f: ^controls.Frame,
	fallback: debug.Action_Status,
) -> (
	debug.Action_Status,
	bool,
) {
	if !fallback.capability || !common.is_ready(i) {return fallback, true}
	for kind in ([]controls.Kind{.Select, .Dialog}) {for c in f.controls {
			if !c.open || c.kind != kind {continue}
			if kind == .Select &&
			   c.owner_scope_id ==
				   f.scope_id {v, _ := controls.inspect_control(f, c.id); code, ok := wire.code(v.availability); return {true, true, code}, ok}
			if kind == .Dialog && c.layer_id == f.scope_id {
				for item in c.items {if item.id == c.cancel_id {n, found := interaction.find(&i.interaction, item.node_id); if !found {return {true, true, .Not_Found}, true}; code, ok := wire.code(n.availability); return {true, true, code}, ok}}
				return {true, true, .Invalid_Action}, true
			}
		}}
	return fallback, true
}
