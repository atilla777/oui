package ui_rich

import base "../ui_base"
import layout "../ui_layout"
import text "../ui_text"
import "core:mem"
import "core:strings"

Description :: struct {
	id, source: string,
	base_style: Rich_Style,
	options:    text.Text_Options,
}
Frame :: struct {
	rich_blocks: []Rich_Block,
	stamp:       base.Frame_Stamp,
	drawable:    base.Extent,
	ui_scale:    f64,
	allocator:   mem.Allocator,
	bound:       bool,
}
Candidate :: struct {
	frame:    Frame,
	geometry: layout.Frame,
}
State :: struct {
	frame: Frame,
}
create :: proc() -> State {return {}}
destroy_frame :: proc(f: ^Frame) {
	for &block in f.rich_blocks {destroy_rich_block(&block, f.allocator); delete(block.node_id, f.allocator); delete(block.base_style.font_id, f.allocator)}
	delete(f.rich_blocks, f.allocator); base.release(f.stamp); f^ = {}
}
destroy :: proc(s: ^State) {destroy_frame(&s.frame)}
destroy_candidate :: proc(c: ^Candidate) {destroy_frame(&c.frame); layout.destroy_frame(
		&c.geometry,
	)
	c^ = {}}
validate_candidate :: proc(p: ^base.Publication, c: ^Candidate) -> bool {return(
		c.frame.bound &&
		c.frame.stamp == c.geometry.stamp &&
		base.validate(p, c.frame.stamp) == .None \
	)}
commit :: proc(s: ^State, c: ^Candidate) {old := s.frame; s.frame = c.frame; c.frame = {}
	destroy_frame(&old)}
prepare :: proc(
	nodes: []layout.Node,
	options: layout.Layout_Options,
	descriptions: []Description,
	metrics: Rich_Text_Metrics,
	a: mem.Allocator,
	stamp: base.Frame_Stamp,
	fallback: layout.Layout_Metrics = {},
) -> (
	Candidate,
	Rich_Error,
) {
	for d, index in descriptions {
		found := false
		for n in nodes {if n.id == d.id {found = n.role == .Content || n.role == .Box}; if n.parent == d.id {return {}, {code = .Invalid_Text_Options, id = d.id}}}
		if !found ||
		   d.id == "" ||
		   d.base_style.font_id == "" ||
		   !base.finite(d.base_style.size) ||
		   d.base_style.size <= 0 ||
		   !valid_options(d.options) {return {}, {code = .Invalid_Text_Options, id = d.id}}
		for prior in descriptions[:index] {if prior.id == d.id {return {}, {code = .Invalid_Text_Options, id = d.id}}}
	}
	c := Candidate {
		frame = {allocator = a, drawable = options.drawable, ui_scale = options.ui_scale},
	}
	complete := false; defer {if !complete {destroy_candidate(&c)}}
	if !base.retain(stamp) {return {}, {code = .Allocation}}; c.frame.stamp = stamp
	ae: mem.Allocator_Error
	c.frame.rich_blocks, ae = make(
		[]Rich_Block,
		len(descriptions),
		a,
	); if ae != nil {return {}, {code = .Allocation}}
	bytes, tags, runs := 0, 0, 0
	for d, index in descriptions {
		block := &c.frame.rich_blocks[index]
		block.options, block.base_style = d.options, d.base_style; block.base_style.font_id = ""
		block.node_id, ae = strings.clone(
			d.id,
			a,
		); if ae != nil {return {}, {code = .Allocation, id = d.id}}
		block.base_style.font_id, ae = strings.clone(
			d.base_style.font_id,
			a,
		); if ae != nil {return {}, {code = .Allocation, id = d.id}}
		document, pe := parse_rich_text(
			d.source,
			d.base_style,
			a,
		); if pe.code != .None {pe.id = d.id; return {}, pe}; block.document = document
		bytes += len(document.source); tags += len(document.tags); runs += len(document.runs)
		if bytes > 65536 ||
		   tags > 8192 ||
		   runs > 4096 {return {}, {code = .Rich_Limit_Exceeded, id = d.id}}
		if e := rich_resolve_resources(block, metrics, a);
		   e.code != .None {e.id = d.id; return {}, e}
		if e := rich_layout_block(block, 0, metrics, a);
		   e.code != .None {e.id = d.id; return {}, e}
		block.intrinsic_width = block.natural_extent.w
	}
	input := Measure_Input{&c.frame, fallback}
	stage, ge := layout.prepare(
		nodes,
		options,
		{intrinsic = measure_intrinsic, user = &input},
		a,
		stamp,
	)
	defer layout.destroy_frame(&stage)
	if ge.code != .None {return {}, {code = .Existing, id = ge.id, existing = ge}}
	total_lines := 0
	for &block, index in c.frame.rich_blocks {
		n, _ := layout.find(&stage, block.node_id)
		if e := rich_layout_block(&block, n.content.w, metrics, a, n.content.x, options.ui_scale);
		   e.code != .None {e.id = descriptions[index].id; return {}, e}
		total_lines += len(block.lines)
		if total_lines >
		   4096 {return {}, {code = .Rich_Limit_Exceeded, id = descriptions[index].id}}
	}
	c.geometry, ge = layout.prepare(
		nodes,
		options,
		{intrinsic = measure_intrinsic, user = &input},
		a,
		stamp,
	)
	if ge.code != .None {return {}, {code = .Existing, id = ge.id, existing = ge}}
	for &block, index in c.frame.rich_blocks {
		n, _ := layout.find(&c.geometry, block.node_id)
		if e := resolve_rich_display(&block, n.content, options.ui_scale, metrics, a);
		   e.code != .None {e.id = descriptions[index].id; return {}, e}
	}
	c.frame.bound = true; complete = true
	return c, {}
}
valid_options :: proc(o: text.Text_Options) -> bool {
	if o.wrap < .NoWrap ||
	   o.wrap > .WordWrap ||
	   o.overflow < .Clip ||
	   o.overflow > .Ellipsis ||
	   o.horizontal < .Left ||
	   o.horizontal > .Right ||
	   o.vertical < .Top ||
	   o.vertical > .Bottom {return false}
	if limit, has := o.max_lines.?; has && limit < 0 {return false}
	return true
}
Measure_Input :: struct {
	frame:    ^Frame,
	fallback: layout.Layout_Metrics,
}
measure_intrinsic :: proc(id: string, user: rawptr) -> (base.Extent, bool) {
	input := cast(^Measure_Input)user
	for block in input.frame.rich_blocks {if block.node_id == id {
			height := f64(0); limit := len(block.lines)
			if n, has := block.options.max_lines.?; has {limit = min(limit, n)}
			for k in 0 ..< limit {line := block.lines[k]; height += line.ascent + line.descent + line.gap}
			return {block.intrinsic_width, height}, true
		}}
	if input.fallback.intrinsic != nil {return input.fallback.intrinsic(id, input.fallback.user)}
	return {}, false
}
