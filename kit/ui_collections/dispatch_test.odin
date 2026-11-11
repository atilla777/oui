package ui_collections

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:testing"

publish_collection :: proc(
	t: ^testing.T,
	s: ^State,
	ctx: ^interaction.Context,
	d: Collection_Description,
) -> bool {
	stamp, _ := base.begin_attempt(ctx.publication, 1)
	offset := f64(0); if len(s.frame.collections) != 0 {offset = s.frame.collections[0].offset}
	c, e := prepare(
		s,
		stamp,
		d,
		{w = 100, h = 10},
		offset,
		focus_id = ctx.focus_id,
	); defer destroy_candidate(&c)
	if !testing.expect(t, e.code == .None) {return false}
	g, i, bound := bind_fixture(
		t,
		&c,
	); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&i)
	if !testing.expect(t, bound && validate_candidate(ctx.publication, s, &c)) {return false}
	base.enter_commit(ctx.publication, stamp)
	focus := ""; if c.has_focus {focus = c.frame.collections[0].focus_node_id}
	interaction.commit(ctx, &i, focus); commit(s, &c)
	base.finish_commit(ctx.publication, stamp)
	return true
}
@(test)
offscreen_focus_is_materialized_before_one_activation_and_never_replayed :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(); defer destroy(&s)
	items := []Collection_Item {
		{"a", "A", true, true, ""},
		{"b", "B", true, true, ""},
		{"c", "C", true, true, ""},
	}
	d := fixture_description(items)
	if !publish_collection(t, &s, &ctx, d) {return}
	r := dispatch(
		&s,
		&ctx,
		{kind = .Focus, collection_id = "list", item_id = "c", source = .Agent},
	)
	if !testing.expect(t, r.dispatch.code == .Applied && !p.ready) {return}
	if !publish_collection(t, &s, &ctx, d) {return}
	id, _ := item_node_id("list", "c"); defer delete(id)
	testing.expect(t, ctx.focus_id == id && s.frame.collections[0].offset == 24 && !s.has_pending)
	r = dispatch(
		&s,
		&ctx,
		{kind = .Activate, collection_id = "list", item_id = "c", source = .Agent},
	)
	testing.expect(
		t,
		r.dispatch.has_event &&
		r.event != nil &&
		r.event.?.item_id == "c" &&
		p.sequence == 1 &&
		!p.ready,
	)
	r = dispatch(
		&s,
		&ctx,
		{kind = .Activate, collection_id = "list", item_id = "c", source = .Agent},
	)
	testing.expect(t, r.dispatch.code == .Not_Ready && r.event == nil && p.sequence == 1)
}
