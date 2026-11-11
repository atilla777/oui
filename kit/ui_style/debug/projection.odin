package ui_style_debug
import style ".."
import base "../../ui_base"
import debug "../../ui_debug"
import "core:mem"
project_node :: proc(f: ^style.Frame, n: ^debug.Wire_Node, a: mem.Allocator) -> bool {
	for &p in f.presentation {if p.id == n.resolved.description.id {
			n.presentation = debug.Encoded_Value(
				debug.encode(p, a),
			); if n.presentation == nil {return false}; n.selected = .Selected in p.states
			s := &n.resolved.style
			if v, ok := p.computed[.Foreground].value.(base.Color); ok {s.foreground = v}
			if v, ok := p.computed[.Background].value.(base.Color); ok {s.background = v}
			if v, ok := p.computed[.Border].value.(base.Color); ok {s.border = v}
			if v, ok := p.computed[.Font_Size].value.(f64); ok {s.font_size = v}
			if v, ok := p.computed[.Border_Width].value.(f64); ok {s.border_width = v}
			if v, ok := p.computed[.Focus_Width].value.(f64); ok {s.focus_width = v}
			return true
		}}
	return true
}
project_frame :: proc(
	f: ^style.Frame,
	m: ^debug.Frame_Metadata,
) {m.theme_revision, m.resource_revision = f.theme_revision, f.resource_revision
	m.theme_provenance = len(f.presentation) > 0}
