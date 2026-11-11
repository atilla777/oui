package ui_gestures
import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import scroll "../ui_scroll"
import "core:mem"
import "core:strings"

@(private)
prepare_into :: proc(
	c: ^Candidate,
	s: ^State,
	g: ^layout.Frame,
	i: ^interaction.Frame,
	sf: ^scroll.Frame,
	ds: []Description,
	revision: u64,
	scope: string,
	sample: base.Geometry_View,
) -> Error {
	if g.stamp != i.stamp ||
	   (sf != nil && sf.stamp != g.stamp) ||
	   (s.frame.stamp.lifetime != nil &&
			   s.frame.stamp.lifetime != g.stamp.lifetime) {return {code = .Stale}}
	if s.version == max(u64) {return {code = .Exhausted}}
	projected := sample.stamp.lifetime != nil || len(sample.entries) > 0
	if projected && sample.stamp != g.stamp {return {code = .Stale}}
	f := &c.frame; a := f.allocator
	if !base.retain(g.stamp) {return {code = .Allocation}}; f.stamp = g.stamp
	f.model_revision, f.ui_scale, f.drawable = revision, g.ui_scale, g.drawable
	ae: mem.Allocator_Error
	f.scope_id, ae = strings.clone(scope, a); if ae != nil {return {code = .Allocation}}
	f.gestures, ae = make([]View, len(ds), a); if ae != nil {return {code = .Allocation}}
	for d, index in ds {
		if d.id == "" ||
		   d.node_id == "" ||
		   d.kind < .Drag_Source ||
		   d.kind > .Pan_Scroll {return {.Invalid, d.id}}
		for prior in ds[:index] {if prior.id == d.id || prior.node_id == d.node_id {return {.Invalid, d.id}}}
		n, found := layout.find(g, d.node_id); target, has_target := interaction.find(i, d.node_id)
		if !found || !has_target {return {.Invalid, d.id}}
		if d.kind == .Drag_Source &&
		   (d.payload_id == "" ||
				   d.payload_type == "" ||
				   target.description.role == "") {return {.Invalid, d.id}}
		if d.kind ==
		   .Drop_Target {if len(d.accept_types) == 0 {return {.Invalid, d.id}}; for v, j in d.accept_types {if v == "" {return {.Invalid, d.id}}; for prior in d.accept_types[:j] {if v == prior {return {.Invalid, d.id}}}}}
		if d.kind == .Repeat_Scroll || d.kind == .Pan_Scroll {
			if sf == nil {return {.Invalid, d.id}}
			if _, ok := scroll.find(sf, d.scroll_id); !ok {return {.Invalid, d.id}}
			if d.kind == .Repeat_Scroll &&
			   (target.description.role == "" ||
					   !base.finite(d.step) ||
					   d.step == 0 ||
					   d.delay_ms <= 0 ||
					   d.interval_ms <= 0) {return {.Invalid, d.id}}
		}
		if d.kind != .Drop_Target {
			if code := interaction.bind_activation_owner(i, d.node_id, "gestures");
			   code != .Applied {
				if code == .Allocation {return {.Allocation, d.id}}
				return {.Invalid, d.id}
			}
		}
		v := &f.gestures[index]
		if d.kind == .Repeat_Scroll || d.kind == .Pan_Scroll {
			r, _ := scroll.find(sf, d.scroll_id)
			v.scroll_viewport, v.scroll_offset, v.max_offset = r.viewport, r.offset, r.max_offset
		}
		ok: bool; v.description, ok = copy_description(d, a); if !ok {return {code = .Allocation}}
		v.parent, ae = strings.clone(
			n.description.parent,
			a,
		); if ae != nil {return {code = .Allocation}}
		parent, count := n.description.parent, 0
		for parent !=
		    "" {pn, exists := layout.find(g, parent); if !exists || count > len(g.nodes) {return {.Invalid, d.id}}; count += 1; parent = pn.description.parent}
		v.ancestors, ae = make([]string, count, a); if ae != nil {return {code = .Allocation}}
		parent = n.description.parent
		for j in 0 ..< count {v.ancestors[j], ae = strings.clone(parent, a); if ae != nil {return {code = .Allocation}}; pn, _ := layout.find(g, parent); parent = pn.description.parent}
		v.availability = target.availability
		if v.availability == .Invalid_Action &&
		   target.description.role == "" {v.availability = .Applied}
		if d.scope_id != scope {v.availability = .Blocked_By_Modal}
		if v.availability == .Applied && (d.kind == .Repeat_Scroll || d.kind == .Pan_Scroll) {
			region, _ := scroll.find(sf, d.scroll_id)
			v.availability = region.availability
		}
		v.geometry = {
			scale        = 1,
			opacity      = 1,
			bounds       = n.bounds,
			content      = n.content,
			clip         = n.paint_clip,
			content_clip = n.clip,
		}
		if projected {
			matched := false
			for entry, j in sample.entries {if entry.id == d.node_id {
					for prior in sample.entries[:j] {if prior.id == entry.id {return {.Invalid, d.id}}}
					if !valid_geometry(entry.geometry) {return {.Invalid, d.id}}
					v.geometry, matched = entry.geometry, true
					if !entry.input_enabled ||
					   entry.geometry.opacity == 0 {v.availability = .Not_Visible}
				}}
			if !matched {return {.Invalid, d.id}}
		}
	}
	// Freeze the layout traversal order used by the old hit/navigation path,
	// independently of the caller's description enumeration.
	position := 0
	for node in g.nodes {for k in position ..< len(f.gestures) {if f.gestures[k].node_id == node.description.id {
				f.gestures[position], f.gestures[k] = f.gestures[k], f.gestures[position]
				position += 1; break
			}}}
	ok: bool; f.live, ok = copy_live(s.live, a); if !ok {return {code = .Allocation}}
	f.result = s.result
	if f.live.phase != .Idle {
		owner, found := find(f, f.live.owner.id)
		reason := Cancel_Reason.None
		if !found {reason = .Removed} else if owner.availability != .Applied {reason = .Unavailable} else if !compatible(owner.description, f.live.owner) {reason = .Mode_Changed}
		if reason != .None {
			f.live.phase, f.live.reason = .Idle, reason
			f.result = {
				code   = .Applied,
				cycle  = f.live.cycle,
				phase  = .Idle,
				reason = reason,
			}
			emit(&f.result, f.live, .Cancelled)
		} else if f.live.target_id != "" {
			target, exists := find(f, f.live.target_id)
			if !exists ||
			   target.availability !=
				   .Applied {delete(f.live.target_id, a); f.live.target_id, f.live.target_accepted = "", false} else {f.live.target_accepted = accepts(f, f.live.owner, target)}
		}
	}
	if f.live.phase != .Idle && f.live.owner.kind == .Pan_Scroll {
		before, had := find(&s.frame, f.live.owner.id)
		after, _ := find(f, f.live.owner.id)
		if !had ||
		   f.drawable != s.frame.drawable ||
		   f.ui_scale != s.frame.ui_scale ||
		   before.scroll_viewport != after.scroll_viewport ||
		   before.max_offset != after.max_offset ||
		   before.geometry.clip != after.geometry.clip {
			f.live.start, f.live.start_offset = f.live.current, after.scroll_offset
		}
	}
	rebind(&f.result, f.live)
	c.live, ok = copy_live(f.live, a); if !ok {return {code = .Allocation}}
	return {}
}
valid_geometry :: proc(g: base.Frozen_Geometry) -> bool {
	if !base.finite(g.scale) ||
	   g.scale <= 0 ||
	   !base.finite(g.opacity) ||
	   g.opacity < 0 ||
	   g.opacity > 1 ||
	   !base.finite(g.offset[0]) ||
	   !base.finite(g.offset[1]) {return false}
	for r in ([4]base.Rect{g.bounds, g.content, g.clip, g.content_clip}) {if !base.finite(r.x) || !base.finite(r.y) || !base.finite_nonnegative(r.w) || !base.finite_nonnegative(r.h) || !base.finite(r.x + r.w) || !base.finite(r.y + r.h) {return false}}
	return true
}
