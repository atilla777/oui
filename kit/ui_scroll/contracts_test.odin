package ui_scroll

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:testing"

fixture :: proc(
	t: ^testing.T,
	p: ^base.Publication,
	a: mem.Allocator,
	height: f64 = 40,
) -> (
	layout.Frame,
	interaction.Frame,
) {
	stamp, _ := base.begin_attempt(p, 1)
	nodes := [5]layout.Node {
		{
			id = "scroll",
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = height},
			},
		},
		{
			id = "content",
			parent = "scroll",
			role = .Column,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fixed, value = 100}, y = {mode = .Content}},
		},
		{
			id = "a",
			parent = "content",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 30},
			},
		},
		{
			id = "b",
			parent = "content",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 30},
			},
		},
		{
			id = "c",
			parent = "content",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 30},
			},
		},
	}
	g, e := layout.prepare(
		nodes[:],
		{drawable = {100, 100}, ui_scale = 1},
		{},
		a,
		stamp,
	); testing.expect(t, e.code == .None)
	targets := [3]interaction.Target {
		{"a", "button", true, true},
		{"b", "button", true, true},
		{"c", "button", true, true},
	}
	i, code := interaction.prepare(
		&g,
		targets[:],
		nil,
		a,
	); testing.expect(t, code == .Applied); return g, i
}

@(test)
candidate_refuses_wrong_owner_new_attempt_and_intervening_pending_action :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	other, _ := base.create(context.allocator); defer base.destroy(&other)
	s := create(context.allocator); defer destroy(&s)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	g, i := fixture(
		t,
		&p,
		context.allocator,
	); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&i)
	ds := [1]Description{{"scroll", "content"}}
	c, e := prepare(&s, &g, &i, ds[:], context.allocator); defer destroy_candidate(&c)
	if !testing.expect(t, e.code == .None && validate_candidate(&p, &s, &c)) {return}
	testing.expect(t, !validate_candidate(&other, &s, &c))
	foreign_state := create(context.allocator); defer destroy(&foreign_state)
	testing.expect(
		t,
		!validate_candidate(&p, &foreign_state, &c),
		"candidate belongs to one family State",
	)
	base.enter_commit(&p, g.stamp); interaction.commit(&ctx, &i); base.finish_commit(&p, g.stamp)
	// Borrow the fixture's frozen metadata only during dispatch; c remains its
	// sole allocation owner. This isolates the technical-version guard.
	s.frame = c.frame
	r := dispatch(&s, &ctx, {kind = .Scroll_By, id = "scroll", source = .Agent, delta_y = 5})
	s.frame = {}
	testing.expect(t, r.code == .Applied && s.has_pending)
	testing.expect(
		t,
		!validate_candidate(&p, &s, &c),
		"pending action cannot be lost by committing an earlier candidate",
	)
	base.begin_attempt(&p, 2); testing.expect(t, !validate_candidate(&p, &s, &c))
}

@(test)
validation_rejects_extra_content_and_viewport_relative_rows :: proc(t: ^testing.T) {
	for variant in 0 ..< 4 {
		p, _ := base.create(context.allocator)
		g, i := fixture(t, &p, context.allocator)
		owned_parent := g.nodes[2].description.parent
		s := create(context.allocator)
		switch variant {
		case 0:
			g.nodes[2].description.parent = "scroll" // second direct child
		case 1:
			l := g.nodes[2].description.layout.?; l.y.mode = .Fill
			g.nodes[2].description.layout = l
		case 2:
			l := g.nodes[1].description.layout.?; l.shrink = 1; g.nodes[1].description.layout = l
		case 3:
			l := g.nodes[1].description.layout.?; l.y.mode = .Percent; l.y.value = 1
			g.nodes[1].description.layout = l
		}
		ds := [1]Description{{"scroll", "content"}}
		c, e := prepare(&s, &g, &i, ds[:], context.allocator)
		testing.expect(t, e.code == .Invalid_Scroll && c.geometry.nodes == nil)
		destroy_candidate(&c)
		// Restore changed borrowed-looking parent to its original owning bytes.
		if variant == 0 {g.nodes[2].description.parent = owned_parent}
		destroy(&s); interaction.destroy_frame(&i); layout.destroy_frame(&g); base.destroy(&p)
	}
}

@(test)
natural_vertical_overflow_is_not_a_diagnostic_but_horizontal_remains :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	g, i := fixture(
		t,
		&p,
		context.allocator,
	); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&i)
	s := create(context.allocator); defer destroy(&s)
	ds := [1]Description{{"scroll", "content"}}
	c, e := prepare(&s, &g, &i, ds[:], context.allocator); defer destroy_candidate(&c)
	if !testing.expect(t, e.code == .None) {return}
	testing.expect(
		t,
		len(c.geometry.diagnostics) == 0,
		"natural scroll extent must not report vertical overflow",
	)
	// The family must not erase an independently addressed horizontal oracle.
	append(
		&g.diagnostics,
		layout.Diagnostic {
			kind = .Container_Overflow,
			id = "scroll",
			required = {120, 90},
			available = {100, 40},
		},
	)
	destroy_candidate(&c); c, e = prepare(&s, &g, &i, ds[:], context.allocator)
	testing.expect(
		t,
		e.code == .None &&
		len(c.geometry.diagnostics) == 1 &&
		c.geometry.diagnostics[0].required.w == 120,
		fmt.tprintf("error=%v diagnostics=%v", e, c.geometry.diagnostics),
	)
}

@(test)
common_availability_precedes_value_validation_and_invalid_inputs_are_atomic :: proc(
	t: ^testing.T,
) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s := create(context.allocator); defer destroy(&s)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	ids := [3]string{"a", "b", "c"}; if !publish(t, &p, &ctx, &s, ids[:], "a") {return}
	n, _ := interaction.find(&ctx.frame, "scroll"); n.availability = .Blocked_By_Modal
	r := dispatch(
		&s,
		&ctx,
		{kind = .Scroll_By, id = "scroll", source = .Agent, delta_y = math.QNAN_F64},
	)
	testing.expect(t, r.code == .Blocked_By_Modal && p.ready && !s.has_pending)
	n.availability = .Applied
	for value in ([]f64{math.QNAN_F64, math.INF_F64, -math.INF_F64}) {r = dispatch(&s, &ctx, {kind = .Scroll_By, id = "scroll", source = .Agent, delta_y = value}); testing.expect(t, r.code == .Invalid_Action && p.ready && !s.has_pending)}
	r = dispatch(
		&s,
		&ctx,
		{kind = Action_Kind(99), source = .Agent},
	); testing.expect(t, r.code == .Invalid_Action && p.ready)
}
