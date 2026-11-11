package collections_demo_model

import "core:testing"

@(test)
delete_restore_and_mode_are_atomic :: proc(t: ^testing.T) {
	s := create(); before := s
	testing.expect(t, !reduce(&s, {kind = .Delete}).ok && s == before)
	reduce(&s, {kind = .Select, id = "item-05000"})
	testing.expect(t, reduce(&s, {kind = .Delete}).changed)
	testing.expect(t, s.count == 9999 && s.selected == 0 && !contains(&s, 5000))
	testing.expect(t, s.order[4999] == 5001)
	testing.expect(t, !reduce(&s, {kind = .Select, id = "item-05000"}).ok)
	testing.expect(t, reduce(&s, {kind = .Switch}).changed && s.mode == .Grid)
	reduce(&s, {kind = .Reverse})
	epoch := s.reset_epoch
	testing.expect(t, reduce(&s, {kind = .Restore}).changed)
	testing.expect(
		t,
		s.count == 10000 && s.selected == 0 && s.mode == .Grid && s.reset_epoch == epoch + 1,
	)
	for i in 0 ..< CAPACITY {testing.expect_value(t, s.order[i], i + 1)}
	s.count = 0
	testing.expect(t, reduce(&s, {kind = .Reverse}).ok && s.selected == 0)
	testing.expect(t, !reduce(&s, {kind = .Select, id = "item-00001"}).ok)
	testing.expect(t, reduce(&s, {kind = .Restore}).changed && s.count == 10000)
}

@(test)
initial_fixture_is_complete_and_unselected :: proc(t: ^testing.T) {
	s := create()
	testing.expect(t, s.count == 10000 && s.selected == 0 && s.mode == .List)
	for i in 0 ..< CAPACITY {testing.expect_value(t, s.order[i], i + 1)}
}

@(test)
selection_and_reorder_are_by_stable_id :: proc(t: ^testing.T) {
	s := create()
	testing.expect(t, reduce(&s, {kind = .Select, id = "item-05000", sequence = 1}).changed)
	testing.expect_value(t, s.selected, 5000)
	revision := s.revision
	testing.expect(t, reduce(&s, {kind = .Select, id = "item-05000", sequence = 2}).ok)
	testing.expect_value(t, s.revision, revision)
	testing.expect(t, reduce(&s, {kind = .Reverse, sequence = 3}).changed)
	testing.expect(t, s.order[0] == 10000 && s.order[9999] == 1 && s.selected == 5000)
	before := s
	testing.expect(t, !reduce(&s, {kind = .Select, id = "item-00000"}).ok && s == before)
	testing.expect(t, !reduce(&s, {kind = .Reverse, sequence = 3}).ok && s == before)
	testing.expect_value(t, identity("item-10000"), 10000)
	testing.expect_value(t, identity("item-+0001"), 0)
}
