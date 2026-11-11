package ui_text_debug
import text ".."
import debug "../../ui_debug"
import common "../../ui_inspect"
import "core:mem"
project_node :: proc(f: ^text.Frame, n: ^debug.Wire_Node, a: mem.Allocator) -> bool {for &b in f.text_blocks {if b.node_id ==
		   n.resolved.description.id {n.text = debug.Encoded_Value(debug.encode(b, a)); return(
				n.text !=
				nil \
			)}}
	return true}
semantic :: proc(f: ^text.Frame, id, role: string) -> (common.Semantic, bool) {for b in f.text_blocks {if b.node_id ==
		   id {return {id, role, b.original_text, ""}, true}}
	return {}, false}
