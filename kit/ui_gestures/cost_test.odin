package ui_gestures
import base "../ui_base"
import interaction "../ui_interaction"
import "core:fmt"
import "core:mem"
import "core:testing"
@(test)
bounded_rebuild_accounting_does_not_grow_history :: proc(t: ^testing.T) {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	tracking.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	previous :=
		context.allocator; context.allocator = mem.tracking_allocator(&tracking); defer {context.allocator = previous}
	p, _ := base.create(
		context.allocator,
	); ctx := interaction.create(context.allocator, &p); s := create(); ds := descriptions([]string{"card"})
	testing.expect(t, publish(t, &p, &ctx, &s, ds[:]))
	dispatch(&s, &ctx, nil, {kind = .Begin, id = "drag", source = .Agent})
	testing.expect(t, publish(t, &p, &ctx, &s, ds[:]))
	live := tracking.current_memory_allocated
	for _ in 0 ..< 64 {testing.expect(t, publish(t, &p, &ctx, &s, ds[:])); testing.expect(t, tracking.current_memory_allocated == live)}
	reader, ok := try_copy_frame(&s.frame); testing.expect(t, ok)
	fmt.printf(
		"gestures 66-publish+reader alloc=%d bytes=%d live=%d peak=%d State=%d Frame=%d Candidate=%d handlers=%d backend=0\n",
		tracking.total_allocation_count,
		tracking.total_memory_allocated,
		tracking.current_memory_allocated,
		tracking.peak_memory_allocated,
		size_of(s),
		size_of(Frame),
		size_of(Candidate),
		len(ctx.registrations),
	)
	destroy(&s); interaction.destroy(&ctx); base.destroy(&p); destroy_frame(&reader)
	testing.expect(t, tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
}
