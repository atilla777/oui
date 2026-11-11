package native_fixture

import "core:mem"
import "core:testing"

@(test)
on_owner_and_observer_counters_observe_real_delegated_allocations :: proc(t: ^testing.T) {
	f := Fixture {
		instrument = true,
		previous   = context.allocator,
	}
	mem.tracking_allocator_init(&f.observer, f.previous)
	defer mem.tracking_allocator_destroy(&f.observer)
	mem.tracking_allocator_init(&f.tracking, f.previous, mem.tracking_allocator(&f.observer))
	defer mem.tracking_allocator_destroy(&f.tracking)
	a := owner_allocator(&f)
	data := make([]u8, 37, a)
	if !testing.expect(t, len(data) == 37) {return}
	data[36] = 19
	c := counters(&f)
	testing.expect(
		t,
		c.allocs == 1 && c.bytes == 37 && c.live == 37 && c.peak == 37,
		"on must count actual owner requests, not report a vacuous zero",
	)
	testing.expect(
		t,
		c.observer_allocs > 0 && c.observer_live > 0,
		"tracking bookkeeping must be measured separately",
	)
	delete(data, a)
	testing.expect(
		t,
		f.tracking.current_memory_allocated == 0 && len(f.tracking.bad_free_array) == 0,
	)
	mem.tracking_allocator_destroy(&f.tracking)
	testing.expect(t, f.observer.current_memory_allocated == 0)
	f.instrument = false
	testing.expect(
		t,
		owner_allocator(&f) == f.previous,
		"off delegates directly to the original owner allocator",
	)
}
