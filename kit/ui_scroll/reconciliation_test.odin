package ui_scroll

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:testing"

// One typed publication owner. Layout runs once; scroll transforms an owning
// copy before interaction is finally frozen. No second focus manager.
publish :: proc(
	t: ^testing.T,
	p: ^base.Publication,
	ctx: ^interaction.Context,
	s: ^State,
	ids: []string,
	focus: string = "",
) -> bool {
	stamp, _ := base.begin_attempt(p, 1)
	nodes := make([]layout.Node, 2 + len(ids)); defer delete(nodes)
	nodes[0] = {
		id = "scroll",
		role = .Stack,
		enabled = true,
		visible = true,
		layout = layout.Layout{x = {mode = .Fixed, value = 100}, y = {mode = .Fixed, value = 40}},
	}
	nodes[1] = {
		id = "content",
		parent = "scroll",
		role = .Column,
		enabled = true,
		visible = true,
		layout = layout.Layout{x = {mode = .Fixed, value = 100}, y = {mode = .Content}},
	}
	targets := make([]interaction.Target, len(ids)); defer delete(targets)
	for id, k in ids {nodes[k + 2] = {
			id = id,
			parent = "content",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 30},
			},
		}; targets[k] = {id, "button", true, true}}
	g, e := layout.prepare(
		nodes,
		{drawable = {100, 100}, ui_scale = 1},
		{},
		context.allocator,
		stamp,
	); defer layout.destroy_frame(&g)
	if !testing.expect(t, e.code == .None) {return false}
	i, code := interaction.prepare(
		&g,
		targets,
		nil,
		context.allocator,
	); defer interaction.destroy_frame(&i)
	if !testing.expect(t, code == .Applied) {return false}
	ds := [1]Description{{"scroll", "content"}}
	c, error := prepare(
		s,
		&g,
		&i,
		ds[:],
		context.allocator,
		ctx.focus_id,
	); defer destroy_candidate(&c)
	if !testing.expect(t, error.code == .None && validate_candidate(p, s, &c)) {return false}
	final, fc := interaction.prepare(
		&c.geometry,
		targets,
		nil,
		context.allocator,
	); defer interaction.destroy_frame(&final)
	if !testing.expect(t, fc == .Applied) {return false}
	desired := focus; if c.has_focus {desired = c.focus_id}
	if !testing.expect(t, base.enter_commit(p, stamp) == .None) {return false}
	interaction.commit(ctx, &final)
	if focus != "" || c.has_focus {ctx.focus_id = interaction.retained_id(&ctx.frame, desired)}
	commit(s, &c); base.finish_commit(p, stamp); interaction.reconcile_registrations(ctx)
	return true
}

@(test)
anchor_and_focus_use_old_order_then_clamp_and_never_wrap :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	ids := [3]string{"a", "b", "c"}
	if !publish(t, &p, &ctx, &s, ids[:], "b") {return}
	dispatch(&s, &ctx, {kind = .Scroll_By, id = "scroll", source = .Agent, delta_y = 35})
	if !publish(t, &p, &ctx, &s, ids[:]) {return}
	testing.expect(
		t,
		s.frame.regions[0].offset == 35 &&
		s.frame.regions[0].anchor_id == "b" &&
		s.frame.regions[0].intra_offset == 5,
	)
	ids = {"b", "a", "c"}; if !publish(t, &p, &ctx, &s, ids[:]) {return}
	testing.expect(
		t,
		s.frame.regions[0].offset == 5 && ctx.focus_id == "b",
		"reorder preserves anchor b+5, not numeric offset",
	)
	ids = {"c", "a", ""}; if !publish(t, &p, &ctx, &s, ids[:2]) {return}
	testing.expect(
		t,
		ctx.focus_id == "a" && s.frame.regions[0].offset == 20,
		"deleted b falls forward to a in OLD order, then clamp",
	)
	dispatch(
		&s,
		&ctx,
		{kind = .Move_Item, source = .Agent},
	); publish(t, &p, &ctx, &s, ids[:2]); testing.expect(t, ctx.focus_id == "a")
	dispatch(
		&s,
		&ctx,
		{kind = .Move_Item, source = .Agent, backwards = true},
	); publish(t, &p, &ctx, &s, ids[:2]); testing.expect(t, ctx.focus_id == "c")
	publish(
		t,
		&p,
		&ctx,
		&s,
		nil,
	); testing.expect(t, ctx.focus_id == "" && s.frame.regions[0].offset == 0 && s.frame.regions[0].anchor_id == "")
}

@(test)
insert_above_anchor_preserves_partial_offset_without_focus_reveal :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	ids := [3]string{"a", "b", "c"}; if !publish(t, &p, &ctx, &s, ids[:], "a") {return}
	dispatch(
		&s,
		&ctx,
		{kind = .Scroll_By, id = "scroll", source = .Agent, delta_y = 35},
	); publish(t, &p, &ctx, &s, ids[:])
	inserted := [4]string{"new", "a", "b", "c"}; publish(t, &p, &ctx, &s, inserted[:])
	testing.expect(
		t,
		ctx.focus_id == "a" &&
		s.frame.regions[0].offset == 65 &&
		s.frame.regions[0].anchor_id == "b" &&
		s.frame.regions[0].intra_offset == 5,
	)
}
