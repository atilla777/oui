package ui_transitions

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:testing"

@(test)
visual_geometry_matches_inverse_and_preserves_layout :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s := create(); defer destroy(&s)
	stamp, _ := base.begin_attempt(&p, 1)
	c, e := prepare(
		&s,
		stamp,
		[]Description {
			{
				node_id = "button",
				tracks = []Track {
					{property = .Scale, target = f64(.5)},
					{property = .Offset, target = [2]f64{80, 0}},
				},
			},
		},
		{},
		false,
	)
	defer destroy_candidate(&c)
	if !testing.expect(t, e.code == .None) {return}
	nodes := []layout.Node {
		{
			id = "root",
			role = .Absolute,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
		},
		{
			id = "button",
			parent = "root",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 40},
				offset = {20, 20},
			},
		},
	}
	g, ge := layout.prepare(
		nodes,
		{drawable = {300, 200}, ui_scale = 1},
		{},
		context.allocator,
		stamp,
	); defer layout.destroy_frame(&g)
	if !testing.expect(t, ge.code == .None) {return}
	i, ie := interaction.prepare(
		&g,
		[]interaction.Target{{"button", "button", true, true}},
		nil,
		context.allocator,
	); defer interaction.destroy_frame(&i)
	if !testing.expect(t, ie == .Applied) {return}
	be := bind_geometry(&c, &g, &i)
	if !testing.expect(t, be.code == .None) {return}
	v := c.frame.entries[1].geometry
	testing.expect(t, v.bounds == (base.Rect{125, 30, 50, 20}))
	point, valid := base.inverse_point(v, {150, 40})
	testing.expect(t, valid && point == ([2]f64{70, 40}))
	n, _ := layout.find(&g, "button")
	testing.expect(
		t,
		// D1 §2: a Box without content metrics has zero intrinsic extent.
		n.bounds == (base.Rect{20, 20, 100, 40}) && n.measured == (base.Extent{}),
	)
	testing.expect(t, validate_candidate(&p, &s, &c))
	r, copied := try_copy_frame(&c.frame)
	destroy_candidate(&c); destroy(&s); base.destroy(&p)
	defer destroy_frame(&r)
	if !testing.expect(t, copied) {return}
	testing.expect(
		t,
		r.entries[1].id == "button" &&
		r.entries[1].geometry.bounds == (base.Rect{125, 30, 50, 20}),
	)
}

@(test)
hidden_presence_is_projected_before_layout_not_into_source :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s := create(); defer destroy(&s)
	stamp, _ := base.begin_attempt(&p, 1)
	c, e := prepare(
		&s,
		stamp,
		[]Description{{node_id = "card", present = false}},
		{},
		false,
	); defer destroy_candidate(&c)
	if !testing.expect(t, e.code == .None) {return}
	nodes := []layout.Node {
		{id = "card", visible = true},
		{id = "child", parent = "card", visible = true},
	}
	projected, pe := project_nodes(&c, nodes); defer destroy_nodes(projected)
	if !testing.expect(t, pe.code == .None && len(projected) == 2) {return}
	testing.expect(
		t,
		!projected[0].visible && !projected[1].visible && nodes[0].visible && nodes[1].visible,
	)
}
