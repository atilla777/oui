package ui_scroll

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:testing"

@(test)
viewport_scroll_gate_does_not_make_a_new_focus_or_activation_target :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	g, i := fixture(
		t,
		&p,
		context.allocator,
	); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&i)
	interaction.destroy_frame(&i)
	targets := [3]interaction.Target {
		{"a", "button", true, true},
		{"b", "button", true, true},
		{"c", "button", true, true},
	}
	code: interaction.Code; i, code = interaction.prepare(&g, targets[:], nil, context.allocator); testing.expect(t, code == .Applied)
	s := create(context.allocator); defer destroy(&s)
	ds := [1]Description{{"scroll", "content"}}
	c, e := prepare(
		&s,
		&g,
		&i,
		ds[:],
		context.allocator,
	); defer destroy_candidate(&c); if !testing.expect(t, e.code == .None) {return}
	_, hit := hit_test(
		&c.frame,
		&c.geometry,
		&i,
		10,
		10,
	); testing.expect(t, hit, "structural scroll region need not be a focus/activation target")
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	base.enter_commit(
		&p,
		g.stamp,
	); interaction.commit(&ctx, &i, "c"); commit(&s, &c); base.finish_commit(&p, g.stamp)
	testing.expect(
		t,
		interaction.dispatch(&ctx, {.Activate, "scroll", .Agent, false}).code == .Invalid_Action &&
		p.ready,
	)
	r := dispatch(&s, &ctx, {kind = .Scroll_By, id = "scroll", source = .Agent, delta_y = 5})
	testing.expect(t, r.code == .Applied && !p.ready)
}
