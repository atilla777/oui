package ui_rich

import "core:mem"
import "core:strings"
rich_resolve_resources :: proc(
	b: ^Rich_Block,
	m: Rich_Text_Metrics,
	a: mem.Allocator,
) -> Rich_Error {
	chains := make([dynamic]Rich_Chain_View, 0, 0, a)
	coverage := make([dynamic]Rich_Coverage, 0, 0, a)
	defer {b.font_chains = chains[:]; b.coverage = coverage[:]}
	styles := make([dynamic]Rich_Style, 0, 0, a); defer delete(styles)
	if _, ae := append(&styles, b.base_style); ae != nil {return {code = .Allocation}}
	for run in b.document.runs {if run.image_id == "" {
			found := false; for style in styles {if style == run.style {found = true; break}}
			if !found {if _, ae := append(&styles, run.style); ae != nil {return {code = .Allocation}}}
		}}
	if m.font_chain != nil {for style in styles {
			ids := m.font_chain(style, m.user)
			if len(ids) == 0 ||
			   len(ids) > 4 {return {code = .Resource_Missing, reason = "font chain/variant"}}
			if _, ae := append(&chains, Rich_Chain_View{}); ae != nil {return {code = .Allocation}}
			v := &chains[len(chains) - 1]; v.style = style; v.style.font_id = ""
			ae: mem.Allocator_Error
			v.style.font_id, ae = strings.clone(
				style.font_id,
				a,
			); if ae != nil {return {code = .Allocation}}
			v.resources, ae = make(
				[]string,
				len(ids),
				a,
			); if ae != nil {return {code = .Allocation}}
			for id, index in ids {v.resources[index], ae = strings.clone(id, a); if ae != nil {return {code = .Allocation}}}
		}}
	if m.coverage != nil {for run in b.document.runs {
			if run.image_id != "" {continue}
			for scalar, offset in b.document.decoded[run.decoded_range.start:run.decoded_range.end] {
				if scalar == '\r' || scalar == '\n' {continue}
				resource := m.coverage(scalar, run.style, m.user)
				ds :=
					run.decoded_range.start +
					offset; source := run.source_range; decoded := Text_Source_Range{ds, ds}
				for mapping in b.document.mappings {if mapping.decoded_range.start == ds {source, decoded = mapping.source_range, mapping.decoded_range; break}}
				if resource ==
				   "" {return {code = .Glyph_Missing, source_range = source, reason = "no supplied font covers scalar"}}
				owned, ae := strings.clone(resource, a); if ae != nil {return {code = .Allocation}}
				if _, ce := append(&coverage, Rich_Coverage{decoded, source, owned});
				   ce != nil {delete(owned, a); return {code = .Allocation}}
			}
		}}
	return {}
}
