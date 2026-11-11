package recipe

import "core:fmt"
import "core:mem"
import base "ui:ui_base"
import hold "ui:ui_hold"
import hold_sdl "ui:ui_hold/sdl"
import interaction "ui:ui_interaction"
import layers "ui:ui_layers"
import layout "ui:ui_layout"
import fonts "ui:ui_sdl_text"
import text "ui:ui_text"

// Bounded headless composition, not a second window application. The selected
// backend types compile here; lab-hud supplies actual strings/fonts/paint/input.
Reader :: struct {
	geometry:    layout.Frame,
	interaction: interaction.Frame,
	layers:      layers.Frame,
	hold:        hold.Frame,
}
destroy_reader :: proc(r: ^Reader) {
	layout.destroy_frame(&r.geometry)
	interaction.destroy_frame(&r.interaction)
	layers.destroy_frame(&r.layers)
	hold.destroy_frame(&r.hold)
	r^ = {}
}
publish :: proc(
	p: ^base.Publication,
	ctx: ^interaction.Context,
	ls: ^layers.State,
	hs: ^hold.State,
	hp: f64,
	revision: u64,
	conflicts: ^int,
	drawable: layout.Extent = {100, 60},
) -> Reader {
	a := context.allocator
	stamp, pe := base.begin_attempt(p, revision); assert(pe == .None)
	nodes := []layout.Node {
		{
			id = "root",
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 60},
			},
		},
		{
			id = "base",
			parent = "root",
			role = .Column,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
		},
		{
			id = "restore",
			parent = "base",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 20},
			},
		},
		{
			id = "progress",
			parent = "base",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 10},
			},
		},
	}
	g, ge := layout.prepare(nodes, {drawable = drawable, ui_scale = 1}, {}, a, stamp)
	assert(ge.code == .None); defer layout.destroy_frame(&g)
	targets := []interaction.Target{{"restore", "button", true, true}}
	claims := []interaction.Capture_Claim{{"restore", "hold"}}
	if conflicts^ == 0 {
		bad, code := interaction.prepare(
			&g,
			targets,
			[]interaction.Capture_Claim{{"restore", "hold"}, {"restore", "other"}},
			a,
		)
		defer interaction.destroy_candidate(&bad)
		assert(code == .Conflict && !p.ready); conflicts^ += 1
	}
	lc, le := layers.prepare(ls, ctx, &g, targets, claims, {base_root_id = "base"}, a)
	assert(le.code == .None); defer layers.destroy_candidate(&lc)
	hc, he := hold.prepare(
		hs,
		ctx,
		&g,
		&lc.interaction,
		[]hold.Progress_Description{{"progress", hp, 100}},
		[]hold.Description{{"restore", 1000}},
		a,
	)
	assert(he.code == .None); defer hold.destroy_candidate(&hc)
	// All fallible reader copies precede the shared infallible commit barrier.
	r: Reader; complete := false; defer {if !complete {destroy_reader(&r)}}
	ok: bool
	r.geometry, ok = layout.try_copy_frame(&g, a); assert(ok)
	r.interaction, ok = interaction.try_copy_frame(&lc.interaction, a); assert(ok)
	r.layers, ok = layers.try_copy_frame(&lc.frame, a); assert(ok)
	r.hold, ok = hold.try_copy_frame(&hc.frame, a); assert(ok)
	assert(
		layout.validate_candidate(p, &g) &&
		layers.validate_candidate(p, &lc) &&
		hold.validate_candidate(p, &hc),
	)
	assert(base.enter_commit(p, stamp) == .None)
	layers.commit(ls, ctx, &lc); hold.commit(hs, &hc)
	base.finish_commit(p, stamp); interaction.reconcile_registrations(ctx)
	complete = true; return r
}
main :: proc() {
	tracking: mem.Tracking_Allocator
	mem.tracking_allocator_init(
		&tracking,
		context.allocator,
	); defer mem.tracking_allocator_destroy(&tracking)
	previous :=
		context.allocator; context.allocator = mem.tracking_allocator(&tracking); defer {context.allocator = previous}
	p, pe := base.create(context.allocator); assert(pe == .None)
	ctx := interaction.create(context.allocator, &p)
	ls := layers.create(context.allocator); hs := hold.create(context.allocator)
	adapter: hold_sdl.Adapter; tf: text.Frame; font: ^fonts.Generation
	assert(size_of(adapter) > 0 && size_of(tf) > 0 && font == nil)
	conflicts, effects := 0, 0; hp := f64(60); revision := u64(1)
	r := publish(&p, &ctx, &ls, &hs, hp, revision, &conflicts)
	assert(base.is_current(&p, r.geometry.stamp))
	assert(
		interaction.dispatch(&ctx, {.Activate, "restore", .Agent, false}).code ==
		.Activation_Required,
	)
	assert(
		hold.dispatch(&hs, &ctx, {kind = .Begin, id = "restore", source = .Agent}).code ==
		.Applied,
	)
	destroy_reader(&r); r = publish(&p, &ctx, &ls, &hs, hp, revision, &conflicts)
	assert(!hold.dispatch(&hs, &ctx, {kind = .Advance, duration_ms = 999}).dispatch.has_event)
	destroy_reader(&r); r = publish(&p, &ctx, &ls, &hs, hp, revision, &conflicts)
	result := hold.dispatch(&hs, &ctx, {kind = .Advance, duration_ms = 1})
	assert(result.dispatch.has_event)
	// One application outcome, then rebuild; publication/recovery is not reduce.
	hp = 100; effects += 1; revision += 1
	destroy_reader(&r); r = publish(&p, &ctx, &ls, &hs, hp, revision, &conflicts)
	base.invalidate(&p)
	assert(hold.dispatch(&hs, &ctx, {kind = .Advance, duration_ms = 1000}).code == .Not_Ready)
	destroy_reader(&r); r = publish(&p, &ctx, &ls, &hs, hp, revision, &conflicts)
	assert(effects == 1 && hp == 100 && r.hold.hold.phase == .Completed_Waiting_Release)
	hold.destroy(&hs); layers.destroy(&ls); interaction.destroy(&ctx); base.destroy(&p)
	assert(!r.hold.stamp.lifetime.alive && r.hold.hold.phase == .Completed_Waiting_Release)
	destroy_reader(&r)
	assert(tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
	fmt.printf(
		"recipe-hud effects=%d conflicts=%d live=%d\n",
		effects,
		conflicts,
		tracking.current_memory_allocated,
	)
}
