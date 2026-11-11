package ui_controls

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:testing"

Observer :: struct {
	t:     ^testing.T,
	s:     ^State,
	ctx:   ^interaction.Context,
	calls: int,
}
observe :: proc(d: interaction.Delivery, user: rawptr) -> interaction.Propagation {return(
		.Continue \
	)}
dispose :: proc(user: rawptr) {
	o := cast(^Observer)user; o.calls += 1
	testing.expect(
		o.t,
		len(o.s.frame.controls) == 0 &&
		o.s.frame.stamp == o.ctx.frame.stamp &&
		base.is_current(o.ctx.publication, o.ctx.frame.stamp) &&
		o.ctx.busy,
		"dispose sees the coherent application/interaction/control swap",
	)
}
@(test)
failed_prepare_keeps_registrations_and_dispose_observes_all_swapped_owners :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(); defer destroy(&s)
	if !publish_fixture(t, &p, &ctx, &s) {return}
	o := Observer{t, &s, &ctx, 0}
	_, code := interaction.register_handler(
		&ctx,
		s.frame.controls[0].node_id,
		observe,
		&o,
		dispose,
	); testing.expect(t, code == .Applied)
	stamp, _ := base.begin_attempt(&p, 2)
	nodes := [1]layout.Node {
		{id = "other", role = .Box, layout = layout.Layout{}, enabled = true, visible = true},
	}
	g, ge := layout.prepare(
		nodes[:],
		{drawable = {100, 100}, ui_scale = 1},
		{},
		context.allocator,
		stamp,
	); defer layout.destroy_frame(&g); testing.expect(t, ge.code == .None)
	targets := [1]interaction.Target{{"other", "button", true, true}}
	i, ic := interaction.prepare(
		&g,
		targets[:],
		nil,
		context.allocator,
	); defer interaction.destroy_frame(&i); testing.expect(t, ic == .Applied)
	bad := [1]Description{{id = "bad", node_id = "missing", kind = .Checkbox}}
	c, e := prepare(&i, {}, bad[:], context.allocator, &g); destroy_candidate(&c)
	testing.expect(
		t,
		e.code == .Invalid_Control && o.calls == 0 && len(ctx.registrations) == 1 && !p.ready,
	)
	c, e = prepare(
		&i,
		{},
		nil,
		context.allocator,
		&g,
	); defer destroy_candidate(&c); testing.expect(t, e.code == .None)
	base.enter_commit(
		&p,
		stamp,
	); interaction.commit(&ctx, &i); commit(&s, &c); base.finish_commit(&p, stamp); interaction.reconcile_registrations(&ctx)
	testing.expect(t, o.calls == 1 && len(ctx.registrations) == 0)
}
