package ui_scroll

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:testing"

@(test)
zero_viewport_is_diagnosed_and_oversize_reveal_keeps_the_item_top :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	g, i := fixture(
		t,
		&p,
		context.allocator,
		0,
	); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&i)
	s := create(context.allocator); defer destroy(&s)
	s.pending = {
		kind   = .Focus,
		id     = "a",
		source = .Agent,
	}; s.has_pending = true
	// This fixture borrows its pending ID rather than allocating it.
	defer {s.pending.id = ""}
	ds := [1]Description{{"scroll", "content"}}
	c, e := prepare(
		&s,
		&g,
		&i,
		ds[:],
		context.allocator,
	); if !testing.expect(t, e.code == .None) {return}; defer destroy_candidate(&c)
	testing.expect(
		t,
		c.frame.regions[0].viewport.h == 0 &&
		c.frame.regions[0].offset == 0 &&
		c.focus_id == "a" &&
		len(c.geometry.diagnostics) > 0,
	)
	_, hit := hit_test(&c.frame, &c.geometry, &i, 0, 0); testing.expect(t, !hit)
}

@(test)
nested_scroll_and_duplicate_descriptions_are_explicitly_refused :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	g, i := fixture(
		t,
		&p,
		context.allocator,
	); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&i)
	s := create(context.allocator); defer destroy(&s)
	ds := [2]Description{{"scroll", "content"}, {"scroll", "content"}}
	c, e := prepare(
		&s,
		&g,
		&i,
		ds[:],
		context.allocator,
	); destroy_candidate(&c); testing.expect(t, e.code == .Invalid_Scroll)
	// Build a valid nested layout tree, not a malformed cyclic geometry probe.
	ids := [5]string{"outer", "outer-content", "inner", "inner-content", "item"}
	parents := [5]string{"", "outer", "outer-content", "inner", "inner-content"}
	nodes: [5]layout.Node
	for id, k in ids {
		role := layout.Kind.Column; if k == 0 || k == 2 {role = .Stack}; if k == 4 {role = .Box}
		nodes[k] = {
			id = id,
			parent = parents[k],
			role = role,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fixed, value = 100}, y = {mode = .Content}},
		}
		if k == 0 || k == 2 {l := nodes[k].layout.?; l.y = {
				mode  = .Fixed,
				value = 40,
			}; nodes[k].layout = l}
	}
	ng, ge := layout.prepare(
		nodes[:],
		{drawable = {100, 100}, ui_scale = 1},
		{},
		context.allocator,
		g.stamp,
	); defer layout.destroy_frame(&ng); if !testing.expect(t, ge.code == .None) {return}
	ni, code := interaction.prepare(
		&ng,
		nil,
		nil,
		context.allocator,
	); defer interaction.destroy_frame(&ni); testing.expect(t, code == .Applied)
	ds = {{"outer", "outer-content"}, {"inner", "inner-content"}}
	c, e = prepare(
		&s,
		&ng,
		&ni,
		ds[:],
		context.allocator,
	); destroy_candidate(&c); testing.expect(t, e.code == .Invalid_Scroll)
}
