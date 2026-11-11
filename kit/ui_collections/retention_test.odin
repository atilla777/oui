package ui_collections

import base "../ui_base"
import "core:testing"

@(test)
retains_logical_focus_anchor_and_reset_only_after_commit :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s := create(); defer destroy(&s)
	items := [4]Collection_Item {
		{"a", "A", true, true, ""},
		{"b", "B", true, true, ""},
		{"c", "C", true, true, ""},
		{"d", "D", true, true, ""},
	}
	d := fixture_description(items[:])
	stamp, _ := base.begin_attempt(&p, 1)
	c, e := prepare(&s, stamp, d, {w = 100, h = 10}, 0)
	defer destroy_candidate(&c)
	if !testing.expect(t, e.code == .None) {return}
	testing.expect(
		t,
		c.frame.collections[0].focus_id == "a" && c.frame.collections[0].anchor_id == "a",
	)
	base.enter_commit(&p, stamp); commit(&s, &c); base.finish_commit(&p, stamp)
	stamp, _ = base.begin_attempt(&p, 1)
	c, e = prepare(&s, stamp, d, {w = 100, h = 10}, 12)
	if !testing.expect(t, e.code == .None) {return}
	base.enter_commit(&p, stamp); commit(&s, &c); base.finish_commit(&p, stamp)
	items[0].visible = false; d.data_revision += 1
	stamp, _ = base.begin_attempt(&p, 2)
	c, e = prepare(&s, stamp, d, {w = 100, h = 10}, 12)
	if !testing.expect(t, e.code == .None) {return}
	testing.expect(
		t,
		c.frame.collections[0].focus_id == "b" &&
		c.frame.collections[0].anchor_id == "b" &&
		c.frame.collections[0].offset == 0,
	)
	testing.expect(
		t,
		s.frame.collections[0].focus_id == "a" && s.frame.collections[0].offset == 12,
	)
}
