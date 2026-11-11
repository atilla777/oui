package ui_collections

import interaction "../ui_interaction"
import scroll "../ui_scroll"

// One logical collection stop in the caller-selected ordinary/layer paint order.
// IDs borrow immutable frames synchronously; no focus manager or stop list owner.
tab_target :: proc(
	f: ^Frame,
	i: ^interaction.Frame,
	focus: string,
	backwards: bool,
	order: []string = nil,
) -> (
	string,
	Code,
) {
	if !f.bound || f.stamp != i.stamp || len(f.collections) != 1 {return "", .Not_Ready}
	cs := f.collections[0]
	collection, _, active := decode_item_node_id(
		focus,
	); active = active && collection == cs.description.id
	count := len(i.targets); if order != nil {count = len(order)}
	total, start := 0, -1
	for index in 0 ..< count {
		id := ordered_id(i, order, index)
		stop := stop_id(f, i, id); if stop == "" {continue}
		if (active && id == cs.description.scroll_id) || stop == focus {start = total}
		total += 1
	}
	if total == 0 {return "", .Not_Found}
	if backwards && start < 0 {start = 0}
	chosen := (start + 1) % total; if backwards {chosen = (start - 1 + total) % total}
	n := 0
	for index in 0 ..< count {
		stop := stop_id(f, i, ordered_id(i, order, index)); if stop == "" {continue}
		if n == chosen {return stop, .Applied}; n += 1
	}
	return "", .Not_Found
}
ordered_id :: proc(i: ^interaction.Frame, order: []string, index: int) -> string {if order !=
	   nil {return order[index]}
	return i.targets[index].description.id}
stop_id :: proc(f: ^Frame, i: ^interaction.Frame, id: string) -> string {
	cs := f.collections[0]
	if id ==
	   cs.description.scroll_id {if f.owner_gate == .Applied {return cs.focus_node_id}; return ""}
	if collection, _, valid := decode_item_node_id(id);
	   valid && collection == cs.description.id {return ""}
	n, found := interaction.find(
		i,
		id,
	); if found && n.availability == .Applied {return n.description.id}
	return ""
}
dispatch_scroll :: proc(s: ^State, ctx: ^interaction.Context, action: scroll.Action) -> Result {
	if code := interaction.guard_common(ctx, action.source);
	   code != .Applied {return {dispatch = {code = code}}}
	if len(s.frame.collections) != 1 {return {dispatch = {code = .Not_Found}}}
	cs := s.frame.collections[0]
	if action.kind == .Scroll_By &&
	   action.id ==
		   cs.description.scroll_id {return dispatch(s, ctx, {kind = .Scroll_By, collection_id = cs.description.id, source = action.source, delta_y = action.delta_y})}
	collection, item, valid := decode_item_node_id(action.id)
	if !valid {return {dispatch = {code = .Not_Found}}}
	kind :=
		Action_Kind.Focus; if action.kind == .Reveal_Item {kind = .Scroll_To_Item} else if action.kind != .Focus {return {dispatch = {code = .Invalid_Action}}}
	return dispatch(
		s,
		ctx,
		{kind = kind, collection_id = collection, item_id = item, source = action.source},
	)
}
