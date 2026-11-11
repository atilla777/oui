package ui_hold

import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"

Observer :: struct {
	t:               ^testing.T,
	s:               ^State,
	ctx:             ^interaction.Context,
	calls, disposed: int,
}
handler :: proc(d: interaction.Delivery, user: rawptr) -> interaction.Propagation {
	o := cast(^Observer)user; o.calls += 1
	testing.expect(
		o.t,
		d.sequence == 1 &&
		d.target_id == "confirm" &&
		o.s.live.phase == .Completed_Waiting_Release &&
		o.s.last_result.count == 2,
	)
	r := dispatch(o.s, o.ctx, {kind = .Advance, duration_ms = 500})
	testing.expect(
		o.t,
		r.code == .Not_Ready &&
		r.count == 0 &&
		!r.dispatch.has_event &&
		o.ctx.publication.sequence == 1,
	)
	return .Continue
}
disposed :: proc(user: rawptr) {o := cast(^Observer)user; o.disposed += 1; testing.expect(
		o.t,
		o.ctx.busy,
	)}

@(test)
each_source_routes_completion_once_and_never_bypasses_owned_activation :: proc(t: ^testing.T) {
	for source in interaction.Source {
		p, _ := base.create(
			context.allocator,
		); ctx := interaction.create(context.allocator, &p); s := create(context.allocator)
		publish(t, &p, &ctx, &s)
		o := Observer{t, &s, &ctx, 0, 0}
		token, code := interaction.register_handler(
			&ctx,
			"confirm",
			handler,
			&o,
			disposed,
		); testing.expect(t, code == .Applied)
		for _ in 0 ..< 2 {testing.expect(t, interaction.dispatch_routed(&ctx, {.Activate, "confirm", source, false}).code == .Activation_Required && p.sequence == 0)}
		r := dispatch(
			&s,
			&ctx,
			{kind = .Begin, id = "confirm", source = source},
		); testing.expect(t, r.count == 1 && s.live.cycle == 1)
		publish(t, &p, &ctx, &s)
		r = dispatch(
			&s,
			&ctx,
			{kind = .Begin, id = "confirm", source = source},
		); testing.expect(t, r.count == 0 && s.live.cycle == 1 && p.ready)
		r = dispatch(
			&s,
			&ctx,
			{kind = .Advance, duration_ms = 499},
		); testing.expect(t, r.count == 1 && s.live.elapsed_ms == 499 && p.sequence == 0)
		publish(t, &p, &ctx, &s)
		r = dispatch(
			&s,
			&ctx,
			{kind = .Advance, duration_ms = 1},
		); testing.expect(t, r.count == 2 && r.dispatch.has_event && r.dispatch.event.source == source && o.calls == 1 && p.sequence == 1)
		publish(t, &p, &ctx, &s)
		r = dispatch(
			&s,
			&ctx,
			{kind = .Advance, duration_ms = 500},
		); testing.expect(t, r.count == 0 && !r.dispatch.has_event && o.calls == 1)
		r = dispatch(
			&s,
			&ctx,
			{kind = .Begin, id = "confirm", source = source},
		); testing.expect(t, r.count == 0 && s.live.cycle == 1)
		r = dispatch(
			&s,
			&ctx,
			{kind = .Release, source = source},
		); testing.expect(t, r.count == 0 && s.live.phase == .Idle)
		publish(t, &p, &ctx, &s)
		testing.expect(t, interaction.unsubscribe(&ctx, token) == .Applied && o.disposed == 1)
		destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	}
}

@(test)
early_release_and_explicit_cancellation_never_complete_and_invalid_requests_preserve_readiness :: proc(
	t: ^testing.T,
) {
	for reason in Cancel_Reason {
		if reason == .None {continue}
		p, _ := base.create(
			context.allocator,
		); ctx := interaction.create(context.allocator, &p); s := create(context.allocator)
		publish(
			t,
			&p,
			&ctx,
			&s,
		); dispatch(&s, &ctx, {kind = .Begin, id = "confirm", source = .Agent}); publish(t, &p, &ctx, &s)
		r := dispatch(
			&s,
			&ctx,
			{kind = .Release, id = "other", source = .Agent},
		); testing.expect(t, r.code == .Invalid_Action && p.ready && s.live.phase == .Holding)
		r = dispatch(
			&s,
			&ctx,
			{kind = .Cancel, reason = .None},
		); testing.expect(t, r.code == .Invalid_Action && p.ready)
		a := Action {
			kind   = .Cancel,
			reason = reason,
		}; if reason == .Early_Release {a = {
				kind   = .Release,
				source = .Agent,
			}}
		r = dispatch(
			&s,
			&ctx,
			a,
		); testing.expect(t, r.count == 1 && r.signals[0].kind == .Cancelled && r.signals[0].reason == reason && s.live.phase == .Idle && p.sequence == 0 && !p.ready)
		publish(
			t,
			&p,
			&ctx,
			&s,
		); r = dispatch(&s, &ctx, {kind = .Advance, duration_ms = max(i64)}); testing.expect(t, r.count == 0 && p.sequence == 0)
		destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	}
}

@(test)
exhaustion_and_unavailable_readiness_are_atomic :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	publish(t, &p, &ctx, &s); s.live.cycle = max(u64)
	r := dispatch(
		&s,
		&ctx,
		{kind = .Begin, id = "confirm", source = .Agent},
	); testing.expect(t, r.code == .Invalid_Action && s.live.phase == .Idle && p.ready)
	s.live.cycle = 0; dispatch(&s, &ctx, {kind = .Begin, id = "confirm", source = .Agent}); publish(t, &p, &ctx, &s)
	p.sequence = max(
		u64,
	); ctx.frame.stamp.sequence = p.sequence; s.frame.stamp.sequence = p.sequence
	base.finish_commit(&p, ctx.frame.stamp)
	r = dispatch(
		&s,
		&ctx,
		{kind = .Advance, duration_ms = 500},
	); testing.expect(t, r.code == .Invalid_Action && s.live.elapsed_ms == 0 && s.live.phase == .Holding && p.ready)
	base.invalidate(&p)
	for kind in Action_Kind {r = dispatch(&s, &ctx, {kind = kind, source = interaction.Source(99), duration_ms = 500}); testing.expect(t, r.code == .Not_Ready && s.live.phase == .Holding && s.live.elapsed_ms == 0)}
}

@(test)
begin_refuses_missing_activation_binding_without_taking_cycle_or_focus :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	publish(t, &p, &ctx, &s)
	n, _ := interaction.find(
		&ctx.frame,
		"confirm",
	); delete(n.activation_owner, ctx.frame.allocator); n.activation_owner = ""
	r := dispatch(&s, &ctx, {kind = .Begin, id = "confirm", source = .Agent})
	testing.expect(
		t,
		r.code == .Activation_Required &&
		r.count == 0 &&
		s.live.phase == .Idle &&
		s.live.cycle == 0 &&
		p.ready,
	)
}
