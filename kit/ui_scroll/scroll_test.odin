package ui_scroll

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:testing"

@(test)
prepare_owns_scrolled_geometry_and_clamps_offset :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	stamp, _ := base.begin_attempt(&p, 1)
	nodes := [4]layout.Node {
		{
			id = "viewport",
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 20},
			},
		},
		{
			id = "content",
			parent = "viewport",
			role = .Column,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fixed, value = 100}, y = {mode = .Content}},
		},
		{
			id = "one",
			parent = "content",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 20},
			},
		},
		{
			id = "two",
			parent = "content",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 20},
			},
		},
	}
	g, e := layout.prepare(
		nodes[:],
		{drawable = {100, 40}, ui_scale = 1},
		{},
		context.allocator,
		stamp,
	)
	if !testing.expect(t, e.code == .None) {return}; defer layout.destroy_frame(&g)
	targets := [3]interaction.Target {
		{"viewport", "scroll", true, true},
		{"one", "button", true, true},
		{"two", "button", true, true},
	}
	i, code := interaction.prepare(
		&g,
		targets[:],
		nil,
		context.allocator,
	); defer interaction.destroy_frame(&i)
	testing.expect(t, code == .Applied)
	s := create(context.allocator); defer destroy(&s)
	descriptions := [1]Description{{"viewport", "content"}}
	c, error := prepare(&s, &g, &i, descriptions[:], context.allocator)
	if !testing.expect(
		t,
		error.code == .None,
		"vertical scroll preparation must succeed",
	) {return}; defer destroy_candidate(&c)
	testing.expect(t, c.frame.regions[0].extent == 40 && c.frame.regions[0].max_offset == 20)
	commit(&s, &c)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	base.enter_commit(
		&p,
		stamp,
	); interaction.commit(&ctx, &i, "one"); base.finish_commit(&p, stamp)
	r := dispatch(&s, &ctx, {kind = .Scroll_By, id = "viewport", source = .Agent, delta_y = 99})
	testing.expect(t, r.code == .Applied && !p.ready)
	stamp, _ = base.begin_attempt(
		&p,
		2,
	); g.stamp.attempt = stamp.attempt; g.stamp.model_revision = stamp.model_revision
	i, code = interaction.prepare(&g, targets[:], nil, context.allocator)
	c, error = prepare(&s, &g, &i, descriptions[:], context.allocator)
	if !testing.expect(t, error.code == .None) {return}
	region := c.frame.regions[0]
	n, _ := layout.find(&c.geometry, "two")
	testing.expect(
		t,
		region.offset == 20 &&
		region.anchor_id == "two" &&
		n.bounds.y == 0 &&
		n.paint_clip.h == 20,
	)
	original, _ := layout.find(
		&g,
		"two",
	); testing.expect(t, original.bounds.y == 20, "input geometry is not mutated")
	commit(&s, &c)
	c, error = prepare(&s, &g, &i, descriptions[:], context.allocator)
	if !testing.expect(t, error.code == .None) {return}
	testing.expect(
		t,
		c.frame.regions[0].offset == 20,
		"offset survives a rebuild without replaying its command",
	)
	destroy_candidate(&c)
	base.enter_commit(
		&p,
		stamp,
	); interaction.commit(&ctx, &i, "one"); base.finish_commit(&p, stamp)
	r = dispatch(&s, &ctx, {kind = .Move_Item, source = .Agent})
	testing.expect(
		t,
		r.code == .Applied,
		"Move_Item resolves from shared focus without an explicit ID",
	)
	i, code = interaction.prepare(&g, targets[:], nil, context.allocator)
	c, error = prepare(&s, &g, &i, descriptions[:], context.allocator)
	if !testing.expect(t, error.code == .None) {return}
	testing.expect(t, c.focus_id == "two" && c.frame.regions[0].offset == 20)
}
