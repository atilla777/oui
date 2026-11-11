package ui_collections_inspect
import family ".."
import common "../../ui_inspect"
import "core:mem"
Collection_Result :: union {
	common.Node_View,
	Logical_Item_View,
}
Collection_Find_Result :: struct {
	indices:       []int,
	logical_items: []Logical_Item_View,
}
inspect_with_collections :: proc(
	i: ^common.Inspection,
	f: ^Inspection,
	id: string,
) -> (
	Collection_Result,
	common.Inspect_Error,
) {
	collection, item, decoded := family.decode_item_node_id(id)
	if decoded {if _, known := family.inspect_collection(f, collection); known {v, e := inspect_item(f, collection, item, id); return v, e}}
	v, e := common.inspect(i, id); return v, e
}
find_with_collections :: proc(
	i: ^common.Inspection,
	f: ^Inspection,
	q: common.Query,
	a: mem.Allocator,
) -> (
	Collection_Find_Result,
	common.Inspect_Error,
) {
	if q.kind ==
	   .ID {v, e := inspect_with_collections(i, f, q.exact_string); if logical, ok := v.(Logical_Item_View); ok && e == .None {
			r, ae := make(
				[]Logical_Item_View,
				1,
				a,
			); if ae != nil {return {}, .Allocation}; r[0] = logical; return {logical_items = r}, .None
		}}
	indices, e := common.find(i, q, a); return {indices = indices}, e
}
