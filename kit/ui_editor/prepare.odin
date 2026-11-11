package ui_editor

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import text "../ui_text"
import graphemes "../unicode_graphemes"
import "core:mem"
import "core:strings"

@(private)
prepare_into :: proc(
	c: ^Candidate,
	s: ^State,
	g: ^layout.Frame,
	i: ^interaction.Frame,
	tf: ^text.Frame,
	ds: []Description,
	metrics: text.Text_Layout_Metrics,
) -> Error {
	if g.stamp != i.stamp ||
	   g.stamp != tf.stamp ||
	   (s.frame.stamp.lifetime != nil &&
			   s.frame.stamp.lifetime != g.stamp.lifetime) {return {code = .Stale}}
	if s.version == max(u64) {return {code = .Exhausted}}
	if metrics.font_metrics == nil ||
	   metrics.measure_line == nil ||
	   metrics.validate_text == nil {return {code = .Invalid, rejection = .Glyph_Missing}}
	if !base.retain(g.stamp) {return {code = .Allocation}}
	f := &c.frame; f.stamp = g.stamp; a := f.allocator
	f.drawable, f.ui_scale = g.drawable, g.ui_scale
	ae: mem.Allocator_Error
	f.editors, ae = make([]View, len(ds), a); if ae != nil {return {code = .Allocation}}
	for d, index in ds {
		if d.id == "" ||
		   d.node_id == "" ||
		   d.text_node_id == "" ||
		   d.node_id == d.text_node_id {return {.Invalid, .Invalid_Range, d.id, 0}}
		for prior in ds[:index] {if prior.id == d.id || prior.node_id == d.node_id || prior.text_node_id == d.text_node_id || prior.node_id == d.text_node_id || prior.text_node_id == d.node_id {return {.Invalid, .Invalid_Range, d.id, 0}}}
		n, found := layout.find(g, d.node_id); leaf, has_leaf := layout.find(g, d.text_node_id)
		it, has_target := interaction.find(i, d.node_id)
		if !found ||
		   !has_leaf ||
		   !has_target ||
		   it.description.role == "" ||
		   leaf.description.parent != d.node_id {return {.Invalid, .Invalid_Range, d.id, 0}}
		for node in g.nodes {if node.description.parent == d.text_node_id {return {.Invalid, .Invalid_Range, d.id, 0}}}
		// Binding is candidate-local; incompatible selected families cannot claim it.
		if code := interaction.bind_activation_owner(i, d.node_id, "editor"); code != .Applied {
			if code == .Allocation {return {code = .Allocation, id = d.id}}
			return {code = .Invalid, id = d.id}
		}
		v := editor_splice("", 0, 0, d.value, d.max_graphemes, a)
		rejection, offset := v.rejection, v.byte_offset; destroy_editor_splice(&v)
		if rejection !=
		   .None {code := Error_Code.Invalid; if rejection == .Allocation {code = .Allocation}; return {code, rejection, d.id, offset}}
		e := &f.editors[index]
		e.description = d
		// Clear borrowed fields before any fallible clone, so partial cleanup never frees caller storage.
		e.id, e.node_id, e.text_node_id, e.label, e.value = "", "", "", "", ""
		for pair in ([]struct {
				src: string,
				dst: ^string,
			}{{d.id, &e.id}, {d.node_id, &e.node_id}, {d.text_node_id, &e.text_node_id}, {d.label, &e.label}, {d.value, &e.value}}) {
			pair.dst^, ae = strings.clone(
				pair.src,
				a,
			); if ae != nil {return {code = .Allocation, id = d.id}}
		}
		boundaries, be := graphemes.try_boundaries(
			d.value,
			a,
		); if be != nil {return {code = .Allocation, id = d.id}}
		e.boundaries = boundaries.([]int); e.count = len(e.boundaries) - 1
		e.caret, e.anchor = len(d.value), len(d.value)
		if old, ok := find(&s.frame, d.id);
		   ok && old.value == d.value && old.revision == d.revision {
			e.caret, e.anchor, e.scroll = old.caret, old.anchor, old.scroll
			if s.cursor.id ==
			   d.id {e.caret, e.anchor, e.scroll = s.cursor.caret, s.cursor.anchor, s.cursor.scroll}
		}
		if !resolve(s, e) {return {.Invalid, .Stale_Value, d.id, 0}}
		e.availability, e.content, e.clip = it.availability, n.content, leaf.paint_clip
		e.geometry = {
			scale        = 1,
			opacity      = 1,
			bounds       = n.bounds,
			content      = n.content,
			clip         = n.paint_clip,
			content_clip = base.intersection(n.content, leaf.paint_clip),
		}
		f.ui_scale = g.ui_scale
		block: ^text.Text_Block
		for &b in tf.text_blocks {if b.node_id == d.text_node_id {block = &b; break}}
		if block == nil ||
		   block.original_text != d.value ||
		   block.options.wrap != .NoWrap ||
		   block.options.overflow != .Clip {return {.Invalid, .Invalid_Range, d.id, 0}}
		e.font_size = block.font_size
		e.font_id, ae = strings.clone(
			block.font_id,
			a,
		); if ae != nil {return {code = .Allocation, id = d.id}}
		ge, byte_offset := metrics.validate_text(d.value, e.font_id, e.font_size, metrics.user)
		if ge != .None {return {.Invalid, .Glyph_Missing, d.id, byte_offset}}
		fm, fe := metrics.font_metrics(e.font_id, e.font_size, metrics.user)
		if fe != .None ||
		   !base.finite_nonnegative(fm.ascent) ||
		   !base.finite_nonnegative(fm.line_advance) {return {.Invalid, .Glyph_Missing, d.id, 0}}
		e.ascent, e.line_advance = fm.ascent, fm.line_advance
		e.font_revision, ae = strings.clone(
			fm.font_revision,
			a,
		); if ae != nil {return {code = .Allocation, id = d.id}}
		e.stops, ae = make(
			[]f64,
			len(e.boundaries),
			a,
		); if ae != nil {return {code = .Allocation, id = d.id}}
		e.runs, ae = make([]Run, e.count, a); if ae != nil {return {code = .Allocation, id = d.id}}
		for j in 0 ..< e.count {
			start, end := e.boundaries[j], e.boundaries[j + 1]
			m, me := metrics.measure_line(e.value[start:end], e.font_id, e.font_size, metrics.user)
			if me != .None ||
			   !base.finite_nonnegative(m.advance_width) ||
			   !base.finite_nonnegative(m.surface_extent.w) ||
			   !base.finite_nonnegative(m.surface_extent.h) ||
			   !base.finite(
					   e.stops[j] + m.advance_width,
				   ) {return {.Invalid, .Glyph_Missing, d.id, 0}}
			e.runs[j] = {start, end, e.stops[j], m.advance_width, m.surface_extent}
			e.stops[j + 1] = e.stops[j] + m.advance_width
			e.extent = max(e.extent, e.stops[j] + m.surface_extent.w)
		}
		e.extent = max(e.extent, e.stops[len(e.stops) - 1] + 1 / g.ui_scale)
		reveal(e, 1 / g.ui_scale)
	}
	return {}
}

@(private)
resolve :: proc(s: ^State, e: ^View) -> bool {
	old, exists := find(&s.frame, e.id)
	if !exists {return e.resolution.kind == .Unchanged || e.resolution.kind == .External}
	unchanged := old.value == e.value && old.revision == e.revision
	if p, pending := s.pending.?; pending && p.id == e.id {
		if e.resolution.sequence != p.sequence {return false}
		switch e.resolution.kind {
		case .Accepted:
			if e.value != p.value || e.revision <= p.base_revision {return false}
			e.caret, e.anchor = p.caret, p.anchor
		case .Rejected:
			if !unchanged {return false}; e.rejection = e.resolution.rejection
		case .External:
			if e.revision <= old.revision {return false}
			e.caret, e.anchor, e.scroll = len(e.value), len(e.value), 0
		case .Unchanged:
			return false
		}
		return true
	}
	if unchanged {return e.resolution.kind == .Unchanged || e.resolution == old.resolution}
	if e.resolution.kind != .External || e.revision <= old.revision {return false}
	e.caret, e.anchor, e.scroll = len(e.value), len(e.value), 0
	return true
}
@(private)
reveal :: proc(e: ^View, width: f64) {
	x: f64
	for b, j in e.boundaries {if b == e.caret {x = e.stops[j]; break}}
	maximum := max(0, e.extent - e.content.w)
	e.scroll = clamp(e.scroll, 0, maximum)
	if x < e.scroll {e.scroll = x}
	if x + width >
	   e.scroll + e.content.w {e.scroll = min(maximum, max(0, x + width - e.content.w))}
}
