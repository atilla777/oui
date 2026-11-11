package ui_collections

import base "../ui_base"
import "core:mem"

State :: struct {
	pending:     Action,
	has_pending: bool,
	frame:       Frame,
	identity:    ^base.Lifetime,
	version:     u64,
	allocator:   mem.Allocator,
}
Candidate :: struct {
	has_focus: bool,
	frame:     Frame,
	identity:  ^base.Lifetime,
	version:   u64,
}
create :: proc(a := context.allocator) -> State {return {allocator = a}}
destroy :: proc(s: ^State) {
	delete(s.pending.item_id, s.allocator)
	destroy_frame(&s.frame)
	if s.identity != nil {s.identity.alive = false; base.release({lifetime = s.identity})}
	s^ = {}
}
destroy_candidate :: proc(c: ^Candidate) {destroy_frame(&c.frame); base.release(
		{lifetime = c.identity},
	)
	c^ = {}}
prepare :: proc(
	s: ^State,
	stamp: base.Frame_Stamp,
	d: Collection_Description,
	viewport: Rect,
	offset: f64,
	a := context.allocator,
	focus_id: string = "",
	restore_focus: string = "",
) -> (
	Candidate,
	Update_Error,
) {
	if s.version == max(u64) {return {}, {.Exhausted, d.id}}
	if stamp.lifetime == nil ||
	   !stamp.lifetime.alive ||
	   stamp.attempt == 0 ||
	   (s.frame.stamp.lifetime != nil &&
			   s.frame.stamp.lifetime != stamp.lifetime) {return {}, {.Stale, d.id}}
	f, e := prepare_collection(d, viewport, offset, a, &s.frame)
	if e.code != .None {return {}, e}
	complete := false; defer {if !complete {destroy_frame(&f)}}
	next := &f.collections[0]
	old, known := inspect_collection(&s.frame, d.id)
	reset := !known || old.description.reset_epoch != d.reset_epoch
	active_collection, active_item, active := decode_item_node_id(focus_id)
	active = active && active_collection == d.id
	has_focus := reset && active
	focus := ""; desired := offset
	if reset {desired = 0} else {
		focus = old.focus_id
		if collection, item, belongs := decode_item_node_id(focus_id);
		   belongs && collection == d.id {focus = item}
		focus = retained(old, next, focus, true)
		anchor := retained(old, next, old.anchor_id)
		if anchor !=
		   "" {index := next.data.index[anchor]; desired = f64(next.data.ordinals[index] / next.columns) * (d.height + d.gap) + old.intra_offset + (offset - old.offset)}
	}
	if focus ==
	   "" {for index in next.data.visible {if next.data.items[index].enabled {focus = next.data.items[index].item_id; break}}}
	if active && focus != active_item {has_focus = true}
	if s.has_pending && !reset {
		pending := s.pending
		if pending.kind ==
		   .Scroll_By {desired += pending.delta_y} else if index, found := next.data.index[pending.item_id]; found && next.data.items[index].visible {
			if pending.kind == .Focus &&
			   next.data.items[index].enabled {focus = next.data.items[index].item_id; has_focus = true}
			preview := next^; preview.offset = clamp(desired, 0, max(0, preview.extent - viewport.h)); desired = reveal_offset(&preview, next.data.items[index].item_id)
		} else if pending.kind == .Scroll_To_Item {f.target_removed = true}
	}
	if !base.finite(desired) {return {}, {.Invalid_Size, d.id}}
	if !reset && old.description.mode != d.mode {
		if collection, _, belongs := decode_item_node_id(focus_id);
		   belongs &&
		   collection ==
			   d.id {preview := next^; preview.offset = clamp(desired, 0, max(0, preview.extent - viewport.h)); desired = reveal_offset(&preview, focus); has_focus = true}
	}
	if collection, item, belongs := decode_item_node_id(restore_focus);
	   belongs && collection == d.id {
		if index, found := next.data.index[item];
		   found &&
		   next.data.items[index].visible &&
		   next.data.items[index].enabled {focus = next.data.items[index].item_id; preview := next^; preview.offset = clamp(desired, 0, max(0, preview.extent - viewport.h)); desired = reveal_offset(&preview, focus); has_focus = true}
	}
	desired = clamp(desired, 0, max(0, next.extent - viewport.h))
	if desired != next.offset {
		copied := next.metadata_items_copied
		removed := f.target_removed
		window, we := prepare_collection(d, viewport, desired, a, &f)
		if we.code != .None {return {}, we}
		destroy_frame(
			&f,
		); f = window; f.target_removed = removed; next = &f.collections[0]; next.metadata_items_copied = copied
	}
	next.focus_id = focus
	if focus !=
	   "" {id, ae := item_node_id(d.id, focus, a); if ae != nil {return {}, {.Allocation, d.id}}; next.focus_node_id = id}
	if next.visible_count > 0 {
		row := min(next.rows - 1, int(next.offset / (d.height + d.gap)))
		next.anchor_id = next.data.items[next.data.visible[row * next.columns]].item_id
		next.intra_offset = next.offset - f64(row) * (d.height + d.gap)
	}
	if s.identity == nil {
		identity, ae := new(
			base.Lifetime,
			s.allocator,
		); if ae != nil {return {}, {.Allocation, d.id}}
		identity^ = {
			references = 1,
			alive      = true,
			allocator  = s.allocator,
		}; s.identity = identity
	}
	if !base.retain(stamp) {return {}, {.Allocation, d.id}}
	f.stamp = stamp
	if !base.retain({lifetime = s.identity}) {return {}, {.Allocation, d.id}}
	complete = true
	return {frame = f, identity = s.identity, version = s.version, has_focus = has_focus}, {}
}
validate_candidate :: proc(p: ^base.Publication, s: ^State, c: ^Candidate) -> bool {
	return(
		s.identity != nil &&
		s.identity.alive &&
		c.identity == s.identity &&
		c.version == s.version &&
		c.frame.bound &&
		base.validate(p, c.frame.stamp) == .None \
	)
}
// The concrete publisher passes candidate focus to interaction.commit, then
// swaps this family in the same validated commit section.
commit :: proc(s: ^State, c: ^Candidate) {
	old := s.frame
	s.frame = c.frame
	c.frame = {}
	delete(s.pending.item_id, s.allocator); s.pending = {}; s.has_pending = false
	s.version += 1
	destroy_frame(&old)
	destroy_candidate(c)}
