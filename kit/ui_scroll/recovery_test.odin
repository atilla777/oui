package ui_scroll

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:testing"

@(test)
pending_delta_survives_failure_but_is_refused_by_new_modal_gate :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	ids := [3]string{"a", "b", "c"}; if !publish(t, &p, &ctx, &s, ids[:], "a") {return}
	dispatch(&s, &ctx, {kind = .Scroll_By, id = "scroll", source = .Agent, delta_y = 35})
	old := s.frame.stamp
	g, i := fixture(
		t,
		&p,
		context.allocator,
	); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&i)
	bad := [1]Description{{"scroll", "missing"}}
	c, e := prepare(&s, &g, &i, bad[:], context.allocator); destroy_candidate(&c)
	testing.expect(
		t,
		e.code == .Invalid_Scroll &&
		s.frame.stamp == old &&
		s.frame.regions[0].offset == 0 &&
		s.has_pending &&
		!p.ready,
	)
	n, _ := interaction.find(&i, "scroll"); n.availability = .Blocked_By_Modal
	ds := [1]Description{{"scroll", "content"}}
	c, e = prepare(&s, &g, &i, ds[:], context.allocator); defer destroy_candidate(&c)
	if !testing.expect(t, e.code == .None) {return}
	testing.expect(
		t,
		c.frame.regions[0].offset == 0,
		"new frozen unavailability rejects an old pending delta",
	)
	testing.expect(t, s.has_pending, "prepare alone never consumes pending input")
}

@(test)
removal_and_disable_reconcile_focus_only_on_successful_publication :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	ids := [3]string{"a", "b", "c"}; if !publish(t, &p, &ctx, &s, ids[:], "b") {return}
	g, i := fixture(
		t,
		&p,
		context.allocator,
	); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&i)
	n, _ := interaction.find(&i, "b"); n.availability = .Disabled
	ds := [1]Description{{"scroll", "content"}}
	c, e := prepare(
		&s,
		&g,
		&i,
		ds[:],
		context.allocator,
		ctx.focus_id,
	); defer destroy_candidate(&c)
	testing.expect(t, e.code == .None && c.has_focus && c.focus_id == "c" && ctx.focus_id == "b")
}
