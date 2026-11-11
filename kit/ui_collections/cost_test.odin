package ui_collections

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:fmt"
import "core:mem"
import "core:testing"

@(test)
repeated_bound_publications_release_old_owners_and_measure_family_only :: proc(t: ^testing.T) {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	a := mem.tracking_allocator(&tracking)
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s := create(a)
	items := []Collection_Item {
		{"a", "A", true, true, ""},
		{"b", "B", true, true, ""},
		{"c", "C", true, true, ""},
		{"d", "D", true, true, ""},
	}
	for iteration in 0 ..< 50 {
		stamp, _ := base.begin_attempt(&p, 1)
		c, e := prepare(
			&s,
			stamp,
			fixture_description(items),
			{w = 100, h = 10},
			f64(iteration % 3) * 12,
			a,
		)
		if !testing.expect(t, e.code == .None) {destroy_candidate(&c); destroy(&s); return}
		g, i, bound := bind_fixture(t, &c)
		if !testing.expect(
			t,
			bound && validate_candidate(&p, &s, &c),
		) {layout.destroy_frame(&g); interaction.destroy_frame(&i); destroy_candidate(&c); destroy(&s); return}
		reader, copied := try_copy_frame(&c.frame, a)
		testing.expect(t, copied)
		base.enter_commit(&p, stamp); commit(&s, &c); base.finish_commit(&p, stamp)
		layout.destroy_frame(&g); interaction.destroy_frame(&i); destroy_frame(&reader)
		if iteration > 0 {testing.expect(t, s.frame.collections[0].metadata_items_copied == 0)}
	}
	reader, copied := try_copy_frame(&s.frame, a); destroy(&s)
	if testing.expect(
		t,
		copied,
	) {v, code := lookup_collection_item(&reader, "list", "a"); testing.expect(t, code == .Applied && v.item.semantic_name == "A")}
	destroy_frame(&reader)
	fmt.printf(
		"collections 50 rebuilds; common layout/input allocated separately; family alloc=%d bytes=%d peak=%d live=%d State=%d Frame=%d Candidate=%d handlers=0 backend=0\n",
		tracking.total_allocation_count,
		tracking.total_memory_allocated,
		tracking.peak_memory_allocated,
		tracking.current_memory_allocated,
		size_of(State),
		size_of(Frame),
		size_of(Candidate),
	)
	testing.expect(t, tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
}
