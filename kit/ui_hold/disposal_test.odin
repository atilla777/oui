package ui_hold

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:mem"
import "core:testing"

Removal_Observer :: struct {
	t:     ^testing.T,
	s:     ^State,
	ctx:   ^interaction.Context,
	calls: int,
}
on_dispose :: proc(user: rawptr) {
	o := cast(^Removal_Observer)user; o.calls += 1
	testing.expect(
		o.t,
		o.ctx.busy &&
		o.s.frame.stamp == o.ctx.frame.stamp &&
		o.s.live.phase == .Idle &&
		o.s.last_result.signals[0].reason == .Mode_Changed,
	)
	testing.expect(
		o.t,
		dispatch(o.s, o.ctx, {kind = .Begin, id = "confirm", source = .Agent}).code == .Not_Ready,
	)
}
noop :: proc(d: interaction.Delivery, user: rawptr) -> interaction.Propagation {return .Continue}

@(test)
failed_prepare_preserves_registration_and_success_disposes_after_coherent_swap :: proc(
	t: ^testing.T,
) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	publish(
		t,
		&p,
		&ctx,
		&s,
	); dispatch(&s, &ctx, {kind = .Begin, id = "confirm", source = .Agent}); publish(t, &p, &ctx, &s)
	o := Removal_Observer {
		t,
		&s,
		&ctx,
		0,
	}; _, code := interaction.register_handler(&ctx, "confirm", noop, &o, on_dispose); testing.expect(t, code == .Applied)
	g, i := geometry(t, &p); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&i)
	bad := [1]Description{{"missing", 500}}
	c, e := prepare(&s, &ctx, &g, &i, nil, bad[:], context.allocator); destroy_candidate(&c)
	testing.expect(
		t,
		e.code == .Invalid_Hold &&
		o.calls == 0 &&
		len(ctx.registrations) == 1 &&
		!p.ready &&
		s.live.phase == .Holding,
	)
	c, e = prepare(
		&s,
		&ctx,
		&g,
		&i,
		nil,
		nil,
		context.allocator,
	); defer destroy_candidate(&c); testing.expect(t, e.code == .None)
	n, _ := interaction.find(
		&i,
		"confirm",
	); delete(n.description.role, i.allocator); n.description.role = ""
	base.enter_commit(
		&p,
		g.stamp,
	); interaction.commit(&ctx, &i); commit(&s, &c); base.finish_commit(&p, g.stamp); interaction.reconcile_registrations(&ctx)
	testing.expect(t, o.calls == 1 && len(ctx.registrations) == 0)
}

@(test)
begin_allocation_failure_keeps_cycle_focus_and_readiness :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	publish(t, &p, &ctx, &s)
	fault := Fault {
		backing = context.allocator,
		refuse  = 1,
	}; s.allocator = mem.Allocator{fault_alloc, &fault}
	r := dispatch(&s, &ctx, {kind = .Begin, id = "confirm", source = .Agent})
	s.allocator = context.allocator
	testing.expect(
		t,
		r.code == .Allocation &&
		r.count == 0 &&
		s.live.phase == .Idle &&
		s.live.cycle == 0 &&
		p.ready &&
		p.sequence == 0 &&
		ctx.focus_id == "confirm",
	)
}
