package ui_rich

import base "../ui_base"
import text "../ui_text"
import graphemes "../unicode_graphemes"
import "core:mem"

Rich_Run_Metrics :: struct {
	width, height, baseline, ascent, descent, gap: f64,
	revision:                                      string,
}
Rich_Text_Metrics :: struct {
	coverage:   proc(scalar: rune, style: Rich_Style, user: rawptr) -> string,
	font_chain: proc(style: Rich_Style, user: rawptr) -> []string,
	measure:    proc(
		value: string,
		style: Rich_Style,
		user: rawptr,
	) -> (
		Rich_Run_Metrics,
		Rich_Error_Code,
	),
	image:      proc(id: string, user: rawptr) -> bool,
	user:       rawptr,
}
Rich_Fragment :: struct {
	run_index:     int,
	decoded_range: Text_Source_Range,
	synthetic:     bool,
	metrics:       Rich_Run_Metrics,
	rect:          base.Rect,
}
Rich_Line :: struct {
	decoded_range:                         Text_Source_Range,
	fragments:                             [dynamic]Rich_Fragment,
	width, ascent, descent, gap, baseline: f64,
	break_reason:                          text.Text_Break,
	displayed:                             bool,
}
Rich_Coverage :: struct {
	decoded_range, source_range: Text_Source_Range,
	resource:                    string,
}
Rich_Chain_View :: struct {
	style:     Rich_Style,
	resources: []string,
}
Rich_Block :: struct {
	node_id:                                  string,
	document:                                 Rich_Document,
	base_style:                               Rich_Style,
	options:                                  text.Text_Options,
	lines:                                    [dynamic]Rich_Line,
	coverage:                                 []Rich_Coverage,
	font_chains:                              []Rich_Chain_View,
	natural_extent:                           base.Extent,
	intrinsic_width, content_width:           f64,
	visible_line_count:                       int,
	hidden, ellipsized, ellipsis_unavailable: bool,
}
rich_layout_block :: proc(
	b: ^Rich_Block,
	width: f64,
	metrics: Rich_Text_Metrics,
	a: mem.Allocator,
	origin := f64(0),
	scale := f64(1),
) -> Rich_Error {
	if !base.finite_nonnegative(width) ||
	   !base.finite(origin) ||
	   !base.finite(scale) ||
	   scale <= 0 {return {code = .Invalid_Geometry}}
	for line in b.lines {rich_free_line(line, a)}; clear(&b.lines)
	if b.lines.allocator.procedure == nil {b.lines = make([dynamic]Rich_Line, 0, 0, a)}
	b.content_width = width
	if metrics.measure == nil || metrics.image == nil {return {code = .Metrics_Failed}}
	value := b.document.decoded
	if value == "" {b.natural_extent = {}; return {}}
	paragraph := 0
	for end := 0; end <= len(value); end += 1 {
		if end < len(value) && value[end] != '\r' && value[end] != '\n' {continue}
		start := paragraph
		for {
			chosen, next := end, end
			reason := text.Text_Break.End; if end < len(value) {reason = .Explicit}
			full, e := rich_measure_range(
				b,
				start,
				end,
				false,
				metrics,
				a,
			); if e.code != .None {return e}
			full_fits := rich_line_fits(
				full,
				width,
				origin,
				scale,
				b.options.horizontal,
			); rich_free_line(full, a)
			if b.options.wrap == .WordWrap && width > 0 && !full_fits && start < end {
				part := value[start:end]
				boundary_result, ae := graphemes.try_boundaries(
					part,
					a,
				); if ae != nil {return {code = .Allocation}}
				bounds := boundary_result.([]int); defer delete(bounds, a)
				chosen, next = -1, -1
				j := 0
				for j + 1 < len(bounds) {
					if part[bounds[j]:bounds[j + 1]] != " " {j += 1; continue}
					space :=
						j; for j + 1 < len(bounds) && part[bounds[j]:bounds[j + 1]] == " " {j += 1}
					if space == 0 ||
					   j == len(bounds) - 1 ||
					   !text.text_wrap_boundary(part, bounds, space) ||
					   !text.text_wrap_boundary(part, bounds, j) {continue}
					candidate, ce := rich_measure_range(
						b,
						start,
						start + bounds[space],
						false,
						metrics,
						a,
					); if ce.code != .None {return ce}
					fits := rich_line_fits(
						candidate,
						width,
						origin,
						scale,
						b.options.horizontal,
					); rich_free_line(candidate, a)
					if fits {chosen, next = start + bounds[space], start + bounds[j]}
				}
				reason = .Soft_Space
				if chosen < 0 {
					reason = .Emergency; first := end
					for k in 1 ..< len(bounds) {
						if !text.text_wrap_boundary(part, bounds, k) {continue}
						p := start + bounds[k]; first = min(first, p)
						candidate, ce := rich_measure_range(
							b,
							start,
							p,
							false,
							metrics,
							a,
						); if ce.code != .None {return ce}
						fits := rich_line_fits(
							candidate,
							width,
							origin,
							scale,
							b.options.horizontal,
						); rich_free_line(candidate, a)
						if fits {chosen = p}
					}
					if chosen < 0 {chosen = first}; next = chosen
				}
			}
			line, le := rich_measure_range(
				b,
				start,
				chosen,
				false,
				metrics,
				a,
			); if le.code != .None {return le}
			line.break_reason = reason
			if _, ae := append(&b.lines, line);
			   ae != nil {rich_free_line(line, a); return {code = .Allocation}}
			if len(b.lines) > 4096 {return {code = .Rich_Limit_Exceeded, reason = "natural lines"}}
			if next == end {break}; start = next
		}
		if end + 1 < len(value) && value[end] == '\r' && value[end + 1] == '\n' {end += 1}
		paragraph = end + 1
	}
	b.natural_extent = {}
	for line in b.lines {b.natural_extent.w = max(b.natural_extent.w, line.width); b.natural_extent.h += line.ascent + line.descent + line.gap}
	if !base.finite_nonnegative(b.natural_extent.h) {return {code = .Invalid_Geometry}}
	return {}
}
destroy_rich_block :: proc(b: ^Rich_Block, a: mem.Allocator) {
	for v in b.coverage {delete(v.resource, a)}; delete(b.coverage, a)
	for v in b.font_chains {delete(v.style.font_id, a); for id in v.resources {delete(id, a)}; delete(v.resources, a)}; delete(b.font_chains, a)
	for line in b.lines {rich_free_line(line, a)}; delete(b.lines)
	destroy_rich_document(&b.document)
}
rich_free_line :: proc(line: Rich_Line, a: mem.Allocator) {for f in line.fragments {delete(
			f.metrics.revision,
			a,
		)}
	delete(line.fragments)}
