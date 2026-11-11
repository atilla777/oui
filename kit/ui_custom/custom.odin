package ui_custom

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:mem"
import "core:slice"
import "core:strings"

Constraints :: struct {
	x_min, y_min: f64,
	x_max, y_max: Maybe(f64),
}
Description :: struct {
	node_id, type_id, revision, semantic_name, hit_description: string,
	payload:                                                    []u8,
	validate:                                                   proc(payload: []u8) -> bool,
	measure:                                                    proc(
		payload: []u8,
		constraints: Constraints,
	) -> (
		base.Extent,
		bool,
	),
	hit:                                                        proc(
		payload: []u8,
		local_point: [2]f64,
		arranged_extent: base.Extent,
	) -> bool,
}
View :: struct {
	using description: Description,
	layout_bounds:     base.Rect,
	geometry:          base.Frozen_Geometry,
	availability:      interaction.Code,
}
Frame :: struct {
	drawable:  base.Extent,
	ui_scale:  f64,
	views:     []View,
	stamp:     base.Frame_Stamp,
	allocator: mem.Allocator,
	storage:   ^mem.Rollback_Stack,
}
Candidate :: Frame
State :: struct {
	frame: Frame,
}
Metrics :: struct {
	descriptions: []Description,
	constraints:  Constraints,
}
measure :: proc(id: string, user: rawptr) -> (base.Extent, bool) {
	if user == nil {return {}, false}
	m := cast(^Metrics)user
	for d in m.descriptions {if d.node_id == id {
			if d.validate == nil || d.measure == nil || !d.validate(d.payload) {return {}, false}
			s, ok := d.measure(d.payload, m.constraints)
			return s, ok && base.finite_nonnegative(s.w) && base.finite_nonnegative(s.h)
		}}
	return {}, false
}
valid_geometry :: proc(g: base.Frozen_Geometry) -> bool {
	if !base.finite_nonnegative(g.scale) ||
	   !base.finite(g.opacity) ||
	   g.opacity < 0 ||
	   g.opacity > 1 ||
	   !base.finite(g.offset[0]) ||
	   !base.finite(g.offset[1]) {return false}
	for r in ([4]base.Rect{g.bounds, g.content, g.clip, g.content_clip}) {
		if !base.finite(r.x) ||
		   !base.finite(r.y) ||
		   !base.finite_nonnegative(r.w) ||
		   !base.finite_nonnegative(r.h) ||
		   !base.finite(r.x + r.w) ||
		   !base.finite(r.y + r.h) {return false}
	}
	return true
}
sample_candidate :: proc(c: ^Candidate, view: base.Geometry_View) -> bool {
	if view.stamp != c.stamp {return false}
	for v in c.views {
		found := false
		for entry, index in view.entries {if entry.id == v.node_id {
				for prior in view.entries[:index] {if prior.id == entry.id {return false}}
				if !valid_geometry(entry.geometry) {return false}
				found = true
			}}
		if !found {return false}
	}
	for &v in c.views {for entry in view.entries {if entry.id == v.node_id {
				v.geometry = entry.geometry
				if !entry.input_enabled ||
				   entry.geometry.opacity == 0 ||
				   entry.geometry.scale == 0 {v.availability = .Not_Visible}
			}}}
	return true
}
try_copy_frame :: proc(source: ^Frame, a := context.allocator) -> (Frame, bool) {
	f, e := new_frame(source.stamp, a); if e != .None {return {}, false}
	f.drawable, f.ui_scale = source.drawable, source.ui_scale
	complete := false; defer {if !complete {destroy_frame(&f)}}
	ca := mem.rollback_stack_allocator(f.storage)
	ae: mem.Allocator_Error
	f.views, ae = make([]View, len(source.views), ca); if ae != nil {return {}, false}
	for v, index in source.views {
		f.views[index] = v
		f.views[index].description, ae = clone_description(
			v.description,
			ca,
		); if ae != nil {return {}, false}
	}
	complete = true
	return f, true
}
create :: proc() -> State {return {}}
destroy :: proc(s: ^State) {destroy_frame(&s.frame)}
validate_candidate :: proc(p: ^base.Publication, c: ^Candidate) -> bool {return(
		c.storage != nil &&
		base.validate(p, c.stamp) == .None \
	)}
// Ownership swap only. The typed publisher validates every selected owner first.
commit :: proc(s: ^State, c: ^Candidate) {old := s.frame; s.frame = c^; c^ = {}; destroy_frame(
		&old,
	)}
Error_Code :: enum {
	None,
	Descriptor,
	Validate,
	Measure,
	Binding,
	Allocation,
	Stale,
}
Error :: struct {
	code:    Error_Code,
	node_id: string,
}
prepare :: proc(
	g: ^layout.Frame,
	i: ^interaction.Frame,
	descriptions: []Description,
	a := context.allocator,
) -> (
	Candidate,
	Error,
) {
	if g.stamp != i.stamp {return {}, {.Stale, ""}}
	for d, index in descriptions {
		n, found := layout.find(g, d.node_id)
		if !found ||
		   d.type_id == "" ||
		   d.revision == "" ||
		   d.validate == nil ||
		   d.measure == nil {return {}, {.Descriptor, d.node_id}}
		if n.description.role != .Content &&
		   n.description.role != .Box {return {}, {.Descriptor, d.node_id}}
		if l, has := n.description.layout.?;
		   has && l.metric_id != "" {return {}, {.Descriptor, d.node_id}}
		for prior in descriptions[:index] {if prior.node_id == d.node_id {return {}, {.Descriptor, d.node_id}}}
		target, interactive := interaction.find(i, d.node_id)
		if d.hit != nil {
			if !interactive ||
			   target.activation_owner != "custom" {return {}, {.Binding, d.node_id}}
		} else if interactive && target.availability == .Applied {return {}, {.Binding, d.node_id}}
		if !d.validate(d.payload) {return {}, {.Validate, d.node_id}}
	}
	f, fe := new_frame(g.stamp, a); if fe != .None {return {}, {fe, ""}}
	f.drawable, f.ui_scale = g.drawable, g.ui_scale
	complete := false; defer {if !complete {destroy_frame(&f)}}
	ca := mem.rollback_stack_allocator(f.storage)
	ae: mem.Allocator_Error
	f.views, ae = make([]View, len(descriptions), ca); if ae != nil {return {}, {.Allocation, ""}}
	for d, index in descriptions {
		n, _ := layout.find(g, d.node_id)
		v := &f.views[index]
		v.layout_bounds = n.bounds
		v.geometry = {
			scale        = 1,
			opacity      = 1,
			bounds       = n.bounds,
			content      = n.content,
			clip         = n.paint_clip,
			content_clip = n.clip,
		}
		v.availability = .Invalid_Action
		if target, found := interaction.find(i, d.node_id);
		   found {v.availability = target.availability}
		v.description, ae = clone_description(
			d,
			ca,
		); if ae != nil {return {}, {.Allocation, d.node_id}}
	}
	complete = true
	return f, {}
}
new_frame :: proc(stamp: base.Frame_Stamp, a: mem.Allocator) -> (Frame, Error_Code) {
	storage, ae := new(mem.Rollback_Stack, a); if ae != nil {return {}, .Allocation}
	storage.block_allocator = a
	if mem.rollback_stack_init_dynamic(storage, 4096, a) !=
	   nil {free(storage, a); return {}, .Allocation}
	if !base.retain(
		stamp,
	) {mem.rollback_stack_destroy(storage); free(storage, a); return {}, .Stale}
	return {storage = storage, allocator = a, stamp = stamp}, .None
}
clone_description :: proc(
	d: Description,
	a: mem.Allocator,
) -> (
	r: Description,
	e: mem.Allocator_Error,
) {
	r = d
	r.node_id = strings.clone(d.node_id, a) or_return
	r.type_id = strings.clone(d.type_id, a) or_return
	r.revision = strings.clone(d.revision, a) or_return
	r.semantic_name = strings.clone(d.semantic_name, a) or_return
	r.hit_description = strings.clone(d.hit_description, a) or_return
	r.payload = slice.clone(d.payload, a) or_return
	return r, nil
}
destroy_frame :: proc(f: ^Frame) {
	base.release(f.stamp)
	if f.storage != nil {mem.rollback_stack_destroy(f.storage); free(f.storage, f.allocator)}
	f^ = {}
}
destroy_candidate :: destroy_frame
hit :: proc(f: ^Frame, id: string, point: [2]f64) -> bool {
	for v in f.views {if v.node_id == id {
			if v.availability != .Applied ||
			   v.hit == nil ||
			   v.geometry.opacity <= 0 ||
			   !base.contains(v.geometry.clip, point[0], point[1]) {return false}
			p, valid := base.inverse_point(
				v.geometry,
				point,
			); if !valid || !base.contains(v.layout_bounds, p[0], p[1]) {return false}
			return v.hit(
				v.payload,
				{p[0] - v.layout_bounds.x, p[1] - v.layout_bounds.y},
				{v.layout_bounds.w, v.layout_bounds.h},
			)
		}}
	return false
}
// Ordinary targets retain rectangular defaults. Unknown IDs do not turn on a
// family; the concrete caller selected this predicate and keeps f alive.
hit_predicate :: proc(id: string, point: [2]f64, user: rawptr) -> bool {
	f := cast(^Frame)user; if f == nil {return false}
	for v in f.views {if v.node_id == id {return hit(f, id, point)}}
	return true
}
