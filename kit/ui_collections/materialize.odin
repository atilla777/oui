package ui_collections

import layout "../ui_layout"
import "core:fmt"
import "core:strings"

// The caller installs this on the ordinary Column content node before layout.
// ui_scroll then owns the one offset/translation; this stage never translates it.
content_layout :: proc(f: ^Frame) -> layout.Layout {
	s := f.collections[0]
	return {x = {mode = .Fill}, y = {mode = .Content, min = s.extent}, gap = s.description.gap}
}
destroy_nodes :: proc(nodes: []layout.Node, a := context.allocator) {
	for n in nodes {delete(n.id, a); delete(n.parent, a)}
	delete(nodes, a)
}
materialize :: proc(f: ^Frame, a := context.allocator) -> ([]layout.Node, Update_Error) {
	if len(f.collections) != 1 {return nil, {.Invalid_ID, ""}}
	s := f.collections[0]; d := s.description
	rows := 0
	if d.mode == .Grid &&
	   s.materialized_count >
		   0 {rows = (s.materialized_end - 1) / s.columns - s.materialized_start / s.columns + 1}
	if s.materialized_count > max(int) - rows {return nil, {.Allocation, d.id}}
	nodes, ae := make(
		[]layout.Node,
		s.materialized_count + rows,
		a,
	); if ae != nil {return nil, {.Allocation, d.id}}
	complete := false; defer {if !complete {destroy_nodes(nodes, a)}}
	k := 0; row_id := ""
	for ordinal := s.materialized_start; ordinal < s.materialized_end; ordinal += 1 {
		parent := d.content_id
		l := layout.Layout {
			x = {mode = .Fill},
			y = {mode = .Fixed, value = d.height},
		}
		if d.mode == .Grid {
			if ordinal % s.columns == 0 {
				buffer: [64]u8
				row_id, ae = strings.concatenate(
					[]string {
						d.content_id,
						":collection-row:",
						fmt.bprintf(buffer[:], "%d", ordinal / s.columns),
					},
					a,
				); if ae != nil {return nil, {.Allocation, d.id}}
				nodes[k].id = row_id
				nodes[k].parent, ae = strings.clone(
					d.content_id,
					a,
				); if ae != nil {return nil, {.Allocation, d.id}}
				rl := layout.Layout {
					x = {mode = .Fill},
					y = {mode = .Fixed, value = d.height},
					gap = d.gap,
				}
				if ordinal ==
				   s.materialized_start {rl.margin.top = f64(ordinal / s.columns) * (d.height + d.gap)}
				nodes[k].layout, nodes[k].role, nodes[k].enabled, nodes[k].visible =
					rl, .Row, true, true
				k += 1
			}
			parent = row_id; l.x = {
				mode  = .Fixed,
				value = d.card_width,
			}
		} else if ordinal ==
		   s.materialized_start {l.margin.top = f64(ordinal) * (d.height + d.gap)}
		item := s.data.items[s.data.visible[ordinal]]
		nodes[k].id, ae = item_node_id(
			d.id,
			item.item_id,
			a,
		); if ae != nil {return nil, {.Allocation, d.id}}
		nodes[k].parent, ae = strings.clone(
			parent,
			a,
		); if ae != nil {return nil, {.Allocation, d.id}}
		nodes[k].layout, nodes[k].role, nodes[k].visible, nodes[k].enabled =
			l, .Box, true, item.enabled
		k += 1
	}
	complete = true
	return nodes, {}
}
