package loader

import "base:runtime"
import "core:mem"
import "core:testing"

Output_Fault :: struct {
	backing:       mem.Allocator,
	calls, refuse: int,
}
output_fault :: proc(
	data: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old: rawptr,
	old_size: int,
	loc: runtime.Source_Code_Location,
) -> (
	[]u8,
	mem.Allocator_Error,
) {
	f := cast(^Output_Fault)data
	if size > 0 &&
	   (mode == .Alloc ||
			   mode == .Alloc_Non_Zeroed ||
			   mode == .Resize ||
			   mode == .Resize_Non_Zeroed) {
		f.calls += 1
		if f.calls == f.refuse {return nil, .Out_Of_Memory}
	}
	return f.backing.procedure(f.backing.data, mode, size, alignment, old, old_size, loc)
}
@(test)
png_output_allocator_refusal_and_explicit_retry :: proc(t: ^testing.T) {
	b := valid_rgba_fixture()
	live: mem.Tracking_Allocator
	mem.tracking_allocator_init(
		&live,
		context.allocator,
	); defer mem.tracking_allocator_destroy(&live)
	f := Output_Fault {
		backing = mem.tracking_allocator(&live),
		refuse  = 1,
	}
	for _ in 0 ..< 100 {
		f.calls = 0
		image, e := decode_png(b[:], {output_fault, &f})
		testing.expect(t, e.stage == "output" && e.field == "allocation" && len(image.pixels) == 0)
		destroy_decoded(&image)
		testing.expect(t, len(live.allocation_map) == 0 && len(live.bad_free_array) == 0)
	}
	f.calls, f.refuse = 0, 0
	image, e := decode_png(b[:], {output_fault, &f})
	testing.expect(t, e.stage == "" && len(image.pixels) == 16)
	destroy_decoded(&image)
	testing.expect(t, len(live.allocation_map) == 0 && len(live.bad_free_array) == 0)
}

when #config(ATLAS_NATIVE_FAULT_TEST, false) {
	foreign import native_test "system:c"
	foreign native_test {
		atlas_test_reset :: proc "c" (fail_at: uintptr) ---
		atlas_test_calls :: proc "c" () -> uintptr ---
		atlas_test_blocks :: proc "c" () -> uintptr ---
		atlas_test_bytes :: proc "c" () -> uintptr ---
	}
	@(test)
	png_native_every_malloc_refusal_and_100_cleanup_retries :: proc(t: ^testing.T) {
		b := valid_rgba_fixture()
		atlas_test_reset(0)
		image, e := decode_png(b[:])
		testing.expect(t, e.stage == "")
		count := atlas_test_calls(); destroy_decoded(&image)
		testing.expect(t, count >= 9 && atlas_test_blocks() == 0 && atlas_test_bytes() == 0)
		for _ in 0 ..< 100 {
			for n in 1 ..= count {
				atlas_test_reset(n)
				image, e = decode_png(b[:])
				testing.expect(t, e.stage != "" && len(image.pixels) == 0)
				destroy_decoded(&image)
				testing.expect(t, atlas_test_blocks() == 0 && atlas_test_bytes() == 0)
			}
			atlas_test_reset(0)
			image, e = decode_png(b[:])
			testing.expect(t, e.stage == "" && len(image.pixels) == 16)
			destroy_decoded(&image)
			testing.expect(t, atlas_test_blocks() == 0 && atlas_test_bytes() == 0)
		}
		// Output allocation fails after successful native begin; native blocks
		// must still be freed by the decoder's unconditional png_image_free.
		f := Output_Fault {
			backing = context.allocator,
			refuse  = 1,
		}
		atlas_test_reset(0)
		image, e = decode_png(b[:], {output_fault, &f})
		testing.expect(
			t,
			e.stage == "output" &&
			atlas_test_calls() >= 3 &&
			atlas_test_blocks() == 0 &&
			atlas_test_bytes() == 0,
		)
		destroy_decoded(&image)
	}
}
