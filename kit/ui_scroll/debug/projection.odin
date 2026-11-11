package ui_scroll_debug
import scroll ".."
import base "../../ui_base"
import debug "../../ui_debug"
import common "../../ui_inspect"
import wire "../../ui_wire"
import "core:mem"
Scroll_State :: struct {
	id, anchor_id:                            string,
	viewport:                                 base.Rect,
	extent, offset, max_offset, intra_offset: f64,
	items:                                    []scroll.Item,
}
project_node :: proc(f: ^scroll.Frame, n: ^debug.Wire_Node, a: mem.Allocator) -> bool {for r in f.regions {if r.id ==
		   n.resolved.description.id {v := Scroll_State {
				r.id,
				r.anchor_id,
				r.viewport,
				r.extent,
				r.offset,
				r.max_offset,
				r.intra_offset,
				r.items,
			}
			n.scroll = debug.Encoded_Value(debug.encode(v, a))
			return n.scroll != nil}}
	return true}
action_status :: proc(
	i: ^common.Inspection,
	f: ^scroll.Frame,
	id: string,
) -> (
	debug.Action_Status,
	bool,
) {
	r := debug.Action_Status {
		capability = i.capabilities[.Scroll_By],
		code       = .Invalid_Action,
	}
	for s in f.regions {if s.id == id {r.suitable = true; if r.capability {if !common.is_ready(i) {r.code = .Not_Ready} else {c, ok := wire.code(s.availability); if !ok {return {}, false}; r.code = c}}; return r, true}}
	if r.capability {r.code = .Not_Found; if !common.is_ready(i) {r.code = .Not_Ready}}; return r, true
}
