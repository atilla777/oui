package ui_collections_inspect
import family ".."
import base "../../ui_base"
import common "../../ui_inspect"
import "core:mem"
Inspection :: family.Frame
capture :: proc(
	i: ^common.Inspection,
	f: ^family.Frame,
	a: mem.Allocator,
) -> (
	Inspection,
	common.Inspect_Error,
) {
	if f == nil || !f.bound || f.stamp != i.frame.stamp {return {}, .Metadata_Mismatch}
	r, ok := family.try_copy_frame(f, a); if !ok {return {}, .Allocation}; return r, .None
}
destroy :: family.destroy_frame
Logical_Item_View :: struct {
	collection_id, item_id, id, name, disabled_reason:                     string,
	logical_ordinal, visible_ordinal:                                      int,
	enabled, hidden, selected, logical_focused, materialized, in_viewport: bool,
	bounds:                                                                Maybe(base.Rect),
}
Collection_View :: struct {
	id, selected_id, focus_id, anchor_id:                                                 string,
	total_count, visible_count, columns:                                                  int,
	visible_start, visible_end, materialized_start, materialized_end, materialized_count: int,
	extent, offset, intra_offset:                                                         f64,
	revision:                                                                             u64,
}
inspect_item :: proc(
	i: ^Inspection,
	collection_id, item_id, id: string,
) -> (
	Logical_Item_View,
	common.Inspect_Error,
) {
	s, found := family.inspect_collection(i, collection_id); if !found {return {}, .Not_Found}
	v, code := family.lookup_collection_item(
		i,
		collection_id,
		item_id,
	); if code != .Applied {return {}, .Not_Found}
	return {
			collection_id,
			item_id,
			id,
			v.item.semantic_name,
			v.item.disabled_reason,
			v.logical_ordinal,
			v.visible_ordinal,
			v.item.enabled,
			!v.item.visible,
			v.selected,
			s.focus_id == item_id,
			v.materialized,
			v.in_viewport,
			v.bounds,
		},
		.None
}
inspect_collections :: proc(
	i: ^Inspection,
	a: mem.Allocator,
) -> (
	[]Collection_View,
	common.Inspect_Error,
) {
	r, e := make([]Collection_View, len(i.collections), a); if e != nil {return nil, .Allocation}
	for s, k in i.collections {r[k] = {s.description.id, s.description.selected_id, s.focus_id, s.anchor_id, len(s.description.items), s.visible_count, s.columns, s.visible_start, s.visible_end, s.materialized_start, s.materialized_end, s.materialized_count, s.extent, s.offset, s.intra_offset, s.description.data_revision}}
	return r, .None
}
