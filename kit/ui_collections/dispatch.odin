package ui_collections

import base "../ui_base"
import interaction "../ui_interaction"
import "core:strings"

Action_Kind :: enum {
	Scroll_To_Item,
	Move_Direction,
	Focus,
	Activate,
	Scroll_By,
}
Action :: struct {
	kind:                   Action_Kind,
	collection_id, item_id: string,
	direction:              Direction,
	source:                 interaction.Source,
	delta_y:                f64,
}
Item_Event :: struct {
	collection_id, item_id: string,
	source:                 interaction.Source,
	sequence, frame_id:     u64,
}
Result :: struct {
	dispatch: interaction.Dispatch_Result,
	event:    Maybe(Item_Event),
}
dispatch :: proc(s: ^State, ctx: ^interaction.Context, action: Action) -> Result {
	if code := interaction.guard_common(ctx, action.source);
	   code != .Applied {return {dispatch = {code = code}}}
	if !s.frame.bound ||
	   s.frame.stamp != ctx.frame.stamp ||
	   len(s.frame.collections) != 1 {return {dispatch = {code = .Not_Ready}}}
	cs := &s.frame.collections[0]
	if s.frame.owner_gate != .Applied {return {dispatch = {code = s.frame.owner_gate}}}
	owner, exists := interaction.find(
		&ctx.frame,
		cs.description.scroll_id,
	); if !exists {return {dispatch = {code = .Not_Found}}}
	if owner.availability != .Applied &&
	   !(owner.availability == .Invalid_Action &&
			   owner.description.role == "") {return {dispatch = {code = owner.availability}}}
	if action.collection_id != cs.description.id {return {dispatch = {code = .Not_Found}}}
	if action.kind < .Scroll_To_Item ||
	   action.kind > .Scroll_By {return {dispatch = {code = .Invalid_Action}}}
	next := action
	view: Collection_Item_View
	if action.kind == .Scroll_By {
		if !base.finite(action.delta_y) ||
		   !base.finite(cs.offset + action.delta_y) {return {dispatch = {code = .Invalid_Action}}}
		next.item_id = ""
	} else {
		if action.kind == .Move_Direction {
			collection, item, valid := decode_item_node_id(ctx.focus_id)
			if !valid ||
			   collection != cs.description.id {return {dispatch = {code = .Invalid_Action}}}
			id, code := move_item(
				&s.frame,
				collection,
				item,
				action.direction,
			); if code != .Applied {return {dispatch = {code = code}}}
			next.item_id, next.kind = id, .Focus
		}
		code: Code; view, code = lookup_collection_item(&s.frame, cs.description.id, next.item_id)
		if code != .Applied {return {dispatch = {code = code}}}
		if !view.item.visible {return {dispatch = {code = .Not_Visible}}}
		if next.kind != .Scroll_To_Item &&
		   !view.item.enabled {return {dispatch = {code = .Disabled}}}
		if next.kind == .Activate {
			if !view.materialized || !view.in_viewport {return {dispatch = {code = .Not_Visible}}}
			node_id := s.frame.nodes[view.node_index.?].description.id
			r := interaction.dispatch_owned(
				ctx,
				{.Activate, node_id, action.source, false},
				"collections",
			)
			out := Result {
				dispatch = r,
			}
			if r.has_event {out.event = Item_Event{cs.description.id, view.item.item_id, action.source, r.event.sequence, ctx.frame.stamp.attempt}}
			return out
		}
	}
	if s.version == max(u64) {return {dispatch = {code = .Exhausted}}}
	item, ae := strings.clone(
		next.item_id,
		s.allocator,
	); if ae != nil {return {dispatch = {code = .Allocation}}}
	delete(
		s.pending.item_id,
		s.allocator,
	); s.pending = next; s.pending.item_id = item; s.pending.collection_id = ""; s.has_pending = true; s.version += 1
	keep_press :=
		next.kind == .Focus &&
		action.source == .Mouse &&
		view.materialized &&
		view.in_viewport &&
		ctx.pressed_id == s.frame.nodes[view.node_index.?].description.id
	if !keep_press {interaction.cancel_press(ctx)}
	base.invalidate(ctx.publication)
	return {dispatch = {code = .Applied}}
}
