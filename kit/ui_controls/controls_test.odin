package ui_controls

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:fmt"
import "core:testing"

@(test)
controlled_bool_and_integer_are_single_guarded_proposals :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	stamp, _ := base.begin_attempt(&p, 1)
	nodes := [3]layout.Node {
		{id = "root", role = .Column, visible = true, enabled = true},
		{id = "check", parent = "root", role = .Box, visible = true, enabled = true},
		{id = "slider", parent = "root", role = .Box, visible = true, enabled = true},
	}
	for &n in nodes {n.layout = layout.Layout {
			x = {mode = .Fixed, value = 100},
			y = {mode = .Fixed, value = 20},
		}}
	g, e := layout.prepare(
		nodes[:],
		{drawable = {100, 100}, ui_scale = 1},
		{},
		context.allocator,
		stamp,
	)
	if !testing.expect(
		t,
		e.code == .None,
		fmt.tprintf("geometry %v %s", e.code, e.id),
	) {return}; defer layout.destroy_frame(&g)
	targets := [2]interaction.Target {
		{"check", "button", true, true},
		{"slider", "button", true, true},
	}
	i, code := interaction.prepare(
		&g,
		targets[:],
		nil,
		context.allocator,
	); testing.expect(t, code == .Applied)
	defer interaction.destroy_frame(&i)
	descriptions := [2]Description {
		{id = "check", node_id = "check", kind = .Checkbox, label = "Check"},
		{
			id = "level",
			node_id = "slider",
			kind = .Slider,
			minimum = 0,
			maximum = 100,
			step = 10,
			value = 50,
		},
	}
	c, error := prepare(&i, {}, descriptions[:], context.allocator)
	if !testing.expect(
		t,
		error.code == .None,
		"valid controlled descriptions prepare",
	) {return}; defer destroy_candidate(&c)
	descriptions[0].label = "mutated"
	testing.expect(t, c.controls[0].label == "Check")
	s := create(); defer destroy(&s)
	commit(&s, &c)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	base.enter_commit(
		&p,
		stamp,
	); interaction.commit(&ctx, &i, "check"); base.finish_commit(&p, stamp)
	r := dispatch(&s, &ctx, {kind = .Activate, id = "check", source = .Agent})
	testing.expect(
		t,
		r.dispatch.has_event &&
		r.event != nil &&
		r.event.?.checked &&
		!s.frame.controls[0].checked,
		"checkbox is a proposal, not a hidden reducer",
	)
	testing.expect(
		t,
		!dispatch(&s, &ctx, {kind = .Activate, id = "check", source = .Agent}).dispatch.has_event,
	)
	ctx.frame.stamp.sequence = p.sequence; base.finish_commit(&p, ctx.frame.stamp)
	// Refreeze the controlled metadata for this fixture's new sequence association.
	next, ne := prepare(&ctx.frame, {}, descriptions[:], context.allocator)
	if !testing.expect(t, ne.code == .None) {return}; commit(&s, &next)
	r = dispatch(&s, &ctx, {kind = .Set_Value, id = "slider", source = .Agent, value = 55})
	testing.expect(t, r.dispatch.code == .Invalid_Action && p.ready)
	r = dispatch(&s, &ctx, {kind = .Adjust, id = "slider", source = .Agent, value = 1})
	testing.expect(t, r.event != nil && r.event.?.value == 60 && s.frame.controls[1].value == 50)
}
