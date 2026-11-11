package ui_collections

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:testing"

@(test)
typed_candidates_reuse_data_and_refuse_foreign_stale_owners :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s := create(); defer destroy(&s)
	other := create(); defer destroy(&other)
	stamp, _ := base.begin_attempt(&p, 1)
	items := [2]Collection_Item{{"a", "Я", true, true, ""}, {"b", "B", true, true, ""}}
	d := fixture_description(items[:])
	c, e := prepare(&s, stamp, d, {w = 100, h = 10}, 0)
	defer destroy_candidate(&c)
	if !testing.expect(t, e.code == .None) {return}
	g, i, bound := bind_fixture(
		t,
		&c,
	); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&i)
	if !testing.expect(t, bound && validate_candidate(&p, &s, &c)) {return}
	testing.expect(t, !validate_candidate(&p, &other, &c))
	base.enter_commit(&p, stamp); commit(&s, &c); base.finish_commit(&p, stamp)
	stamp, _ = base.begin_attempt(&p, 1)
	c, e = prepare(&s, stamp, d, {w = 100, h = 10}, 12)
	if !testing.expect(t, e.code == .None) {return}
	testing.expect(
		t,
		c.frame.collections[0].data == s.frame.collections[0].data &&
		c.frame.collections[0].metadata_items_copied == 0,
	)
	base.begin_attempt(&p, 1)
	testing.expect(t, !validate_candidate(&p, &s, &c))
}
