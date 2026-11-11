package ui_composition

import base "../ui_base"
import layout "../ui_layout"
import "core:testing"

@(test)
empty_panel_is_a_real_layout_tree :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	stamp, _ := base.begin_attempt(&p, 1)
	c, e := compose_panel("n", "", {}, {}, nil)
	defer destroy(&c)
	if !testing.expect(t, e == .None) {return}
	nodes := make([]layout.Node, len(c.nodes)); defer delete(nodes)
	for n, i in c.nodes {nodes[i] = n.node}
	g, ge := layout.prepare(
		nodes,
		{drawable = {100, 100}, ui_scale = 1},
		{},
		context.allocator,
		stamp,
	)
	defer layout.destroy_frame(&g)
	testing.expect(t, ge.code == .None)
}

@(test)
reject_unknown_duplicate_slots_foreign_parents_cycles_and_colliding_host :: proc(t: ^testing.T) {
	for slots in ([][]Slot{{{name = "unknown"}}, {{name = "title"}, {name = "title"}}, {{name = "content", nodes = []Node{{node = {id = "a", parent = "foreign"}}}}}, {{name = "content", nodes = []Node{{node = {id = "a", parent = "a"}}}}}, {{name = "content", nodes = []Node{{node = {id = "a"}}, {node = {id = "a"}}}}}, {{name = "content", nodes = []Node{{node = {id = ""}}}}}}) {
		c, e := compose_panel("namespace", "host", {}, {}, slots)
		testing.expect(t, e != .None && len(c.nodes) == 0); destroy(&c)
	}
	root, _ := root_id("namespace"); defer delete(root)
	c, e := compose_panel("namespace", root, {}, {}, nil)
	testing.expect(t, e == .Invalid_Tree && len(c.nodes) == 0); destroy(&c)
	a, _ := node_id("a:b", "content", "go"); defer delete(a)
	b, _ := node_id("a", "b:content", "go"); defer delete(b)
	testing.expect(t, a != b)
}

@(test)
panel_namespaces_order_and_owns_input :: proc(t: ^testing.T) {
	c, e := compose_panel(
		"меню",
		"host",
		{},
		{},
		[]Slot {
			{
				name = "footer",
				nodes = []Node{{node = {id = "same", enabled = true, visible = true}}},
			},
			{
				name = "title",
				nodes = []Node{{node = {id = "same", enabled = true, visible = true}}},
			},
		},
	)
	defer destroy(&c)
	if !testing.expect(t, e == .None) {return}
	testing.expect(t, len(c.nodes) == 6)
	testing.expect(t, c.nodes[0].node.parent == "host")
	testing.expect(t, c.nodes[2].node.id != c.nodes[5].node.id)
	testing.expect(t, c.nodes[2].node.parent == c.nodes[1].node.id)
	testing.expect(t, c.nodes[5].node.parent == c.nodes[4].node.id)
}
