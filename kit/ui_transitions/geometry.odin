package ui_transitions

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:mem"
import "core:strings"

geometry_view :: proc(f: ^Frame) -> base.Geometry_View {return {f.stamp, f.entries}}
bind_geometry :: proc(
	c: ^Candidate,
	g: ^layout.Frame,
	i: ^interaction.Frame,
	protected_roots: []string = nil,
	progress_ids: []string = nil,
) -> Error {
	f := &c.frame
	if f.storage == nil ||
	   f.bound ||
	   f.stamp != g.stamp ||
	   f.stamp != i.stamp ||
	   g.ui_scale <= 0 ||
	   !base.finite(g.ui_scale) {return {code = .Stale, stage = .Bind}}
	for id in f.bindings {
		if _, found := layout.find(g, id); !found {return {.Binding, id, .Foreground, .Bind}}
		for root in protected_roots {if root == id {return {.Binding, id, .Foreground, .Bind}}}
	}
	for tr in f.tracks {if tr.property == .Progress {found := false; for id in progress_ids {if id == tr.node_id {found = true}}; if !found {return {.Binding, tr.node_id, .Progress, .Bind}}}}
	a := mem.rollback_stack_allocator(f.storage)
	entries, ae := make(
		[]base.Geometry_Entry,
		len(g.nodes),
		a,
	); if ae != nil {return {code = .Allocation, stage = .Bind}}
	ready, re := make(
		[]bool,
		len(g.nodes),
		a,
	); if re != nil {return {code = .Allocation, stage = .Bind}}
	clips, ce := make(
		[]base.Rect,
		len(g.nodes),
		a,
	); if ce != nil {return {code = .Allocation, stage = .Bind}}
	for n, index in g.nodes {entries[index].id, ae = strings.clone(n.description.id, a); if ae != nil {return {code = .Allocation, stage = .Bind}}}
	f.entries, f.drawable, f.ui_scale = entries, g.drawable, g.ui_scale
	input := Geometry_Input{f, g, ready, clips}
	for n, index in g.nodes {if !compute_geometry(&input, index, 0) {f.entries = nil; return {.Geometry, n.description.id, .Scale, .Bind}}}
	f.bound = true
	return {}
}
project_nodes :: proc(
	c: ^Candidate,
	nodes: []layout.Node,
	a := context.allocator,
) -> (
	[]layout.Node,
	Error,
) {
	result, ae := make(
		[]layout.Node,
		len(nodes),
		a,
	); if ae != nil {return nil, {code = .Allocation, stage = .Prepare}}
	complete := false; defer {if !complete {destroy_nodes(result, a)}}
	for n, index in nodes {
		copy, ce := layout.try_clone_description(
			n,
			a,
		); if ce != nil {return nil, {code = .Allocation, stage = .Prepare}}
		result[index] = copy
		for presence in c.frame.presences {if presence.phase == .Hidden && within_nodes(nodes, n.id, presence.node_id) {result[index].visible = false}}
	}
	complete = true
	return result, {}
}
destroy_nodes :: proc(nodes: []layout.Node, a := context.allocator) {
	for n in nodes {delete(n.id, a); delete(n.parent, a); if l, has := n.layout.?; has {delete(l.rows, a); delete(l.columns, a); delete(l.metric_id, a)}}
	delete(nodes, a)
}
within_nodes :: proc(nodes: []layout.Node, id, root: string) -> bool {
	id := id
	for depth := 0; id != "" && depth <= len(nodes); depth += 1 {
		if id == root {return true}
		found := false
		for n in nodes {if n.id == id {id = n.parent; found = true; break}}
		if !found {return false}
	}
	return false
}
Geometry_Input :: struct {
	f:     ^Frame,
	g:     ^layout.Frame,
	ready: []bool,
	clips: []base.Rect,
}
compute_geometry :: proc(input: ^Geometry_Input, index, depth: int) -> bool {
	f, g := input.f, input.g
	if index < 0 || index >= len(g.nodes) || depth > len(g.nodes) {return false}
	if input.ready[index] {return true}
	n := g.nodes[index]
	v := base.Frozen_Geometry {
		scale   = 1,
		opacity = 1,
	}
	inherited := base.Rect{0, 0, g.drawable.w / g.ui_scale, g.drawable.h / g.ui_scale}
	gate := n.enabled && n.visible
	if n.description.parent != "" {
		parent := -1; for p, j in g.nodes {if p.description.id == n.description.parent {parent = j; break}}
		if !compute_geometry(input, parent, depth + 1) {return false}
		pg := f.entries[parent].geometry
		v.scale, v.offset, v.opacity = pg.scale, pg.offset, pg.opacity
		gate = gate && f.entries[parent].input_enabled
		l, has := g.nodes[parent].description.layout.?
		inherited = pg.content_clip
		if has && l.overflow == .Visible {inherited = input.clips[parent]}
	}
	input.clips[index] = inherited
	s := f64(1); offset := [2]f64{}
	for tr in f.tracks {if tr.node_id == n.description.id {#partial switch tr.property {
			case .Scale:
				s = tr.current.(f64)
			case .Offset:
				offset = tr.current.([2]f64)
			case .Opacity:
				v.opacity *= tr.current.(f64)
			case:
			}}}
	for presence in f.presences {if presence.node_id == n.description.id && (presence.phase == .Exiting || presence.phase == .Hidden) {gate = false}}
	center := [2]f64{n.bounds.x + n.bounds.w / 2, n.bounds.y + n.bounds.h / 2}
	v.offset[0] +=
		v.scale *
		(center[0] * (1 - s) +
				offset[0]); v.offset[1] += v.scale * (center[1] * (1 - s) + offset[1]); v.scale *= s
	v.bounds, v.content = base.forward_rect(v, n.bounds), base.forward_rect(v, n.content)
	v.clip, v.content_clip =
		base.intersection(inherited, v.bounds), base.intersection(inherited, v.content)
	if !base.finite_nonnegative(v.scale) ||
	   !base.finite(v.opacity) ||
	   !base.finite(v.offset[0]) ||
	   !base.finite(v.offset[1]) {return false}
	for r in ([4]base.Rect{v.bounds, v.content, v.clip, v.content_clip}) {for edge in ([6]f64{r.x, r.y, r.w, r.h, r.x + r.w, r.y + r.h}) {if !base.finite(edge) || !base.finite(edge * g.ui_scale) || abs(edge * g.ui_scale) > f64(max(i32)) {return false}}}
	f.entries[index].geometry, f.entries[index].input_enabled =
		v, gate && v.scale > 0 && v.opacity > 0
	input.ready[index] = true
	return true
}
