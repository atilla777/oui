package ui_collections

import layout "../ui_layout"
import "core:testing"

@(test)
ordinary_materialization_preserves_virtual_leading_space :: proc(t: ^testing.T) {
	items := [6]Collection_Item {
		{"a", "A", true, true, ""},
		{"b", "B", true, true, ""},
		{"c", "C", true, true, ""},
		{"d", "D", true, true, ""},
		{"e", "E", true, true, ""},
		{"f", "F", true, true, ""},
	}
	d := fixture_description(items[:]); d.mode = .Grid; d.card_width = 10
	f, e := prepare_collection(d, {w = 24, h = 10}, 12)
	defer destroy_frame(&f)
	if !testing.expect(t, e.code == .None) {return}
	nodes, me := materialize(&f); defer destroy_nodes(nodes)
	if !testing.expect(t, me.code == .None && len(nodes) == 3) {return}
	testing.expect(t, nodes[0].role == layout.Kind.Row && nodes[0].layout.?.margin.top == 12)
	testing.expect(t, nodes[1].id == f.nodes[0].description.id && nodes[1].parent == nodes[0].id)
	testing.expect(t, content_layout(&f).y.min == 34)
}
