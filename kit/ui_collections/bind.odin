package ui_collections

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import scroll "../ui_scroll"
import "core:mem"

project_layout :: proc(
	c: ^Candidate,
	source: ^layout.Frame,
	a := context.allocator,
) -> (
	layout.Frame,
	Update_Error,
) {
	if c.frame.stamp != source.stamp || len(c.frame.collections) != 1 {return {}, {.Stale, ""}}
	g, copied := layout.try_copy_frame(source, a); if !copied {return {}, {.Allocation, ""}}
	s := c.frame.collections[0]
	if e := scroll.project_region(
		&g,
		{s.description.scroll_id, s.description.content_id},
		s.offset,
	); e.code != .None {layout.destroy_frame(&g); return {}, {.Binding, e.id}}
	return g, {}
}
bind_candidate :: proc(
	c: ^Candidate,
	g: ^layout.Frame,
	i: ^interaction.Candidate,
	view: base.Geometry_View = {},
) -> Update_Error {
	f := &c.frame
	if f.bound ||
	   f.stamp != g.stamp ||
	   f.stamp != i.stamp ||
	   len(f.collections) != 1 {return {.Stale, ""}}
	s := &f.collections[0]
	vp, vok := layout.find(
		g,
		s.description.scroll_id,
	); content, cok := layout.find(g, s.description.content_id)
	if !vok ||
	   !cok ||
	   content.description.parent != s.description.scroll_id ||
	   content.description.role != .Column ||
	   vp.clip != s.viewport {return {.Binding, ""}}
	owner, owner_found := interaction.find(
		i,
		s.description.scroll_id,
	); if !owner_found {return {.Binding, vp.description.id}}
	f.owner_gate = owner.availability
	if f.owner_gate == .Invalid_Action && owner.description.role == "" {f.owner_gate = .Applied}
	if !vp.enabled {f.owner_gate = .Disabled}; if !vp.visible || vp.clip.w <= 0 || vp.clip.h <= 0 {f.owner_gate = .Not_Visible}
	for v in f.nodes {
		n, found := layout.find(g, v.description.id); if !found {return {.Binding, ""}}
		target, has_target := interaction.find(i, v.description.id)
		if !has_target ||
		   (target.activation_owner != "" &&
				   target.activation_owner != "collections") {return {.Binding, n.description.id}}
		if _, valid := selected_geometry(g, n, view); !valid {return {.Binding, n.description.id}}
	}
	for &v in f.nodes {
		n, _ := layout.find(g, v.description.id)
		if code := interaction.bind_activation_owner(i, v.description.id, "collections");
		   code !=
		   .Applied {if code == .Allocation {return {.Allocation, n.description.id}}; return {.Binding, n.description.id}}
		description, ae := layout.try_clone_description(
			n.description,
			f.allocator,
		); if ae != nil {return {.Allocation, n.description.id}}
		destroy_description(v.description, f.allocator); v.description = description
		v.bounds, v.content, v.clip, v.paint_clip = n.bounds, n.content, n.clip, n.paint_clip
		v.geometry, _ = selected_geometry(g, n, view)
		target, _ := interaction.find(i, v.description.id); v.availability = target.availability
		if v.geometry.scale == 0 ||
		   v.geometry.opacity == 0 ||
		   v.geometry.clip.w <= 0 ||
		   v.geometry.clip.h <= 0 ||
		   !selected_gate(view, v.description.id) {v.availability = .Not_Visible}
		target.bounds, target.clip, target.availability =
			v.geometry.bounds, v.geometry.clip, v.availability
	}
	f.bound = true
	if c.has_focus {target, found := interaction.find(i, s.focus_node_id); if !found || target.availability != .Applied || f.owner_gate != .Applied {c.has_focus = false}}
	return {}
}
selected_gate :: proc(view: base.Geometry_View, id: string) -> bool {
	if view.entries == nil && view.stamp.lifetime == nil {return true}
	for entry in view.entries {if entry.id == id {return entry.input_enabled}}
	return false
}
selected_geometry :: proc(
	g: ^layout.Frame,
	n: ^layout.Resolved_Node,
	view: base.Geometry_View,
) -> (
	base.Frozen_Geometry,
	bool,
) {
	if view.entries == nil &&
	   view.stamp.lifetime ==
		   nil {return {scale = 1, opacity = 1, bounds = n.bounds, content = n.content, clip = n.paint_clip, content_clip = n.clip}, true}
	if view.stamp != g.stamp {return {}, false}
	result: base.Frozen_Geometry; found := false
	for e in view.entries {if e.id == n.description.id {
			if found ||
			   !base.finite_nonnegative(e.geometry.scale) ||
			   !base.finite_nonnegative(e.geometry.opacity) ||
			   e.geometry.opacity > 1 ||
			   !base.finite(e.geometry.offset[0]) ||
			   !base.finite(e.geometry.offset[1]) {return {}, false}
			for r in ([4]base.Rect{e.geometry.bounds, e.geometry.content, e.geometry.clip, e.geometry.content_clip}) {if !base.finite(r.x) || !base.finite(r.y) || !base.finite_nonnegative(r.w) || !base.finite_nonnegative(r.h) || !base.finite(r.x + r.w) || !base.finite(r.y + r.h) {return {}, false}}
			result, found = e.geometry, true
		}}
	return result, found
}
destroy_description :: proc(n: layout.Node, a: mem.Allocator) {
	delete(n.id, a); delete(n.parent, a)
	if l, has := n.layout.?; has {delete(l.rows, a); delete(l.columns, a); delete(l.metric_id, a)}
}
