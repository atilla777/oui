package ui_collections

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:testing"

bind_fixture :: proc(
	t: ^testing.T,
	c: ^Candidate,
	bind: bool = true,
) -> (
	layout.Frame,
	interaction.Frame,
	bool,
) {
	mat, me := materialize(&c.frame); defer destroy_nodes(mat)
	if !testing.expect(t, me.code == .None) {return {}, {}, false}
	cs := c.frame.collections[0]
	nodes := make([]layout.Node, 2 + len(mat)); defer delete(nodes)
	nodes[0] = {
		id = cs.description.scroll_id,
		role = .Stack,
		enabled = true,
		visible = true,
		layout = layout.Layout {
			x = {mode = .Fixed, value = cs.viewport.w},
			y = {mode = .Fixed, value = cs.viewport.h},
		},
	}
	nodes[1] = {
		id      = cs.description.content_id,
		parent  = cs.description.scroll_id,
		role    = .Column,
		enabled = true,
		visible = true,
		layout  = content_layout(&c.frame),
	}
	copy(nodes[2:], mat)
	g, ge := layout.prepare(
		nodes,
		{drawable = {cs.viewport.w, cs.viewport.h}, ui_scale = 1},
		{},
		context.allocator,
		c.frame.stamp,
	)
	if !testing.expect(t, ge.code == .None) {return {}, {}, false}
	projected, pe := project_layout(c, &g); layout.destroy_frame(&g)
	if !testing.expect(t, pe.code == .None) {return {}, {}, false}
	targets := make([]interaction.Target, len(c.frame.nodes)); defer delete(targets)
	for n, index in c.frame.nodes {targets[index] = {n.description.id, "button", n.enabled, n.visible}}
	i, ie := interaction.prepare(&projected, targets, nil, context.allocator)
	if !testing.expect(t, ie == .Applied) {layout.destroy_frame(&projected); return {}, {}, false}
	if !bind {return projected, i, true}
	be := bind_candidate(c, &projected, &i)
	return projected, i, testing.expect(t, be.code == .None)
}
@(test)
binding_projects_the_one_virtual_offset_and_checks_actual_targets :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s := create(); defer destroy(&s)
	stamp, _ := base.begin_attempt(&p, 1)
	items := []Collection_Item {
		{"a", "A", true, true, ""},
		{"b", "B", true, true, ""},
		{"c", "C", true, true, ""},
	}
	c, e := prepare(
		&s,
		stamp,
		fixture_description(items),
		{w = 100, h = 10},
		0,
	); defer destroy_candidate(&c)
	if !testing.expect(t, e.code == .None) {return}
	g, i, bound := bind_fixture(
		t,
		&c,
	); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&i)
	if !testing.expect(t, bound) {return}
	testing.expect(t, c.frame.bound && validate_candidate(&p, &s, &c))
	n, found := interaction.find(&i, c.frame.nodes[0].description.id)
	testing.expect(
		t,
		found && n.activation_owner == "collections" && n.bounds == c.frame.nodes[0].bounds,
	)
}
