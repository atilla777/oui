package ui_controls

import base "../ui_base"
import interaction "../ui_interaction"
import layers "../ui_layers"
import "core:testing"

@(test)
controlled_select_close_returns_to_its_owner_not_the_first_base_button :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	f := make_fixture(t, &p, .Select); defer destroy_fixture(&f)
	ds := [1]Description{f.recipe.control}
	c, e := prepare(
		&f.interaction,
		f.layer.frame.layers,
		ds[:],
		context.allocator,
		&f.geometry,
	); defer destroy_candidate(&c); if !testing.expect(t, e.code == .None) {return}
	s := create(); defer destroy(&s)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	stamp :=
		f.geometry.stamp; base.enter_commit(&p, stamp); interaction.commit(&ctx, &f.interaction, ds[0].items[1].node_id); commit(&s, &c); base.finish_commit(&p, stamp)
	r := dispatch(&s, &ctx, {kind = .Cancel, source = .Agent}, &f.layer)
	if !testing.expect(t, r.event != nil && r.event.?.kind == .Close) {return}
	next := make_fixture(t, &p, .Select, false, false); defer destroy_fixture(&next)
	targets := make([dynamic]interaction.Target); defer delete(targets)
	append(
		&targets,
		interaction.Target{"trigger", "button", true, true},
	); append(&targets, ..next.recipe.targets[:])
	lc, le := layers.prepare(
		&f.layer,
		&ctx,
		&next.geometry,
		targets[:],
		nil,
		next.layer.frame.layers,
		context.allocator,
	); defer layers.destroy_candidate(&lc)
	if !testing.expect(t, le.code == .None && layers.validate_candidate(&p, &lc)) {return}
	nd := [1]Description {
		next.recipe.control,
	}; c, e = prepare(&lc.interaction, next.layer.frame.layers, nd[:], context.allocator, &next.geometry)
	if !testing.expect(t, e.code == .None && validate_candidate(&p, &c)) {return}
	stamp =
		next.geometry.stamp; base.enter_commit(&p, stamp); layers.commit(&f.layer, &ctx, &lc); commit(&s, &c); base.finish_commit(&p, stamp)
	testing.expect(
		t,
		ctx.focus_id == s.frame.controls[0].node_id &&
		ctx.focus_id != "trigger" &&
		!s.frame.controls[0].open &&
		p.sequence == 1,
	)
}
