package ui_collections

import interaction "../ui_interaction"
import scroll "../ui_scroll"

Direction :: enum {
	Up,
	Down,
	Left,
	Right,
}
retained :: proc(old, next: ^Collection_State, id: string, focus := false) -> string {
	if i, ok := next.data.index[id];
	   ok &&
	   next.data.items[i].visible &&
	   (!focus || next.data.items[i].enabled) {return next.data.items[i].item_id}
	if old == nil {return ""}
	start, exists := old.data.index[id]; if !exists {return ""}
	for i := start + 1;
	    i < len(old.data.items);
	    i += 1 {if j, ok := next.data.index[old.data.items[i].item_id]; ok && next.data.items[j].visible && (!focus || next.data.items[j].enabled) {return next.data.items[j].item_id}}
	for i := start - 1;
	    i >= 0;
	    i -= 1 {if j, ok := next.data.index[old.data.items[i].item_id]; ok && next.data.items[j].visible && (!focus || next.data.items[j].enabled) {return next.data.items[j].item_id}}
	return ""
}
reveal_offset :: proc(s: ^Collection_State, item: string) -> f64 {
	i, ok := s.data.index[item]; if !ok || s.data.ordinals[i] < 0 {return s.offset}
	top := f64(s.data.ordinals[i] / s.columns) * (s.description.height + s.description.gap)
	bottom := top + s.description.height; offset := s.offset
	if top < offset ||
	   s.description.height >
		   s.viewport.h {offset = top} else if bottom > offset + s.viewport.h {offset = bottom - s.viewport.h}
	return clamp(offset, 0, max(0, s.extent - s.viewport.h))
}
// Logical IDs are borrowed from the retained immutable metadata, not newly allocated.
move_item :: proc(f: ^Frame, collection, item: string, direction: Direction) -> (string, Code) {
	s, exists := inspect_collection(f, collection); if !exists {return "", .Not_Found}
	v, code := lookup_collection_item(f, collection, item); if code != .Applied {return "", code}
	if !v.item.visible {return "", .Not_Visible}
	if !v.item.enabled {return "", .Disabled}
	step := 0
	switch direction {
	case .Up:
		step = -s.columns
	case .Down:
		step = s.columns
	case .Left:
		if s.description.mode == .Grid {step = -1}
	case .Right:
		if s.description.mode == .Grid {step = 1}
	case:
		return "", .Invalid_Action
	}
	if step == 0 {return "", .Invalid_Action}
	for j := v.visible_ordinal + step; j >= 0 && j < s.visible_count; j += step {
		if (direction == .Left || direction == .Right) &&
		   j / s.columns != v.visible_ordinal / s.columns {break}
		candidate := s.data.items[s.data.visible[j]]
		if candidate.enabled {return candidate.item_id, .Applied}
	}
	return v.item.item_id, .Applied
}
reveal_action :: proc(
	f: ^Frame,
	collection, item: string,
	source: interaction.Source,
) -> (
	scroll.Action,
	Code,
) {
	s, exists := inspect_collection(f, collection); if !exists {return {}, .Not_Found}
	v, code := lookup_collection_item(f, collection, item); if code != .Applied {return {}, code}
	if !v.item.visible {return {}, .Not_Visible}
	return {
			kind = .Scroll_By,
			id = s.description.scroll_id,
			delta_y = reveal_offset(s, item) - s.offset,
			source = source,
		},
		.Applied
}
