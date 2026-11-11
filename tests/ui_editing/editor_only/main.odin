package main
import "core:fmt"
import "core:mem"
import editor "ui:ui_editor"
main :: proc() {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	s := editor.create(mem.tracking_allocator(&tracking))
	fmt.printf(
		"editor-only State=%d Frame=%d Candidate=%d init alloc=%d bytes=%d live=%d peak=%d handlers=0 backend=0\n",
		size_of(editor.State),
		size_of(editor.Frame),
		size_of(editor.Candidate),
		tracking.total_allocation_count,
		tracking.total_memory_allocated,
		tracking.current_memory_allocated,
		tracking.peak_memory_allocated,
	)
	editor.destroy(&s)
	assert(tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
}
