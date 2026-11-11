package ui_wire
import base "../ui_base"
import "core:mem"
// Existing v1/v2 DTOs omit layout/rows/columns. Strings borrow the completed
// projection; serialize before destroying its owning captured pair.
Legacy_Node :: struct {
	id, parent, text:          string,
	role:                      Role,
	enabled, visible:          bool,
	width:                     Width,
	fixed_width, padding, gap: f64,
	style:                     Style,
}
Legacy_Resolved_Node :: struct {
	description:                                 Legacy_Node,
	bounds, content, clip, paint_clip:           base.Rect,
	measured:                                    base.Extent,
	style:                                       Style,
	enabled, visible, focused, hovered, pressed: bool,
	availability:                                Code,
}
legacy_node :: proc(n: Resolved_Node) -> Legacy_Resolved_Node {
	d := n.description
	return {
		description = {
			d.id,
			d.parent,
			d.text,
			d.role,
			d.enabled,
			d.visible,
			d.width,
			d.fixed_width,
			d.padding,
			d.gap,
			d.style,
		},
		bounds = n.bounds,
		content = n.content,
		clip = n.clip,
		paint_clip = n.paint_clip,
		measured = n.measured,
		style = n.style,
		enabled = n.enabled,
		visible = n.visible,
		focused = n.focused,
		hovered = n.hovered,
		pressed = n.pressed,
		availability = n.availability,
	}
}
legacy_tree :: proc(nodes: []Resolved_Node, a: mem.Allocator) -> ([]Legacy_Resolved_Node, bool) {
	r, e := make([]Legacy_Resolved_Node, len(nodes), a); if e != nil {return nil, false}
	for n, k in nodes {r[k] = legacy_node(n)}; return r, true
}
