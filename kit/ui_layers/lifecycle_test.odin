package ui_layers

import base "../ui_base"
import interaction "../ui_interaction"
import "core:fmt"
import "core:mem"
import "core:testing"

Audit :: struct {
	t:                ^testing.T,
	s:                ^State,
	ctx:              ^interaction.Context,
	seen:             [3]string,
	count, disposals: int,
	stop:             bool,
}
audit_route :: proc(d: interaction.Delivery, user: rawptr) -> interaction.Propagation {
	a := cast(^Audit)user; a.seen[a.count] = d.current_id; a.count += 1
	testing.expect(
		a.t,
		d.target_id == "ab" &&
		d.sequence == 1 &&
		a.ctx.busy &&
		a.s.frame.stamp == a.ctx.frame.stamp,
	)
	testing.expect(
		a.t,
		dispatch(a.s, a.ctx, {kind = .Cancel, source = .Agent}).dispatch.code == .Not_Ready,
	)
	if a.stop {return .Stop}; return .Continue
}
audit_dispose :: proc(user: rawptr) {
	a := cast(^Audit)user; a.disposals += 1
	testing.expect(
		a.t,
		a.ctx.busy &&
		len(a.s.frame.layers.modals) == 0 &&
		a.s.frame.stamp == a.ctx.frame.stamp &&
		a.ctx.focus_id == "open",
	)
	testing.expect(
		a.t,
		dispatch(a.s, a.ctx, {kind = .Activate, id = "open", source = .Agent}).dispatch.code ==
		.Not_Ready,
	)
}

@(test)
routing_stop_and_dispose_observe_coherent_swap_and_failed_prepare_keeps_registrations :: proc(
	t: ^testing.T,
) {
	for stop in ([]bool{false, true}) {
		p, _ := base.create(
			context.allocator,
		); ctx := interaction.create(context.allocator, &p); s := create(context.allocator)
		l := Layers {
			base_root_id = "base",
		}; accept_scene(t, &p, &s, &ctx, l)
		ms := [1]Modal{{"a", "ab", true}}; l.modals = ms[:]; accept_scene(t, &p, &s, &ctx, l)
		a := Audit {
			t    = t,
			s    = &s,
			ctx  = &ctx,
			stop = stop,
		}
		for id in ([]string{"ab", "a", "root"}) {_, code := interaction.register_handler(&ctx, id, audit_route, &a); testing.expect(t, code == .Applied)}
		_, code := interaction.register_handler(
			&ctx,
			"ax",
			audit_route,
			&a,
			audit_dispose,
		); testing.expect(t, code == .Applied)
		r := dispatch(&s, &ctx, {kind = .Activate, id = "ab", source = .Agent})
		want := 2; if stop {want = 1}
		testing.expect(
			t,
			r.dispatch.has_event &&
			a.count == want &&
			a.seen[0] == "ab" &&
			(stop || a.seen[1] == "a"),
		)
		bad := Layers {
			base_root_id = "base",
		}; f := scene(t, &p, bad); bad.base_root_id = "missing"
		c, e := prepare(
			&s,
			&ctx,
			&f.g,
			f.targets[:],
			nil,
			bad,
			context.allocator,
		); destroy_candidate(&c); destroy_scene(&f)
		testing.expect(
			t,
			e.code != .None && a.disposals == 0 && len(ctx.registrations) == 4 && !p.ready,
		)
		l.modals = nil; accept_scene(t, &p, &s, &ctx, l)
		testing.expect(
			t,
			a.disposals == 1 && len(ctx.registrations) == 1 && p.sequence == 1 && a.count == want,
		)
		destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	}
}

@(test)
capture_retention_scope_loss_and_claim_conflict_have_one_common_owner :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	l := Layers {
		base_root_id = "base",
	}; accept_scene(t, &p, &s, &ctx, l)
	interaction.begin_pointer_press(&ctx, "open"); accept_scene(t, &p, &s, &ctx, l)
	testing.expect(t, ctx.pressed_id == "open" && ctx.focus_id == "open")
	ms := [1]Modal{{"a", "ab", true}}; l.modals = ms[:]; accept_scene(t, &p, &s, &ctx, l)
	testing.expect(t, ctx.pressed_id == "" && ctx.hover_id == "" && ctx.focus_id == "ab")
	testing.expect(
		t,
		interaction.release_press(&ctx, "open", .Mouse).code == .Invalid_Action && p.sequence == 0,
	)
	f := scene(t, &p, l); defer destroy_scene(&f)
	claims := [2]interaction.Capture_Claim{{"ab", "hold"}, {"ab", "gesture"}}
	c, e := prepare(
		&s,
		&ctx,
		&f.g,
		f.targets[:],
		claims[:],
		l,
		context.allocator,
	); defer destroy_candidate(&c)
	testing.expect(
		t,
		e.code == .Interaction &&
		e.interaction == .Conflict &&
		c.interaction.targets == nil &&
		s.frame.layers.modals[0].root_id == "a",
	)
}

@(test)
overlay_nested_prepare_and_copy_refusals_preserve_all_owners_and_own_all_strings :: proc(
	t: ^testing.T,
) {
	p, _ := base.create(
		context.allocator,
	); ctx := interaction.create(context.allocator, &p); s := create(context.allocator)
	l := Layers {
		base_root_id = "base",
	}; accept_scene(t, &p, &s, &ctx, l)
	ms := [1]Modal {
		{"a", "ab", true},
	}; ps := [1]Popup{{"pop", "a", "ax"}}; ts := [1]Tooltip{{"tip", "a"}}
	interaction.observe_pointer(&ctx, 10, 10); accept_scene(t, &p, &s, &ctx, l)
	interaction.begin_pointer_press(&ctx, "open")
	l.modals = ms[:]; l.popups = ps[:]; l.tooltips = ts[:]
	f := scene(t, &p, l)
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	tracking.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	fault := Fault {
		backing = mem.tracking_allocator(&tracking),
	}; a := mem.Allocator{fault_allocator, &fault}
	refs := p.lifetime.references
	c, e := prepare(
		&s,
		&ctx,
		&f.g,
		f.targets[:],
		nil,
		l,
		a,
	); testing.expect(t, e.code == .None); count := fault.requests; destroy_candidate(&c)
	for pos in 1 ..= count {
		fault.requests, fault.refuse = 0, pos
		c, e = prepare(
			&s,
			&ctx,
			&f.g,
			f.targets[:],
			nil,
			l,
			a,
		); testing.expect(t, e.code != .None); destroy_candidate(&c)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 &&
			len(tracking.bad_free_array) == 0 &&
			p.lifetime.references == refs &&
			s.frame.layers.modals == nil &&
			ctx.focus_id == "open",
		)
	}
	fault.requests, fault.refuse = 0, 0
	c, e = prepare(
		&s,
		&ctx,
		&f.g,
		f.targets[:],
		nil,
		l,
		context.allocator,
	); testing.expect(t, e.code == .None)
	r, ok := try_copy_frame(&c.frame, a); testing.expect(t, ok); copies := fault.requests
	live := tracking.current_memory_allocated; refs = p.lifetime.references
	for pos in 1 ..= copies {
		fault.requests, fault.refuse = 0, pos
		failed, success := try_copy_frame(
			&c.frame,
			a,
		); testing.expect(t, !success); destroy_frame(&failed)
		testing.expect(
			t,
			tracking.current_memory_allocated == live &&
			len(tracking.bad_free_array) == 0 &&
			p.lifetime.references == refs,
		)
	}
	destroy_candidate(
		&c,
	); destroy_scene(&f); destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	if ok {testing.expect(t, r.layers.base_root_id == "base" && r.layers.modals[0].root_id == "a" && r.layers.popups[0].owner_scope_id == "a" && r.layers.popups[0].return_focus_id == "ax" && r.layers.tooltips[0].root_id == "tip" && r.returns[0] == "open" && len(r.groups) == 4 && !r.stamp.lifetime.alive)}
	destroy_frame(&r)
	testing.expect(t, tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
	fmt.printf(
		"layers overlay prepare-refusals=%d copy-refusals=%d peak=%d live=%d\n",
		count,
		copies,
		tracking.peak_memory_allocated,
		tracking.current_memory_allocated,
	)
}

@(test)
stable_layer_rebuilds_have_no_history_growth :: proc(t: ^testing.T) {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	tracking.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	previous :=
		context.allocator; context.allocator = mem.tracking_allocator(&tracking); defer {context.allocator = previous}
	p, _ := base.create(
		context.allocator,
	); ctx := interaction.create(context.allocator, &p); s := create(context.allocator)
	ms := [1]Modal {
		{"a", "ab", true},
	}; ps := [1]Popup{{"pop", "a", "ax"}}; ts := [1]Tooltip{{"tip", "a"}}
	l := Layers {
		base_root_id = "base",
		modals       = ms[:],
		popups       = ps[:],
		tooltips     = ts[:],
	}
	accept_scene(t, &p, &s, &ctx, l); live := tracking.current_memory_allocated
	for _ in 0 ..< 64 {accept_scene(t, &p, &s, &ctx, l); testing.expect(t, tracking.current_memory_allocated == live)}
	l.modals = nil; l.popups = nil; l.tooltips = nil; accept_scene(t, &p, &s, &ctx, l)
	live = tracking.current_memory_allocated
	for _ in 0 ..< 32 {
		l.modals = ms[:]; l.popups = ps[:]; l.tooltips = ts[:]; accept_scene(t, &p, &s, &ctx, l)
		f := scene(t, &p, l); bad := l; bad.base_root_id = "missing"
		c, e := prepare(
			&s,
			&ctx,
			&f.g,
			f.targets[:],
			nil,
			bad,
			context.allocator,
		); destroy_candidate(&c); destroy_scene(&f); testing.expect(t, e.code != .None)
		l.modals = nil; l.popups = nil; l.tooltips = nil; accept_scene(t, &p, &s, &ctx, l)
		testing.expect(t, tracking.current_memory_allocated == live && ctx.focus_id == "open")
	}
	destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	testing.expect(t, tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
}
