package ui_hold

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:testing"

publish :: proc(
	t: ^testing.T,
	p: ^base.Publication,
	ctx: ^interaction.Context,
	s: ^State,
) -> bool {
	g, i := geometry(t, p); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&i)
	hs := [1]Description{{"confirm", 500}}
	c, e := prepare(s, ctx, &g, &i, nil, hs[:], context.allocator); defer destroy_candidate(&c)
	if !testing.expect(t, e.code == .None && validate_candidate(p, &c)) {return false}
	stamp :=
		g.stamp; base.enter_commit(p, stamp); interaction.commit(ctx, &i, "confirm"); commit(s, &c); base.finish_commit(p, stamp)
	interaction.reconcile_registrations(ctx); return true
}

@(test)
stale_hold_and_completion_refusals_preserve_live_cycle :: proc(t: ^testing.T) {
	for stale in ([]bool{false, true}) {
		p, _ := base.create(
			context.allocator,
		); ctx := interaction.create(context.allocator, &p); s := create(context.allocator)
		if publish(t, &p, &ctx, &s) {
			dispatch(
				&s,
				&ctx,
				{kind = .Begin, id = "confirm", source = .Agent},
			); publish(t, &p, &ctx, &s)
			if stale {s.frame.stamp.attempt += 1} else {n, _ := interaction.find(&ctx.frame, "confirm"); n.availability = .Disabled}
			r := dispatch(&s, &ctx, {kind = .Advance, duration_ms = 500})
			expected := interaction.Code.Disabled; if stale {expected = .Not_Ready}
			testing.expect(
				t,
				r.code == expected &&
				r.count == 0 &&
				!r.dispatch.has_event &&
				s.live.phase == .Holding &&
				s.live.elapsed_ms == 0 &&
				p.sequence == 0 &&
				p.ready,
				"refused completion must be atomic",
			)
		}
		destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	}
}

@(test)
advance_requires_its_exclusive_activation_binding :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	if !publish(t, &p, &ctx, &s) {return}
	dispatch(&s, &ctx, {kind = .Begin, id = "confirm", source = .Agent}); publish(t, &p, &ctx, &s)
	n, _ := interaction.find(
		&ctx.frame,
		"confirm",
	); delete(n.activation_owner, ctx.frame.allocator); n.activation_owner = ""
	r := dispatch(&s, &ctx, {kind = .Advance, duration_ms = 500})
	testing.expect(
		t,
		r.code == .Activation_Required &&
		r.count == 0 &&
		s.live.phase == .Holding &&
		s.live.elapsed_ms == 0 &&
		p.ready &&
		p.sequence == 0,
	)
}
