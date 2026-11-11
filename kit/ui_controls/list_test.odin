package ui_controls

import base "../ui_base"
import interaction "../ui_interaction"
import scroll "../ui_scroll"
import "core:testing"

@(test)
list_navigation_composes_scroll_focus_without_changing_controlled_selection :: proc(
	t: ^testing.T,
) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	f := make_fixture(t, &p, .List); defer destroy_fixture(&f)
	sc := scroll.create(context.allocator); defer scroll.destroy(&sc)
	staged, se := scroll.prepare(
		&sc,
		&f.geometry,
		&f.interaction,
		f.recipe.scroll[:],
		context.allocator,
	); defer scroll.destroy_candidate(&staged)
	ds := [1]Description{f.recipe.control}
	c, e := prepare(
		&f.interaction,
		f.layer.frame.layers,
		ds[:],
		context.allocator,
		&f.geometry,
	); defer destroy_candidate(&c)
	if !testing.expect(t, se.code == .None && e.code == .None) {return}
	s := create(); defer destroy(&s)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	stamp := f.geometry.stamp
	base.enter_commit(
		&p,
		stamp,
	); interaction.commit(&ctx, &f.interaction, ds[0].items[0].node_id); scroll.commit(&sc, &staged); commit(&s, &c); base.finish_commit(&p, stamp)
	r := dispatch(&s, &ctx, {kind = .Move_Item, source = .Agent}, &f.layer)
	testing.expect(
		t,
		r.dispatch.code == .Invalid_Action && p.ready,
		"missing selected scroll owner is an explicit refusal",
	)
	r = dispatch(&s, &ctx, {kind = .Move_Item, source = .Agent}, &f.layer, &sc)
	testing.expect(
		t,
		r.dispatch.code == .Applied &&
		r.event == nil &&
		ctx.focus_id == ds[0].items[0].node_id &&
		s.frame.controls[0].selected_id == "two",
	)
	next := make_fixture(t, &p, .List); defer destroy_fixture(&next)
	staged, se = scroll.prepare(
		&sc,
		&next.geometry,
		&next.interaction,
		next.recipe.scroll[:],
		context.allocator,
		ctx.focus_id,
	)
	nd := [1]Description {
		next.recipe.control,
	}; c, e = prepare(&next.interaction, next.layer.frame.layers, nd[:], context.allocator, &next.geometry)
	if !testing.expect(
		t,
		se.code == .None &&
		e.code == .None &&
		staged.has_focus &&
		staged.focus_id == ds[0].items[1].node_id,
	) {return}
	stamp = next.geometry.stamp
	base.enter_commit(
		&p,
		stamp,
	); interaction.commit(&ctx, &next.interaction); ctx.focus_id = interaction.retained_id(&ctx.frame, staged.focus_id); scroll.commit(&sc, &staged); commit(&s, &c); base.finish_commit(&p, stamp)
	testing.expect(
		t,
		ctx.focus_id == ds[0].items[1].node_id && s.frame.controls[0].selected_id == "two",
	)
	r = dispatch(&s, &ctx, {kind = .Move_Left, source = .Agent}, &next.layer, &sc)
	testing.expect(
		t,
		r.dispatch.code == .Invalid_Action && p.ready,
		"horizontal collection navigation is not silently enabled",
	)
}
