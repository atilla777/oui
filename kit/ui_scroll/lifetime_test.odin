package ui_scroll

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:mem"
import "core:testing"

@(test)
foreign_publication_or_unpublished_family_cannot_dispatch :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(context.allocator); defer destroy(&s)
	ids := [3]string{"a", "b", "c"}; if !publish(t, &p, &ctx, &s, ids[:], "a") {return}
	old := s.frame.stamp; s.frame.stamp.attempt += 1
	r := dispatch(&s, &ctx, {kind = .Scroll_By, id = "scroll", source = .Agent, delta_y = 5})
	testing.expect(t, r.code == .Not_Ready && p.ready && !s.has_pending)
	s.frame.stamp = old
	other, _ := base.create(context.allocator); defer base.destroy(&other)
	g, i := fixture(
		t,
		&other,
		context.allocator,
	); defer layout.destroy_frame(&g); defer interaction.destroy_frame(&i)
	ds := [1]Description{{"scroll", "content"}}
	c, e := prepare(&s, &g, &i, ds[:], context.allocator); defer destroy_candidate(&c)
	testing.expect(t, e.code == .Stale && c.frame.regions == nil)
}

@(test)
dispatch_allocation_failure_is_atomic_and_rebuild_history_does_not_grow :: proc(t: ^testing.T) {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	tracking.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	previous := context.allocator
	context.allocator = mem.tracking_allocator(&tracking)
	defer {context.allocator = previous}
	p, _ := base.create(context.allocator)
	ctx := interaction.create(context.allocator, &p)
	s := create(context.allocator)
	ids := [3]string{"a", "b", "c"}
	if !publish(
		t,
		&p,
		&ctx,
		&s,
		ids[:],
		"a",
	) {destroy(&s); interaction.destroy(&ctx); base.destroy(&p); return}
	live := tracking.current_memory_allocated
	for _ in 0 ..< 64 {if !publish(t, &p, &ctx, &s, ids[:]) {break}; testing.expect(t, tracking.current_memory_allocated == live)}
	f := Fault {
		backing = context.allocator,
		refuse  = 1,
	}; s.allocator = {fault_allocator, &f}
	version := s.version
	r := dispatch(&s, &ctx, {kind = .Scroll_By, id = "scroll", source = .Agent, delta_y = 10})
	testing.expect(
		t,
		r.code == .Allocation &&
		p.ready &&
		!s.has_pending &&
		s.version == version &&
		tracking.current_memory_allocated == live,
	)
	s.allocator = context.allocator
	destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	testing.expect(t, tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
}
