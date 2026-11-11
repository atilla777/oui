package main
import "core:fmt"
import "core:mem"
import gestures "ui:ui_gestures"
main :: proc() {
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	s := gestures.create(mem.tracking_allocator(&tracking))
	fmt.printf(
		"gestures-only State=%d Frame=%d Candidate=%d init alloc=%d bytes=%d live=%d peak=%d handlers=0 backend=0\n",
		size_of(gestures.State),
		size_of(gestures.Frame),
		size_of(gestures.Candidate),
		tracking.total_allocation_count,
		tracking.total_memory_allocated,
		tracking.current_memory_allocated,
		tracking.peak_memory_allocated,
	)
	gestures.destroy(&s)
	assert(tracking.current_memory_allocated == 0 && len(tracking.bad_free_array) == 0)
}
