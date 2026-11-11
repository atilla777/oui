package app

import collection_model "../../virtualized_collections_demo/model"
import sections "../sections"
import "core:fmt"
import "core:math"
import base "ui:ui_base"
import collections "ui:ui_collections"
import interaction "ui:ui_interaction"
import layout "ui:ui_layout"

Collection_Page_Runtime :: struct {
	state: collections.State,
	model: ^collection_model.State,
	items: []collections.Collection_Item,
	ids:   [10000][11]u8,
}
Collection_Page_Reader :: struct {
	frame: collections.Frame,
}

// Fixed shell and page rows in logical units. bind_candidate checks this exact
// rectangle against the one final solver result, never a second solver pass.
COLLECTION_TOP :: 6 + 18 + 4 + 25 + 4 + 25 + 4 + 18 + 4 + 24 + 4 + 30 + 4 + 30 + 4
compose_collection :: proc(
	r: ^Runtime,
	c: ^Page_Composition,
	stamp: base.Frame_Stamp,
) -> (
	collections.Candidate,
	[]layout.Node,
	bool,
) {
	n, selected := active_collection(r); if !selected || n.model == nil {return {}, nil, false}
	m := n.model
	for value, i in m.order[:m.count] {
		id := fmt.bprintf(n.ids[value - 1][:], "item-%05d", value)
		n.items[i] = {id, id, true, true, ""}
	}
	selected_id := ""; if m.selected != 0 {selected_id = fmt.bprintf(n.ids[m.selected - 1][:], "item-%05d", m.selected)}
	d := collections.Collection_Description {
		id            = "collection",
		scroll_id     = "collections/viewport",
		content_id    = "collections/content",
		items         = n.items[:m.count],
		selected_id   = selected_id,
		data_revision = m.revision,
		reset_epoch   = m.reset_epoch,
		height        = 32,
		gap           = 4,
		card_width    = 132,
		overscan_rows = 1,
	}
	if m.mode == .Grid {d.mode = .Grid}
	w := max(0, min(1000, r.drawable.w / r.model.scale - 12))
	top := f64(COLLECTION_TOP)
	if r.page == .Diagnostics_Performance {
		w = max(0, math.floor(min(650, r.drawable.w / r.model.scale * .55)) - 12)
		top += 24 + 4 + 30 + 4 + 48 + 4
	}
	offset := f64(
		0,
	); if len(n.state.frame.collections) != 0 {offset = n.state.frame.collections[0].offset}
	candidate, e := collections.prepare(
		&n.state,
		stamp,
		d,
		{x = 6, y = top, w = w, h = min(224, max(0, r.drawable.h / r.model.scale - top))},
		offset,
		focus_id = r.interaction.focus_id,
		a = r.allocator,
	)
	if e.code !=
	   .None {fmt.eprintf("collection prepare=%v id=%s\n", e.code, e.id); return {}, nil, false}
	materialized, me := collections.materialize(&candidate.frame, r.allocator)
	if me.code != .None {collections.destroy_candidate(&candidate); return {}, nil, false}
	if !sections.compose_collection_page(
		{r.model^, r.allocator},
		c,
		&candidate.frame,
		materialized,
		w,
	) {collections.destroy_nodes(materialized, r.allocator); collections.destroy_candidate(&candidate); return {}, nil, false}
	return candidate, materialized, true
}
accept_collection :: proc(
	r: ^Runtime,
	stamp: base.Frame_Stamp,
	result: collections.Result,
) -> bool {
	_, ok := active_collection(r); if !ok {return false}
	if e, has := result.event.?; has {
		if !consume(r, stamp, e.sequence) {return false}
		return apply_collection(r, collection_model.Action{kind = .Select, id = e.item_id})
	}
	return true
}
apply_collection :: proc(r: ^Runtime, action: collection_model.Action) -> bool {
	n, ok := active_collection(r); if !ok || n.model == nil {return false}
	if r.model.revision == max(u64) || r.model.effects == max(u64) {return false}
	result := collection_model.reduce(n.model, action)
	if !result.ok || !result.changed {return false}
	r.model.revision += 1; r.model.effects += 1; base.invalidate(&r.publication); return true
}
collection_route :: proc(r: ^Runtime, action: interaction.Action) -> (interaction.Code, bool) {
	n, ok := active_collection(r); if !ok {return .Not_Found, false}
	id := action.id; if id == "" {id = r.interaction.focus_id}
	if action.kind != .Activate {return .Not_Found, false}
	item := ""
	switch id {case "collections/start":
		item = "item-00001"; case "collections/middle":
		item = "item-05000"; case "collections/end":
		item = "item-10000"}
	if item !=
	   "" {result := collections.dispatch(&n.state, &r.interaction, {kind = .Scroll_To_Item, collection_id = "collection", item_id = item, source = action.source}); return result.dispatch.code, true}
	collection, item_id, valid := collections.decode_item_node_id(id)
	if valid {
		result := collections.dispatch(
			&n.state,
			&r.interaction,
			{
				kind = .Activate,
				collection_id = collection,
				item_id = item_id,
				source = action.source,
			},
		)
		accept_collection(r, reader_stamp(&r.live), result); return result.dispatch.code, true
	}
	return .Not_Found, false
}
