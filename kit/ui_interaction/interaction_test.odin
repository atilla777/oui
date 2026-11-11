package ui_interaction

import base "../ui_base"
import layout "../ui_layout"
import "core:mem"
import "core:testing"

publish_fixture :: proc(
	ctx: ^Context,
	targets: []Target,
	root_kind := layout.Kind.Column,
) -> Code {
	s, e := base.begin_attempt(ctx.publication, 1)
	if e != .None {return .Not_Ready}
	nodes := [3]layout.Node {
		{
			id = "root",
			role = root_kind,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
			enabled = true,
			visible = true,
		},
		{
			id = "button",
			parent = "root",
			role = .Box,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 40},
				y = {mode = .Fixed, value = 20},
			},
			enabled = true,
			visible = true,
		},
		{
			id = "last",
			parent = "root",
			role = .Box,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 40},
				y = {mode = .Fixed, value = 20},
			},
			enabled = true,
			visible = true,
		},
	}
	g, ge := layout.prepare(nodes[:], {drawable = {100, 100}, ui_scale = 1}, {}, ctx.allocator, s)
	defer layout.destroy_frame(&g)
	if ge.code != .None {return .Not_Ready}
	c, ce := prepare(&g, targets, nil, ctx.allocator)
	defer destroy_frame(&c)
	if ce != .Applied {return ce}
	if base.enter_commit(ctx.publication, c.stamp) != .None {return .Not_Ready}
	commit(ctx, &c)
	base.finish_commit(ctx.publication, s)
	reconcile_registrations(ctx)
	return .Applied
}

@(test)
rebuild_does_not_accumulate_frames_or_registration_history :: proc(t: ^testing.T) {
	live: mem.Tracking_Allocator
	mem.tracking_allocator_init(
		&live,
		context.allocator,
	); defer mem.tracking_allocator_destroy(&live)
	a := mem.tracking_allocator(&live)
	p, _ := base.create(a); defer base.destroy(&p)
	ctx := create(a, &p); defer destroy(&ctx)
	targets := [1]Target{{"button", "button", true, true}}
	testing.expect(t, publish_fixture(&ctx, targets[:]) == .Applied)
	probe := Probe {
		ctx = &ctx,
	}
	_, code := register_handler(&ctx, "button", handler, &probe, dispose)
	testing.expect(t, code == .Applied)
	baseline := live.current_memory_allocated
	for _ in 0 ..< 64 {
		testing.expect(t, publish_fixture(&ctx, targets[:]) == .Applied)
		testing.expect(
			t,
			live.current_memory_allocated == baseline &&
			len(ctx.registrations) == 1 &&
			probe.disposals == 0,
		)
	}
	destroy(&ctx); base.destroy(&p)
	testing.expect(t, live.current_memory_allocated == 0 && probe.disposals == 1)
}

@(test)
press_release_loss_uses_one_semantic_activation :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := create(context.allocator, &p); defer destroy(&ctx)
	targets := [2]Target{{"button", "button", true, true}, {"last", "button", true, true}}
	testing.expect(t, publish_fixture(&ctx, targets[:]) == .Applied)
	testing.expect(t, observe_pointer(&ctx, 5, 5) == .Applied && ctx.hover_id == "button")
	testing.expect(t, publish_fixture(&ctx, targets[:]) == .Applied)
	if !testing.expect(
		t,
		begin_press(&ctx, "button") == .Applied,
		"available target must begin a press",
	) {return}
	testing.expect(t, !p.ready && ctx.pressed_id == "button")
	testing.expect(t, publish_fixture(&ctx, targets[:]) == .Applied)
	testing.expect(t, begin_press(&ctx, "last") == .Conflict)
	r := release_press(&ctx, "button", .Mouse)
	testing.expect(t, r.has_event && r.event.sequence == 1 && ctx.pressed_id == "")
	testing.expect(t, !release_press(&ctx, "button", .Mouse).has_event)
	testing.expect(t, publish_fixture(&ctx, targets[:]) == .Applied)
	testing.expect(t, begin_press(&ctx, "button") == .Applied)
	cancel_press(&ctx)
	testing.expect(t, publish_fixture(&ctx, targets[:]) == .Applied)
	testing.expect(t, !release_press(&ctx, "button", .Mouse).has_event && p.sequence == 1)
}

Probe :: struct {
	ctx:                   ^Context,
	deliveries, disposals: int,
	reentry_blocked:       bool,
}

@(test)
structural_role_change_retires_registration :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := create(context.allocator, &p); defer destroy(&ctx)
	testing.expect(t, publish_fixture(&ctx, nil) == .Applied)
	probe := Probe {
		ctx = &ctx,
	}
	_, code := register_handler(&ctx, "root", handler, &probe, dispose)
	testing.expect(t, code == .Applied)
	testing.expect(t, publish_fixture(&ctx, nil, .Row) == .Applied)
	testing.expect(
		t,
		probe.disposals == 1,
		"layout kind change retires an existing node registration",
	)
}
handler :: proc(d: Delivery, user: rawptr) -> Propagation {
	p := cast(^Probe)user; p.deliveries += 1
	p.reentry_blocked = dispatch(p.ctx, {.Activate, "button", .Agent, false}).code == .Not_Ready
	return .Continue
}

@(test)
failed_attempt_blocks_current_actions_and_recovery_does_not_replay :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := create(context.allocator, &p); defer destroy(&ctx)
	targets := [1]Target{{"button", "button", true, true}}
	testing.expect(t, publish_fixture(&ctx, targets[:]) == .Applied)
	testing.expect(
		t,
		dispatch(&ctx, {.Activate, "button", .Agent, false}).has_event && p.sequence == 1,
	)
	historical, ok := try_copy_frame(&ctx.frame, context.allocator)
	if !testing.expect(t, ok) {return}; defer destroy_frame(&historical)
	s, _ := base.begin_attempt(&p, 2)
	bad := [1]layout.Node {
		{
			id = "invalid",
			role = .Content,
			layout = layout.Layout{x = {mode = .Content}, y = {mode = .Content}},
			enabled = true,
			visible = true,
		},
	}
	f, e := layout.prepare(
		bad[:],
		{drawable = {100, 100}, ui_scale = 1},
		{},
		context.allocator,
		s,
	); defer layout.destroy_frame(&f)
	testing.expect(t, e.code == .Metrics_Failed && e.id == "invalid")
	testing.expect(t, !ready(&ctx) && !base.is_current(&p, historical.stamp))
	testing.expect(
		t,
		!dispatch(&ctx, {.Activate, "button", .Agent, false}).has_event && p.sequence == 1,
	)
	testing.expect(t, publish_fixture(&ctx, targets[:]) == .Applied && p.sequence == 1)
	testing.expect(t, dispatch(&ctx, {.Activate, "button", .Agent, false}).event.sequence == 2)
}
dispose :: proc(user: rawptr) {p := cast(^Probe)user; p.disposals += 1}
@(test)
routing_registration_reentry_and_disposal :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := create(context.allocator, &p); defer destroy(&ctx)
	targets := [1]Target{{"button", "button", true, true}}
	testing.expect(t, publish_fixture(&ctx, targets[:]) == .Applied)
	probe := Probe {
		ctx = &ctx,
	}
	root, rc := register_handler(&ctx, "root", handler, &probe, dispose)
	button, bc := register_handler(&ctx, "button", handler, &probe, dispose)
	testing.expect(t, rc == .Applied && bc == .Applied && root != button)
	testing.expect(t, dispatch_routed(&ctx, {.Activate, "button", .Agent, false}).has_event)
	testing.expect(t, probe.deliveries == 2 && probe.reentry_blocked)
	testing.expect(t, unsubscribe(&ctx, root) == .Applied && probe.disposals == 1)
	testing.expect(t, publish_fixture(&ctx, nil) == .Applied && probe.disposals == 2)
	testing.expect(t, unsubscribe(&ctx, button) == .Not_Found)
}
@(test)
activation_barrier_navigation_removal_and_copy :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := create(context.allocator, &p); defer destroy(&ctx)
	targets := [2]Target{{"button", "button", true, true}, {"last", "button", true, true}}
	testing.expect(t, publish_fixture(&ctx, targets[:]) == .Applied)
	r := dispatch(&ctx, {.Activate, "button", .Agent, false})
	testing.expect(t, r.has_event && r.event.sequence == 1 && r.event.id == "button")
	testing.expect(t, dispatch(&ctx, {.Activate, "button", .Agent, false}).code == .Not_Ready)
	testing.expect(t, publish_fixture(&ctx, targets[:]) == .Applied)
	testing.expect(
		t,
		dispatch(&ctx, {.Navigate, "", .Keyboard, false}).code == .Applied &&
		ctx.focus_id == "button",
	)
	testing.expect(t, publish_fixture(&ctx, targets[:]) == .Applied)
	reader, copied := try_copy_frame(&ctx.frame, context.allocator)
	if !testing.expect(t, copied, "owning interaction frame must copy") {return}
	defer destroy_frame(&reader)
	destroy(&ctx)
	n, found := find(&reader, "button")
	testing.expect(t, found && n.availability == .Applied)
}

@(test)
invalid_source_is_refused_without_publication_mutation :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := create(context.allocator, &p); defer destroy(&ctx)
	targets := [1]Target{{"button", "button", true, true}}
	testing.expect(t, publish_fixture(&ctx, targets[:]) == .Applied)
	r := dispatch(&ctx, {.Activate, "button", Source(99), false})
	testing.expect(t, r.code == .Invalid_Action && !r.has_event && ready(&ctx) && p.sequence == 0)
}
