package ui_rich
import base "../ui_base"
import "core:mem"
import "core:strings"
try_copy_frame :: proc(source: ^Frame, a := context.allocator) -> (Frame, bool) {
	if !source.bound {return {}, false}
	f := Frame {
		allocator = a,
		drawable  = source.drawable,
		ui_scale  = source.ui_scale,
	}
	complete := false; defer {if !complete {destroy_frame(&f)}}
	if !base.retain(source.stamp) {return {}, false}; f.stamp = source.stamp
	ae: mem.Allocator_Error
	f.rich_blocks, ae = make(
		[]Rich_Block,
		len(source.rich_blocks),
		a,
	); if ae != nil {return {}, false}
	for b, index in source.rich_blocks {
		r := &f.rich_blocks[index]; r^ = b
		r.node_id, r.base_style.font_id =
			"", ""; r.document = {}; r.lines, r.coverage, r.font_chains = nil, nil, nil
		r.node_id, ae = strings.clone(b.node_id, a); if ae != nil {return {}, false}
		r.base_style.font_id, ae = strings.clone(
			b.base_style.font_id,
			a,
		); if ae != nil {return {}, false}
		document := b.document
		copied: bool; r.document, copied = try_copy_document(&document, a); if !copied {return {}, false}
		r.coverage, ae = make([]Rich_Coverage, len(b.coverage), a); if ae != nil {return {}, false}
		for coverage, j in b.coverage {
			r.coverage[j].decoded_range, r.coverage[j].source_range =
				coverage.decoded_range, coverage.source_range
			r.coverage[j].resource, ae = strings.clone(
				coverage.resource,
				a,
			); if ae != nil {return {}, false}
		}
		r.font_chains, ae = make(
			[]Rich_Chain_View,
			len(b.font_chains),
			a,
		); if ae != nil {return {}, false}
		for chain, j in b.font_chains {
			v := &r.font_chains[j]; v.style = chain.style; v.style.font_id = ""
			v.style.font_id, ae = strings.clone(
				chain.style.font_id,
				a,
			); if ae != nil {return {}, false}
			v.resources, ae = make(
				[]string,
				len(chain.resources),
				a,
			); if ae != nil {return {}, false}
			for id, k in chain.resources {v.resources[k], ae = strings.clone(id, a); if ae != nil {return {}, false}}
		}
		r.lines, ae = make([dynamic]Rich_Line, 0, len(b.lines), a); if ae != nil {return {}, false}
		for line in b.lines {
			v := line; v.fragments = make([dynamic]Rich_Fragment, 0, 0, a)
			if _, le := append(&r.lines, v); le != nil {return {}, false}
			installed := &r.lines[len(r.lines) - 1]
			for fragment in line.fragments {
				copy :=
					fragment; copy.metrics.revision, ae = strings.clone(fragment.metrics.revision, a); if ae != nil {return {}, false}
				if _, fe := append(&installed.fragments, copy);
				   fe != nil {delete(copy.metrics.revision, a); return {}, false}
			}
		}
	}
	f.bound = true; complete = true
	return f, true
}
