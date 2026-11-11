package main

import recipe ".."
import fixture "../../native_fixture"
import "core:testing"
import base "ui:ui_base"
import hold "ui:ui_hold"
import interaction "ui:ui_interaction"
import layers "ui:ui_layers"

@(test)
hud_cycle_updates_hp_and_checks_hold_without_retaining_a_front :: proc(t: ^testing.T) {
	s: State; s.hp = 60; s.revision = 1
	p, e := base.create(context.allocator); if !testing.expect(t, e == .None) {return}; s.p = p
	s.ctx = interaction.create(
		context.allocator,
		&s.p,
	); s.ls = layers.create(context.allocator); s.hs = hold.create(context.allocator)
	defer {recipe.destroy_reader(&s.reader); hold.destroy(&s.hs); layers.destroy(&s.ls)
		interaction.destroy(&s.ctx)
		base.destroy(&s.p)}
	publish(&s)
	f: fixture.Fixture; f.input.window_id = 17; f.drawable = {800, 600}
	sample: fixture.Sample
	if !testing.expect(
		t,
		workload_cycle(&f, &s, &sample),
		"HUD workload must apply data updates and threshold/loss checks",
	) {return}
	testing.expect(t, s.hp == 60 && s.effects == 1 && s.hs.live.phase == .Idle && s.p.ready)
	testing.expect(
		t,
		workload_cycle(&f, &s, &sample) && s.hp == 60 && s.effects == 2,
		"repeat must start without a held front or replay",
	)
}
