package ui_editor
import base "../ui_base"
import interaction "../ui_interaction"
import "core:fmt"
import "core:mem"
import "core:testing"
@(test)
bounded_rebuild_accounting_separates_common_and_selected_family :: proc(t: ^testing.T) {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	tracking.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	previous :=
		context.allocator; context.allocator = mem.tracking_allocator(&tracking); defer {context.allocator = previous}
	p, _ := base.create(context.allocator)
	fmt.printf(
		"editor common-init alloc=%d bytes=%d live=%d peak=%d Publication=%d Interaction=%d\n",
		tracking.total_allocation_count,
		tracking.total_memory_allocated,
		tracking.current_memory_allocated,
		tracking.peak_memory_allocated,
		size_of(p),
		size_of(interaction.Context),
	)
	ctx := interaction.create(context.allocator, &p); s := create()
	d := description(); testing.expect(t, publish(t, &p, &ctx, &s, d))
	live := tracking.current_memory_allocated
	for _ in 0 ..< 64 {testing.expect(t, publish(t, &p, &ctx, &s, d)); testing.expect(t, tracking.current_memory_allocated == live)}
	reader, ok := try_copy_frame(&s.frame); testing.expect(t, ok)
	fmt.printf(
		"editor 65-publish+reader alloc=%d bytes=%d live=%d peak=%d State=%d Frame=%d Candidate=%d handlers=%d backend=0\n",
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
