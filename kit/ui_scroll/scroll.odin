package ui_scroll

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:mem"
import "core:strings"

Description :: struct {
	id, content_id: string,
}
Item :: struct {
	id:          string,
	top, height: f64,
	available:   bool,
}
Region :: struct {
	availability:                             interaction.Code,
	id, anchor_id:                            string,
	viewport:                                 base.Rect,
	extent, offset, max_offset, intra_offset: f64,
	items:                                    []Item,
}
Frame :: struct {
	regions:   []Region,
	stamp:     base.Frame_Stamp,
	allocator: mem.Allocator,
}
State :: struct {
	version:     u64,
	frame:       Frame,
	pending:     Action,
	has_pending: bool,
	allocator:   mem.Allocator,
}
Candidate :: struct {
	owner:        ^State,
	base_version: u64,
	has_focus:    bool,
	frame:        Frame,
	geometry:     layout.Frame,
	focus_id:     string,
}
Error_Code :: enum {
	None,
	Invalid_Scroll,
	Allocation,
	Stale,
	Exhausted,
}
Error :: struct {
	code: Error_Code,
	id:   string,
}
Action_Kind :: enum {
	Scroll_By,
	Move_Item,
	Reveal_Item,
	Focus,
}
Action :: struct {
	kind:      Action_Kind,
	id:        string,
	source:    interaction.Source,
	delta_y:   f64,
	backwards: bool,
}
create :: proc(a: mem.Allocator) -> State {return {allocator = a}}
destroy_frame :: proc(f: ^Frame) {
	a := f.allocator
	for r in f.regions {delete(r.id, a); delete(r.anchor_id, a); for item in r.items {delete(item.id, a)}; delete(r.items, a)}
	delete(f.regions, a); base.release(f.stamp); f^ = {}
}
destroy :: proc(s: ^State) {destroy_frame(&s.frame); delete(s.pending.id, s.allocator); s^ = {}}
destroy_candidate :: proc(c: ^Candidate) {destroy_frame(&c.frame); layout.destroy_frame(
		&c.geometry,
	)
	c^ = {}}
prepare :: proc(
	s: ^State,
	g: ^layout.Frame,
	i: ^interaction.Frame,
	descriptions: []Description,
	a: mem.Allocator,
	focus_id: string = "",
) -> (
	Candidate,
	Error,
) {
	if g.stamp != i.stamp {return {}, {code = .Stale}}
	if s.frame.stamp.lifetime != nil &&
	   s.frame.stamp.lifetime != g.stamp.lifetime {return {}, {code = .Stale}}
	if s.version == max(u64) {return {}, {code = .Exhausted}}
	for d, k in descriptions {
		v, vok := layout.find(g, d.id); content, cok := layout.find(g, d.content_id)
		if !vok ||
		   !cok ||
		   content.description.parent != d.id ||
		   content.description.role != .Column {return {}, {.Invalid_Scroll, d.id}}
		cl, has := content.description.layout.?
		if !has ||
		   cl.y.mode != .Content ||
		   cl.shrink != 0 ||
		   cl.grow != 0 {return {}, {.Invalid_Scroll, d.content_id}}
		children := 0
		for n in g.nodes {
			if n.description.parent == d.id {children += 1}
			if within(g, n.description.id, d.content_id) {
				l, ok := n.description.layout.?
				if !ok ||
				   l.y.mode == .Fill ||
				   l.y.mode == .Percent {return {}, {.Invalid_Scroll, n.description.id}}
			}
		}
		if children != 1 {return {}, {.Invalid_Scroll, d.id}}
		for prior in descriptions[:k] {if prior.id == d.id || prior.content_id == d.content_id {return {}, {.Invalid_Scroll, d.id}}}
		for other in descriptions {for at := v.description.parent; at != ""; {if at == other.id {return {}, {.Invalid_Scroll, d.id}}; n, _ := layout.find(g, at); at = n.description.parent}}
	}
	c: Candidate; c.frame.allocator = a
	c.owner = s; c.base_version = s.version
	complete := false; defer {if !complete {destroy_candidate(&c)}}
	ok: bool; c.geometry, ok = layout.try_copy_frame(g, a); if !ok {return {}, {code = .Allocation}}
	if !base.retain(g.stamp) {return {}, {code = .Allocation}}; c.frame.stamp = g.stamp
	e: mem.Allocator_Error
	c.frame.regions, e = make(
		[]Region,
		len(descriptions),
		a,
	); if e != nil {return {}, {code = .Allocation}}
	for d, k in descriptions {
		r := &c.frame.regions[k]
		r.id, e = strings.clone(d.id, a); if e != nil {return {}, {code = .Allocation}}
		v, _ := layout.find(g, d.id); content, _ := layout.find(g, d.content_id)
		r.availability = .Applied
		if !v.enabled {r.availability = .Disabled}; if !v.visible {r.availability = .Not_Visible}
		region_target, has_region := interaction.find(i, d.id)
		if !has_region {r.availability = .Not_Found
		} else if r.availability == .Applied &&
		   (region_target.availability != .Invalid_Action ||
				   region_target.description.role !=
					   "") {r.availability = region_target.availability}
		region_available := r.availability == .Applied
		r.viewport =
			v.clip; r.extent = content.bounds.h; r.max_offset = max(0, r.extent - r.viewport.h)
		count := 0; for n in g.nodes {if n.description.parent == d.content_id && n.visible {count += 1}}
		r.items, e = make([]Item, count, a); if e != nil {return {}, {code = .Allocation}}
		index := 0
		for n in g.nodes {if n.description.parent == d.content_id && n.visible {
				item := &r.items[index]; index += 1; item.top = n.bounds.y - content.bounds.y; item.height = n.bounds.h
				view, found := interaction.find(
					i,
					n.description.id,
				); item.available = found && view.availability == .Applied
				item.id, e = strings.clone(
					n.description.id,
					a,
				); if e != nil {return {}, {code = .Allocation}}
			}}
		for old in s.frame.regions {if old.id == d.id {
				if j := retained_item(old, r^, old.anchor_id);
				   j >=
				   0 {r.offset = clamp(r.items[j].top + min(old.intra_offset, r.items[j].height), 0, r.max_offset)}
				if item_index(old, focus_id) >= 0 {
					c.has_focus = true
					if j := retained_item(old, r^, focus_id, true);
					   j >= 0 {c.focus_id = r.items[j].id}
				}
			}}
		if s.has_pending &&
		   region_available &&
		   (s.pending.kind == .Move_Item ||
				   s.pending.kind == .Focus ||
				   s.pending.kind ==
					   .Reveal_Item) {for item in r.items {if item.id == s.pending.id && item.available {
					if s.pending.kind != .Reveal_Item {c.focus_id = item.id; c.has_focus = true}
					if item.top < r.offset || item.height > r.viewport.h {r.offset = item.top
					} else if item.top + item.height >
					   r.offset + r.viewport.h {r.offset = item.top + item.height - r.viewport.h}
					r.offset = clamp(r.offset, 0, r.max_offset)
				}}}
		if s.has_pending &&
		   region_available &&
		   s.pending.kind == .Scroll_By &&
		   s.pending.id == d.id {r.offset = clamp(r.offset + s.pending.delta_y, 0, r.max_offset)}
		for item in r.items {if item.top + item.height > r.offset {
				r.anchor_id, e = strings.clone(
					item.id,
					a,
				); if e != nil {return {}, {code = .Allocation}}
				r.intra_offset = r.offset - item.top; break
			}}
		translate(&c.geometry, d.content_id, -r.offset, r.viewport)
		if r.viewport.h > 0 {for j := len(c.geometry.diagnostics) - 1; j >= 0; j -= 1 {
				diagnostic := c.geometry.diagnostics[j]
				if (diagnostic.id == d.id || diagnostic.id == d.content_id) &&
				   diagnostic.kind == .Container_Overflow &&
				   diagnostic.required.h > diagnostic.available.h &&
				   diagnostic.required.w <=
					   diagnostic.available.w {ordered_remove(&c.geometry.diagnostics, j)}
			}}
	}
	complete = true; return c, {}
}
@(private)
within :: proc(g: ^layout.Frame, id, root: string) -> bool {
	for at := id;
	    at !=
	    ""; {if at == root {return true}; n, ok := layout.find(g, at); if !ok {return false}; at = n.description.parent}
	return false
}
item_index :: proc(r: Region, id: string, available: bool = false) -> int {
	for item, k in r.items {if item.id == id && (!available || item.available) {return k}}
	return -1
}
@(private)
retained_item :: proc(old, next: Region, id: string, available: bool = false) -> int {
	if k := item_index(next, id, available); k >= 0 {return k}
	start := item_index(old, id); if start < 0 {return -1}
	for k := start + 1;
	    k < len(old.items);
	    k += 1 {if j := item_index(next, old.items[k].id, available); j >= 0 {return j}}
	for k := start - 1;
	    k >= 0;
	    k -= 1 {if j := item_index(next, old.items[k].id, available); j >= 0 {return j}}
	return -1
}
commit :: proc(s: ^State, c: ^Candidate) {
	s.version += 1
	old := s.frame; s.frame = c.frame; c.frame = {}
	delete(s.pending.id, s.allocator); s.pending = {}; s.has_pending = false
	layout.destroy_frame(&c.geometry); c^ = {}; destroy_frame(&old)
}
validate_candidate :: proc(p: ^base.Publication, s: ^State, c: ^Candidate) -> bool {
	return(
		c.owner == s &&
		s.version < max(u64) &&
		c.base_version == s.version &&
		c.geometry.nodes != nil &&
		c.frame.stamp == c.geometry.stamp &&
		base.validate(p, c.frame.stamp) == .None \
	)
}
dispatch :: proc(s: ^State, ctx: ^interaction.Context, a: Action) -> interaction.Dispatch_Result {
	if code := interaction.guard_common(ctx, a.source); code != .Applied {return {code = code}}
	if s.frame.stamp != ctx.frame.stamp {return {code = .Not_Ready}}
	x := a
	if a.kind == .Move_Item {
		found := false
		for r in s.frame.regions {for item, k in r.items {if item.id == ctx.focus_id {
					found = true; x.id = item.id; step := 1; if a.backwards {step = -1}
					for j := k + step;
					    j >= 0 && j < len(r.items);
					    j += step {if r.items[j].available {x.id = r.items[j].id; break}}
				}}}
		if !found {return {code = .Invalid_Action}}
	} else if a.kind == .Focus || a.kind == .Reveal_Item {
		if code := interaction.guard(ctx, a.id, a.source); code != .Applied {return {code = code}}
		found := false; for r in s.frame.regions {if item_index(r, a.id, true) >= 0 {found = true}}
		if !found {return {code = .Not_Found}}
	} else if a.kind == .Scroll_By {
		region, found := find(&s.frame, a.id); if !found {return {code = .Not_Found}}
		if code := region_gate(&ctx.frame, region); code != .Applied {return {code = code}}
		if !base.finite(a.delta_y) {return {code = .Invalid_Action}}
		if !base.finite(region.offset + a.delta_y) {return {code = .Invalid_Action}}
	} else {return {code = .Invalid_Action}}
	if a.kind !=
	   .Scroll_By {if code := interaction.guard(ctx, x.id, x.source); code != .Applied {return {code = code}}}
	if s.version == max(u64) {return {code = .Exhausted}}
	id, e := strings.clone(x.id, s.allocator); if e != nil {return {code = .Allocation}}
	delete(s.pending.id, s.allocator); s.pending = x; s.pending.id = id; s.has_pending = true
	s.version += 1
	base.invalidate(ctx.publication); return {code = .Applied}
}
find :: proc(f: ^Frame, id: string) -> (^Region, bool) {for &r in f.regions {if r.id ==
		   id {return &r, true}}
	return nil, false}
@(private)
region_gate :: proc(i: ^interaction.Frame, r: ^Region) -> interaction.Code {
	if r.availability != .Applied {return r.availability}
	n, found := interaction.find(i, r.id); if !found {return .Not_Found}
	if n.availability == .Invalid_Action && n.description.role == "" {return .Applied}
	return n.availability
}
@(private)
translate :: proc(g: ^layout.Frame, id: string, dy: f64, inherited: base.Rect) {
	n, _ := layout.find(g, id)
	n.bounds.y = base.snap({y = n.bounds.y + dy}, g.ui_scale).y
	n.content.y = base.snap({y = n.content.y + dy}, g.ui_scale).y
	n.paint_clip = base.intersection(
		inherited,
		n.bounds,
	); n.clip = base.intersection(inherited, n.content)
	child_clip :=
		inherited; l, has := n.description.layout.?; if !has || l.overflow == .Clip {child_clip = n.clip}
	for child in g.nodes {if child.description.parent == id {translate(g, child.description.id, dy, child_clip)}}
}
