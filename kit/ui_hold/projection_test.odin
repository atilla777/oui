package ui_hold

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:mem"
import "core:strings"
import "core:testing"

@(test)
all_rebuild_cancellations_are_projected_until_commit_and_completed_latch_is_not_cancelled :: proc(
	t: ^testing.T,
) {
	for reason in ([]Cancel_Reason{.Removed, .Unavailable, .Mode_Changed, .Threshold_Changed, .UI_Focus_Lost}) {
		p, _ := base.create(
			context.allocator,
		); ctx := interaction.create(context.allocator, &p); s := create(context.allocator)
		publish(
			t,
			&p,
			&ctx,
			&s,
		); dispatch(&s, &ctx, {kind = .Begin, id = "confirm", source = .Agent}); publish(t, &p, &ctx, &s)
		g, i := geometry(t, &p)
		hs := [1]Description{{"confirm", 500}}; descriptions := hs[:]
		n, _ := interaction.find(&i, "confirm")
		#partial switch reason {
		case .Removed:
			delete(n.description.id, i.allocator); n.description.id = ""; descriptions = nil
		case .Unavailable:
			n.availability = .Blocked_By_Modal
		case .Mode_Changed:
			descriptions = nil
		case .Threshold_Changed:
			hs[0].threshold_ms = 600
		case .UI_Focus_Lost:
			ctx.focus_id = ""
		case:
		}
		c, e := prepare(&s, &ctx, &g, &i, nil, descriptions, context.allocator)
		if testing.expect(t, e.code == .None) {
			testing.expect(
				t,
				s.live.phase == .Holding &&
				c.frame.hold.phase == .Idle &&
				c.frame.result.count == 1 &&
				c.frame.result.signals[0].reason == reason &&
				p.sequence == 0,
			)
			commit(
				&s,
				&c,
			); testing.expect(t, s.live.phase == .Idle && s.last_result.signals[0].reason == reason)
		}
		destroy_candidate(
			&c,
		); layout.destroy_frame(&g); interaction.destroy_frame(&i); destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	}
	for reason in ([]Cancel_Reason{.Pointer_Left, .Window_Hidden, .Explicit}) {
		p, _ := base.create(
			context.allocator,
		); ctx := interaction.create(context.allocator, &p); s := create(context.allocator)
		publish(
			t,
			&p,
			&ctx,
			&s,
		); dispatch(&s, &ctx, {kind = .Begin, id = "confirm", source = .Agent}); publish(t, &p, &ctx, &s); dispatch(&s, &ctx, {kind = .Advance, duration_ms = 500}); publish(t, &p, &ctx, &s)
		r := dispatch(
			&s,
			&ctx,
			{kind = .Cancel, reason = reason},
		); testing.expect(t, r.count == 0 && s.live.phase == .Completed_Waiting_Release && p.sequence == 1 && p.ready)
		destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	}
}

@(test)
binding_allocation_failures_and_capture_conflict_are_transactional :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	g, i := geometry(t, &p); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&i)
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	tracking.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	fault := Fault {
		backing = mem.tracking_allocator(&tracking),
	}; a := mem.Allocator{fault_alloc, &fault}
	// Two ordinary targets force allocation failure after the first staged binding.
	delete(i.targets[0].description.role, i.allocator)
	i.targets[0].description.role = strings.clone("button", i.allocator)
	hs := [2]Description{{"root", 500}, {"confirm", 500}}
	for pos in 1 ..= 2 {
		fault.count, fault.refuse = 0, pos; old := i.allocator; i.allocator = a
		c, e := prepare(&s, &ctx, &g, &i, nil, hs[:], context.allocator)
		i.allocator = old; destroy_candidate(&c)
		testing.expect(
			t,
			e.code == .Allocation &&
			tracking.current_memory_allocated == 0 &&
			len(tracking.bad_free_array) == 0,
		)
		for n in i.targets {testing.expect(t, n.activation_owner == "")}
	}
	targets := [1]interaction.Target{{"confirm", "button", true, true}}
	claims := [2]interaction.Capture_Claim{{"confirm", "hold"}, {"confirm", "gesture"}}
	bad, code := interaction.prepare(
		&g,
		targets[:],
		claims[:],
		context.allocator,
	); defer interaction.destroy_frame(&bad)
	testing.expect(t, code == .Conflict && bad.targets == nil)
}

@(test)
stable_rebuilds_release_readers_and_failed_rebuild_never_replays_completion :: proc(
	t: ^testing.T,
) {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	tracking.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	previous :=
		context.allocator; context.allocator = mem.tracking_allocator(&tracking); defer {context.allocator = previous}
	p, _ := base.create(
		context.allocator,
	); ctx := interaction.create(context.allocator, &p); s := create(context.allocator)
	publish(
		t,
		&p,
		&ctx,
		&s,
	); dispatch(&s, &ctx, {kind = .Begin, id = "confirm", source = .Agent}); publish(t, &p, &ctx, &s); dispatch(&s, &ctx, {kind = .Advance, duration_ms = 500}); publish(t, &p, &ctx, &s)
	live := tracking.current_memory_allocated
	for _ in 0 ..< 64 {publish(t, &p, &ctx, &s); testing.expect(t, tracking.current_memory_allocated == live && p.sequence == 1 && s.live.phase == .Completed_Waiting_Release)}
	base.begin_attempt(&p, 9)
	testing.expect(
		t,
		dispatch(&s, &ctx, {kind = .Advance, duration_ms = 500}).code == .Not_Ready &&
		p.sequence == 1,
	)
	publish(
		t,
		&p,
		&ctx,
		&s,
	); testing.expect(t, !dispatch(&s, &ctx, {kind = .Advance, duration_ms = 500}).dispatch.has_event && p.sequence == 1)
	r, ok := try_copy_frame(&s.frame, context.allocator); testing.expect(t, ok)
	destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	if ok {testing.expect(t, r.result.dispatch.has_event && r.result.dispatch.event.id == "confirm" && !r.stamp.lifetime.alive)}
	destroy_frame(
		&r,
	); testing.expect(t, tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
}
