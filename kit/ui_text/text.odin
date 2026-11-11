package ui_text

import base "../ui_base"
import layout "../ui_layout"
import style "../ui_style"
import graphemes "../unicode_graphemes"
import "core:mem"
import "core:strings"

Extent :: base.Extent
Rect :: base.Rect
snap :: base.snap
finite :: base.finite
finite_nonnegative :: base.finite_nonnegative
Resolved_Node :: layout.Resolved_Node
Update_Error :: layout.Update_Error
Frame :: struct {
	drawable:         base.Extent,
	text_blocks:      []Text_Block,
	text_diagnostics: []Text_Diagnostic,
	id:               u64,
	ui_scale:         f64,
	stamp:            base.Frame_Stamp,
	allocator:        mem.Allocator,
}
Candidate :: struct {
	text:     Frame,
	geometry: layout.Layout_Candidate,
}

Text_Wrap :: enum {
	NoWrap,
	WordWrap,
}
Text_Overflow :: enum {
	Clip,
	Ellipsis,
}
Text_Horizontal :: enum {
	Left,
	Center,
	Right,
}
Text_Vertical :: enum {
	Top,
	Center,
	Bottom,
}
Text_Options :: struct {
	wrap:              Text_Wrap,
	overflow:          Text_Overflow,
	horizontal:        Text_Horizontal,
	vertical:          Text_Vertical,
	max_lines:         Maybe(int),
	overflow_expected: bool,
}
Text_Node :: struct {
	id, text:  string,
	font:      style.Font_ID,
	font_size: f64,
	options:   Text_Options,
}
Text_Font_Metrics :: struct {
	ascent, descent, line_advance: f64,
	font_revision:                 string,
}
Text_Line_Metrics :: struct {
	advance_width:  f64,
	surface_extent: Extent,
}
Text_Metric_Error :: enum {
	None,
	Failed,
	Glyph_Missing,
}
Text_Layout_Metrics :: struct {
	font_metrics:  proc(
		font_id: string,
		size: f64,
		user: rawptr,
	) -> (
		Text_Font_Metrics,
		Text_Metric_Error,
	),
	measure_line:  proc(
		text, font_id: string,
		size: f64,
		user: rawptr,
	) -> (
		Text_Line_Metrics,
		Text_Metric_Error,
	),
	validate_text: proc(
		text, font_id: string,
		size: f64,
		user: rawptr,
	) -> (
		Text_Metric_Error,
		int,
	),
	user:          rawptr,
}
Text_Error_Code :: enum {
	None,
	Existing,
	Invalid_UTF8,
	Unsupported_Text_Control,
	Invalid_Text_Options,
	Text_Metrics_Failed,
	Glyph_Missing,
	Text_Limit_Exceeded,
	Invalid_Text_Geometry,
}
Text_Update_Result :: struct {
	code:        Text_Error_Code,
	id:          string,
	byte_offset: int,
	existing:    Update_Error,
}
Text_Break :: enum {
	Explicit,
	Soft_Space,
	Emergency,
	End,
}
Text_Source_Range :: struct {
	start, end: int,
}
Text_Line :: struct {
	source_byte_ranges: []Text_Source_Range,
	display_text:       string,
	break_reason:       Text_Break,
	logical_rect:       Rect,
	baseline:           f64,
	measured_extent:    Extent,
	displayed:          bool,
}
Text_Block :: struct {
	line_advance, ascent:                           f64,
	node_id, original_text, font_id, font_revision: string,
	font_size:                                      f64,
	options:                                        Text_Options,
	content_width:                                  f64,
	natural_extent:                                 Extent,
	natural_line_count:                             int,
	lines:                                          []Text_Line,
	visible_line_count:                             int,
	hidden, ellipsized, ellipsis_unavailable:       bool,
}
Text_Diagnostic_Kind :: enum {
	Pixel_Overflow,
	Hidden_Lines,
	Ellipsis_No_Space,
	Zero_Width,
}
Text_Diagnostic :: struct {
	node_id:                                string,
	frame_id:                               u64,
	kind:                                   Text_Diagnostic_Kind,
	required_extent, available_extent:      Extent,
	natural_line_count, visible_line_count: int,
	policy:                                 Text_Overflow,
	expected:                               bool,
}

prepare :: proc(
	nodes: []Text_Node,
	structural: []layout.Node,
	options: layout.Layout_Options,
	metrics: Text_Layout_Metrics,
	a: mem.Allocator,
	stamp: base.Frame_Stamp,
) -> (
	Candidate,
	Text_Update_Result,
) {
	c, e := prepare_internal(nodes, structural, options, metrics, a, stamp)
	if e.code != .None {destroy_candidate(&c); return {}, e}
	return c, e
}
@(private)
prepare_internal :: proc(
	nodes: []Text_Node,
	structural: []layout.Node,
	options: layout.Layout_Options,
	metrics: Text_Layout_Metrics,
	a: mem.Allocator,
	stamp: base.Frame_Stamp,
) -> (
	candidate: Candidate,
	result_error: Text_Update_Result,
) {
	candidate.text = {
		drawable  = options.drawable,
		allocator = a,
		id        = stamp.attempt,
		ui_scale  = options.ui_scale,
	}
	if !base.retain(stamp) {return candidate, {code = .Existing, existing = {.Allocation, ""}}}
	candidate.text.stamp = stamp
	bytes := 0
	for n in nodes {
		if len(n.text) > 65536 - bytes {return candidate, {code = .Text_Limit_Exceeded, id = n.id}}
		bytes += len(n.text)
	}
	blocks := make([dynamic]Text_Block, a)
	defer {f := Frame {
			allocator   = a,
			text_blocks = blocks[:],
		}; destroy_text(&f)}
	for n, i in nodes {
		opts, id := n.options, n.id
		for prior in nodes[:i] {if prior.id == id {return candidate, {code = .Invalid_Text_Options, id = id}}}
		index := layout.node_index(structural, id)
		if index < 0 ||
		   structural[index].role !=
			   .Content {return candidate, {code = .Invalid_Text_Options, id = id}}
		if n.font.id == "" ||
		   !finite_nonnegative(n.font_size) ||
		   n.font_size == 0 ||
		   opts.wrap < .NoWrap ||
		   opts.wrap > .WordWrap ||
		   opts.overflow < .Clip ||
		   opts.overflow > .Ellipsis ||
		   opts.horizontal < .Left ||
		   opts.horizontal > .Right ||
		   opts.vertical < .Top ||
		   opts.vertical > .Bottom {return candidate, {code = .Invalid_Text_Options, id = id}}
		if limit, ok := opts.max_lines.?;
		   ok && limit < 0 {return candidate, {code = .Invalid_Text_Options, id = id}}
		if bad, failed := graphemes.count(n.text).(graphemes.Invalid_UTF8);
		   failed {return candidate, {code = .Invalid_UTF8, id = id, byte_offset = bad.byte_offset}}
		for r, offset in n.text {
			if (r < 32 && r != '\r' && r != '\n') ||
			   (r >= 0x7f && r <= 0x9f) ||
			   r == 0x2028 ||
			   r == 0x2029 ||
			   r == 0x061c ||
			   r == 0x200e ||
			   r == 0x200f ||
			   (r >= 0x202a && r <= 0x202e) ||
			   (r >= 0x2066 &&
					   r <=
						   0x2069) {return candidate, {code = .Unsupported_Text_Control, id = id, byte_offset = offset}}
		}
		font, size := n.font.id, n.font_size
		if metrics.validate_text == nil ||
		   metrics.font_metrics == nil ||
		   metrics.measure_line == nil {return candidate, {code = .Text_Metrics_Failed, id = id}}
		fm, err := metrics.font_metrics(font, size, metrics.user)
		if err != .None {return candidate, {code = text_metric_error(err), id = id}}
		if !finite_nonnegative(fm.ascent) ||
		   !finite_nonnegative(fm.descent) ||
		   !finite_nonnegative(fm.line_advance) ||
		   fm.line_advance <= 0 ||
		   !finite(
				   fm.ascent + fm.descent,
			   ) {return candidate, {code = .Invalid_Text_Geometry, id = id}}
		glyph, offset := metrics.validate_text(n.text, font, size, metrics.user)
		if glyph !=
		   .None {return candidate, {code = text_metric_error(glyph), id = id, byte_offset = offset}}
		if opts.overflow == .Ellipsis {
			e, ellipsis_offset := metrics.validate_text("…", font, size, metrics.user)
			if e !=
			   .None {return candidate, {code = text_metric_error(e), id = id, byte_offset = ellipsis_offset}}
		}
		b := Text_Block {
			line_advance  = max(fm.line_advance, fm.ascent + fm.descent),
			ascent        = fm.ascent,
			node_id       = id,
			original_text = n.text,
			font_id       = font,
			font_revision = fm.font_revision,
			font_size     = size,
			options       = opts,
		}
		owned, be := try_clone_text_block(b, a)
		if be != nil {return candidate, {code = .Existing, existing = {.Allocation, id}}}
		if _, append_error := append(&blocks, owned);
		   append_error !=
		   nil {free_text_block(owned, a); return candidate, {code = .Existing, existing = {.Allocation, id}}}
		result := build_text_paragraphs(&blocks[len(blocks) - 1], metrics, a)
		if result.code != .None {result.id = id; return candidate, result}
	}
	if limit := text_line_limit(blocks[:], nodes); limit.code != .None {return candidate, limit}
	// A/B: intrinsic X and final X. Existing axis-independent layout kernels
	// compute a disposable Y projection too; it never feeds widths or pass C.
	widths, we := make([]f64, len(blocks), a); defer delete(widths, a)
	if we != nil {return candidate, {code = .Existing, existing = {.Allocation, ""}}}
	for b, i in blocks {widths[i] = b.natural_extent.w}
	input := Text_Measure_Input{blocks[:], widths}
	xstage, err := layout.prepare(structural, options, {measure_text_node, &input}, a, stamp)
	defer layout.destroy_frame(&xstage)
	if err.code != .None {return candidate, {code = .Existing, id = err.id, existing = err}}
	// C: line layout under final snapped X; bottom-up dependent Content Y.
	for &b in blocks {
		n, _ := layout.find(&xstage, b.node_id)
		b.content_width = n.content.w
		if b.options.wrap == .WordWrap && b.content_width > 0 {
			result := wrap_text_block(&b, metrics, a)
			if result.code !=
			   .None {result.id = text_input_id(nodes, b.node_id); return candidate, result}
		}
		if b.options.overflow == .Ellipsis {
			result := prime_text_ellipsis(&b, metrics, a)
			if result.code !=
			   .None {result.id = text_input_id(nodes, b.node_id); return candidate, result}
		}
	}
	if limit := text_line_limit(blocks[:], nodes); limit.code != .None {return candidate, limit}
	// D: final Y. Intrinsic widths are frozen, so Y cannot feed back into X.
	candidate.geometry, err = layout.prepare(
		structural,
		options,
		{measure_text_node, &input},
		a,
		stamp,
	)
	if err.code != .None {return candidate, {code = .Existing, id = err.id, existing = err}}
	source := Frame {
		allocator   = a,
		text_blocks = blocks[:],
	}
	if e := try_clone_text_metadata(&source, &candidate.text);
	   e != nil {return candidate, {code = .Existing, existing = {.Allocation, ""}}}
	for &b in candidate.text.text_blocks {
		n, _ := layout.find(&candidate.geometry, b.node_id)
		result := resolve_text_display(&b, n, &candidate.text, metrics)
		if result.code !=
		   .None {result.id = text_input_id(nodes, b.node_id); return candidate, result}
	}
	return candidate, {}
}

Text_Measure_Input :: struct {
	blocks: []Text_Block,
	widths: []f64,
}
measure_text_node :: proc(id: string, user: rawptr) -> (Extent, bool) {
	i := cast(^Text_Measure_Input)user
	for b, index in i.blocks {if b.node_id == id {
			h := b.natural_extent.h
			if limit, has := b.options.max_lines.?;
			   has {h = f64(min(limit, b.natural_line_count)) * b.line_advance}
			return {i.widths[index], h}, true
		}}
	return {}, false
}

resolve_text_display :: proc(
	b: ^Text_Block,
	n: ^Resolved_Node,
	f: ^Frame,
	metrics: Text_Layout_Metrics,
) -> Text_Update_Result {
	content := n.content
	slots := 0
	if content.w > 0 && content.h > 0 {
		for i in 0 ..< len(b.lines) {
			box := snap({content.x, content.y, 0, f64(i + 1) * b.line_advance}, f.ui_scale)
			if box.h > content.h {break}
			slots += 1
		}
	}
	if limit, has := b.options.max_lines.?; has {slots = min(slots, limit)}
	b.visible_line_count = slots
	horizontal_overflow := false
	for l in b.lines {if l.measured_extent.w > content.w {horizontal_overflow = true}}
	b.hidden = slots < b.natural_line_count || horizontal_overflow
	if b.options.overflow == .Ellipsis && slots > 0 {
		last := -1
		for i in 0 ..< slots {if b.lines[i].measured_extent.w > content.w {last = i; break}}
		if last < 0 && slots < b.natural_line_count {last = slots - 1}
		if last >= 0 {
			b.visible_line_count = last + 1
			l := &b.lines[last]
			source := l.display_text
			boundary_result, be := graphemes.try_boundaries(source, f.allocator)
			if be != nil {return {code = .Existing, existing = {.Allocation, ""}}}
			offsets := boundary_result.([]int); defer delete(offsets, f.allocator)
			best := -1
			best_metrics: Text_Line_Metrics
			for offset in offsets {
				candidate, ce := strings.concatenate({source[:offset], "…"}, f.allocator)
				if ce != nil {return {code = .Existing, existing = {.Allocation, ""}}}
				m, code := checked_text_measure(b, candidate, metrics)
				delete(candidate, f.allocator)
				if code != .None {return {code = code}}
				if m.advance_width <= content.w {best = offset; best_metrics = m}
			}
			display := ""
			if best >= 0 {
				joined, je := strings.concatenate({source[:best], "…"}, f.allocator)
				if je != nil {return {code = .Existing, existing = {.Allocation, ""}}}
				display = joined
				b.ellipsized = true
			} else {b.ellipsis_unavailable = true; best = 0}
			delete(l.display_text, f.allocator); l.display_text = display
			l.source_byte_ranges[0].end = l.source_byte_ranges[0].start + best
			l.measured_extent = {best_metrics.advance_width, best_metrics.surface_extent.h}
		}
	}
	block_height := f64(b.visible_line_count) * b.line_advance
	y := content.y
	if content.h > block_height {
		if b.options.vertical == .Center {y += (content.h - block_height) / 2}
		if b.options.vertical == .Bottom {y += content.h - block_height}
	}
	for &l, i in b.lines {
		x := content.x
		if content.w > l.measured_extent.w {
			if b.options.horizontal == .Center {x += (content.w - l.measured_extent.w) / 2}
			if b.options.horizontal == .Right {x += content.w - l.measured_extent.w}
		}
		l.logical_rect = snap(
			{x, y + f64(i) * b.line_advance, l.measured_extent.w, b.line_advance},
			f.ui_scale,
		)
		l.baseline = y + f64(i) * b.line_advance + b.ascent
		l.displayed =
			i < b.visible_line_count && n.visible && content.w > 0 && n.clip.w > 0 && n.clip.h > 0
		if !finite(l.logical_rect.x) ||
		   !finite(l.logical_rect.y) ||
		   !finite_nonnegative(l.logical_rect.w) ||
		   !finite_nonnegative(l.logical_rect.h) ||
		   !finite(l.baseline) {return {code = .Invalid_Text_Geometry}}
	}
	diagnostics, de := make([dynamic]Text_Diagnostic, 0, 4, f.allocator)
	defer delete(diagnostics)
	if de != nil {return {code = .Existing, existing = {.Allocation, ""}}}
	if horizontal_overflow ||
	   b.natural_extent.h >
		   content.h {append(&diagnostics, Text_Diagnostic{kind = .Pixel_Overflow})}
	if b.visible_line_count <
	   b.natural_line_count {append(&diagnostics, Text_Diagnostic{kind = .Hidden_Lines})}
	if b.ellipsis_unavailable {append(&diagnostics, Text_Diagnostic{kind = .Ellipsis_No_Space})}
	if content.w == 0 &&
	   b.natural_line_count > 0 {append(&diagnostics, Text_Diagnostic{kind = .Zero_Width})}
	// Frame arrays are owned slices; append by allocating the exact combined array.
	joined, je := make([]Text_Diagnostic, len(f.text_diagnostics) + len(diagnostics), f.allocator)
	if je != nil {return {code = .Existing, existing = {.Allocation, ""}}}
	copy(joined, f.text_diagnostics)
	old_count := len(f.text_diagnostics)
	delete(f.text_diagnostics, f.allocator)
	f.text_diagnostics = joined
	for d, i in diagnostics {
		diag := d
		id, ie := strings.clone(b.node_id, f.allocator)
		if ie != nil {return {code = .Existing, existing = {.Allocation, ""}}}
		diag.node_id = id; diag.frame_id = f.id
		diag.required_extent, diag.available_extent = b.natural_extent, {content.w, content.h}
		diag.natural_line_count, diag.visible_line_count =
			b.natural_line_count, b.visible_line_count
		diag.policy, diag.expected = b.options.overflow, b.options.overflow_expected
		joined[old_count + i] = diag
	}
	return {}
}

// A legal emergency boundary is an EGC boundary not adjacent to NBSP/NNBSP.
text_nonbreaking :: proc(cluster: string) -> bool {
	// Prepend can precede the space within the same EGC (GB9b).
	for r in cluster {if r == '\u00a0' || r == '\u202f' {return true}}
	return false
}
text_metric_error :: proc(e: Text_Metric_Error) -> Text_Error_Code {
	if e == .Glyph_Missing {return .Glyph_Missing}
	return .Text_Metrics_Failed
}
text_input_id :: proc(nodes: []Text_Node, id: string) -> string {
	for n in nodes {if n.id == id {return n.id}}
	return ""
}
text_line_limit :: proc(blocks: []Text_Block, nodes: []Text_Node) -> Text_Update_Result {
	n := 0
	for b in blocks {
		n += b.natural_line_count
		if n > 4096 {return {code = .Text_Limit_Exceeded, id = text_input_id(nodes, b.node_id)}}
	}
	return {}
}
checked_text_measure :: proc(
	b: ^Text_Block,
	text: string,
	metrics: Text_Layout_Metrics,
) -> (
	Text_Line_Metrics,
	Text_Error_Code,
) {
	m, e := metrics.measure_line(text, b.font_id, b.font_size, metrics.user)
	if e != .None {return {}, text_metric_error(e)}
	if !finite_nonnegative(m.advance_width) ||
	   !finite_nonnegative(m.surface_extent.w) ||
	   !finite_nonnegative(m.surface_extent.h) {return {}, .Invalid_Text_Geometry}
	m.advance_width = max(m.advance_width, m.surface_extent.w)
	b.line_advance = max(b.line_advance, m.surface_extent.h)
	return m, .None
}
free_text_lines :: proc(lines: []Text_Line, a: mem.Allocator) {
	for l in lines {delete(l.display_text, a); delete(l.source_byte_ranges, a)}
	delete(lines, a)
}
append_text_line :: proc(
	lines: ^[dynamic]Text_Line,
	b: ^Text_Block,
	start, end: int,
	reason: Text_Break,
	m: Text_Line_Metrics,
	a: mem.Allocator,
) -> Text_Update_Result {
	if len(lines) >= 4096 {return {code = .Text_Limit_Exceeded}}
	ranges, re := make([]Text_Source_Range, 1, a)
	if re != nil {return {code = .Existing, existing = {.Allocation, ""}}}
	text, te := strings.clone(b.original_text[start:end], a)
	if te != nil {delete(ranges, a); return {code = .Existing, existing = {.Allocation, ""}}}
	ranges[0] = {start, end}
	_, ae := append(
		lines,
		Text_Line {
			source_byte_ranges = ranges,
			display_text = text,
			break_reason = reason,
			measured_extent = {m.advance_width, m.surface_extent.h},
			displayed = true,
		},
	)
	if ae !=
	   nil {delete(ranges, a); delete(text, a); return {code = .Existing, existing = {.Allocation, ""}}}
	return {}
}
text_natural :: proc(b: ^Text_Block) -> Text_Update_Result {
	b.natural_line_count = len(b.lines); b.visible_line_count = len(b.lines)
	b.natural_extent = {0, f64(len(b.lines)) * b.line_advance}
	for l in b.lines {b.natural_extent.w = max(b.natural_extent.w, l.measured_extent.w)}
	if !finite_nonnegative(b.natural_extent.h) {return {code = .Invalid_Text_Geometry}}
	return {}
}
build_text_paragraphs :: proc(
	b: ^Text_Block,
	metrics: Text_Layout_Metrics,
	a: mem.Allocator,
) -> Text_Update_Result {
	lines := make([dynamic]Text_Line, a)
	defer {if b.lines == nil {free_text_lines(lines[:], a)}}
	text := b.original_text
	if len(text) > 0 {
		start := 0
		for p := 0; p <= len(text); p += 1 {
			if p < len(text) && text[p] != '\r' && text[p] != '\n' {continue}
			m, code := checked_text_measure(b, text[start:p], metrics)
			if code != .None {return {code = code, byte_offset = start}}
			reason := Text_Break.Explicit; if p == len(text) {reason = .End}
			result := append_text_line(&lines, b, start, p, reason, m, a)
			if result.code != .None {return result}
			if p + 1 < len(text) && text[p] == '\r' && text[p + 1] == '\n' {p += 1}
			start = p + 1
		}
	}
	b.lines = lines[:]
	return text_natural(b)
}
wrap_text_block :: proc(
	b: ^Text_Block,
	metrics: Text_Layout_Metrics,
	a: mem.Allocator,
) -> Text_Update_Result {
	lines := make([dynamic]Text_Line, a)
	transferred := false
	defer {if !transferred {free_text_lines(lines[:], a)}}
	for paragraph in b.lines {
		range := paragraph.source_byte_ranges[0]
		start, end := range.start, range.end
		for {
			chosen, next := end, end
			reason := paragraph.break_reason
			full, code := checked_text_measure(b, b.original_text[start:end], metrics)
			if code != .None {return {code = code, byte_offset = start}}
			if full.advance_width > b.content_width && start < end {
				part := b.original_text[start:end]
				boundary_result, be := graphemes.try_boundaries(part, a)
				if be != nil {return {code = .Existing, existing = {.Allocation, ""}}}
				offsets := boundary_result.([]int)
				defer delete(offsets, a)
				chosen, next = -1, -1
				// Preferred interior runs of ASCII spaces; the selected run is
				// omitted only at this soft break, not at source paragraph edges.
				j := 0
				for j + 1 < len(offsets) {
					if part[offsets[j]:offsets[j + 1]] != " " {j += 1; continue}
					run := j
					for j + 1 < len(offsets) && part[offsets[j]:offsets[j + 1]] == " " {j += 1}
					if run == 0 ||
					   j == len(offsets) - 1 ||
					   !text_wrap_boundary(part, offsets, run) ||
					   !text_wrap_boundary(part, offsets, j) {continue}
					m, candidate_code := checked_text_measure(b, part[:offsets[run]], metrics)
					if candidate_code !=
					   .None {return {code = candidate_code, byte_offset = start}}
					if m.advance_width <=
					   b.content_width {chosen, next = start + offsets[run], start + offsets[j]}
				}
				reason = .Soft_Space
				if chosen < 0 {
					reason = .Emergency
					first := end
					for boundary in 1 ..< len(offsets) {
						p := start + offsets[boundary]
						if !text_wrap_boundary(part, offsets, boundary) {continue}
						first = min(first, p)
						m, candidate_code := checked_text_measure(
							b,
							b.original_text[start:p],
							metrics,
						)
						if candidate_code !=
						   .None {return {code = candidate_code, byte_offset = start}}
						if m.advance_width <= b.content_width {chosen = p}
					}
					if chosen < 0 {chosen = first}
					next = chosen
				}
			}
			m, final_code := checked_text_measure(b, b.original_text[start:chosen], metrics)
			if final_code != .None {return {code = final_code, byte_offset = start}}
			if chosen == end {reason = paragraph.break_reason}
			result := append_text_line(&lines, b, start, chosen, reason, m, a)
			if result.code != .None {return result}
			if next == end {break}
			start = next
		}
	}
	free_text_lines(b.lines, a)
	b.lines = lines[:]; transferred = true
	return text_natural(b)
}
text_wrap_boundary :: proc(text: string, offsets: []int, j: int) -> bool {
	if j == 0 || j == len(offsets) - 1 {return true}
	return(
		!text_nonbreaking(text[offsets[j - 1]:offsets[j]]) &&
		!text_nonbreaking(text[offsets[j]:offsets[j + 1]]) \
	)
}

// Measure all possible display prefixes before dependent Y. Surfaces (including
// ellipsis) can be taller than nominal advance; no late height feedback in D.
prime_text_ellipsis :: proc(
	b: ^Text_Block,
	metrics: Text_Layout_Metrics,
	a: mem.Allocator,
) -> Text_Update_Result {
	for l in b.lines {
		boundary_result, be := graphemes.try_boundaries(l.display_text, a)
		if be != nil {return {code = .Existing, existing = {.Allocation, ""}}}
		offsets := boundary_result.([]int); defer delete(offsets, a)
		for offset in offsets {
			candidate, ce := strings.concatenate({l.display_text[:offset], "…"}, a)
			if ce != nil {return {code = .Existing, existing = {.Allocation, ""}}}
			_, code := checked_text_measure(b, candidate, metrics)
			delete(candidate, a)
			if code != .None {return {code = code}}
		}
	}
	return text_natural(b)
}
destroy_text :: proc(f: ^Frame) {
	a := f.allocator
	for b in f.text_blocks {
		delete(
			b.node_id,
			a,
		); delete(b.original_text, a); delete(b.font_id, a); delete(b.font_revision, a)
		for l in b.lines {delete(l.display_text, a); delete(l.source_byte_ranges, a)}
		delete(b.lines, a)
	}
	delete(f.text_blocks, a)
	for d in f.text_diagnostics {delete(d.node_id, a)}
	delete(f.text_diagnostics, a)
}
