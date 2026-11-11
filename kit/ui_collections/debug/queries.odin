package ui_collections_debug
import debug "../../ui_debug"
import common "../../ui_inspect"
import inspect "../inspect"
// Caller keeps p in its typed capture bundle and encodes it after this query.
query :: proc(
	i: ^common.Inspection,
	f: ^inspect.Inspection,
	r: Request,
	nodes: []debug.Wire_Node,
	result: ^debug.Result,
	p: ^Collection_Projection,
) -> (
	bool,
	string,
) {
	if r.op == "find" {
		q := common.Query {
			.ID,
			r.id,
		}; if r.role != "" {q = {.Role, r.role}} else if r.name != "" {q = {.Name, r.name}}
		v, e := inspect.find_with_collections(
			i,
			f,
			q,
			context.temp_allocator,
		); if e != .None {return true, common.error_name(e)}
		result.indices = v.indices; p.logical_items = v.logical_items; return true, ""
	}
	if r.op == "inspect" {
		v, e := inspect.inspect_with_collections(
			i,
			f,
			r.id,
		); if e != .None {return true, common.error_name(e)}
		if item, logical := v.(inspect.Logical_Item_View);
		   logical {p.logical_item = item} else {for n in nodes {if n.resolved.description.id == r.id {result.nodes = []debug.Wire_Node{n}; break}}}
		return true, ""
	}
	return false, ""
}
