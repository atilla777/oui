package loader

import "core:hash"
import "core:mem"
import "core:testing"

foreign import fixture_zlib "system:z"
foreign fixture_zlib {
	compress2 :: proc "c" (dest: rawptr, length: ^uintptr, source: rawptr, source_length: uintptr, level: i32) -> i32 ---
}

@(test)
png_envelope_unsupported_overlimit_crc_and_trailing_refusals :: proc(t: ^testing.T) {
	raw := []u8{0, 1, 2, 3, 255, 4, 5, 6, 255}
	for mode in 0 ..< 5 {
		fixture := png_test_fixture(raw, 0 if mode == 0 else 6, width = 4097 if mode == 1 else 2)
		if mode == 2 {fixture[40] ~= 1}
		if mode == 3 {append(&fixture, 0)}
		if mode == 4 {fixture[len(fixture) - 1] ~= 1}
		image, e := decode_png(fixture[:])
		testing.expect(t, e.stage == "envelope" && len(image.pixels) == 0)
		destroy_decoded(&image); delete(fixture)
	}
}
png_test_chunk :: proc(out: ^[dynamic]u8, kind: string, bytes: []u8) {
	n := u32(len(bytes))
	append(out, u8(n >> 24), u8(n >> 16), u8(n >> 8), u8(n))
	start := len(out^)
	append(out, ..transmute([]u8)kind); append(out, ..bytes)
	crc := hash.crc32(out^[start:])
	append(out, u8(crc >> 24), u8(crc >> 16), u8(crc >> 8), u8(crc))
}
// Test-only PNG framing around the ready zlib compressor; no codec algorithm.
png_test_fixture :: proc(
	raw: []u8,
	color: u8,
	transparency: []u8 = nil,
	bad_checksum := false,
	palette := false,
	width: u32 = 2,
	stream: []u8 = nil,
) -> [dynamic]u8 {
	compressed: [1024]u8; length := uintptr(len(compressed))
	assert(compress2(raw_data(compressed[:]), &length, raw_data(raw), uintptr(len(raw)), 6) == 0)
	if bad_checksum {compressed[int(length) - 1] ~= 1}
	header := [13]u8 {
		u8(width >> 24),
		u8(width >> 16),
		u8(width >> 8),
		u8(width),
		0,
		0,
		0,
		1,
		8,
		color,
		0,
		0,
		0,
	}
	out := make([dynamic]u8)
	append(&out, 137, 80, 78, 71, 13, 10, 26, 10)
	png_test_chunk(&out, "IHDR", header[:])
	if palette {png_test_chunk(&out, "PLTE", []u8{10, 20, 30})}
	if transparency != nil {png_test_chunk(&out, "tRNS", transparency)}
	png_test_chunk(&out, "IDAT", compressed[:int(length)] if stream == nil else stream)
	png_test_chunk(&out, "IEND", nil)
	return out
}

@(test)
png_corrupt_deflate_blocks_release_and_allow_explicit_recovery :: proc(t: ^testing.T) {
	// Valid PNG framing and chunk CRCs, but independently constructed invalid
	// zlib/DEFLATE streams: reserved BTYPE, stored LEN/NLEN mismatch, truncated
	// dynamic Huffman block, and invalid zlib window size (with valid FCHECK).
	streams := [][]u8 {
		{0x78, 0x9c, 0x07, 0, 0, 0, 1},
		{0x78, 0x01, 0x01, 0x09, 0, 0, 0, 0},
		{0x78, 0x9c, 0x05, 0},
		{0x88, 0x1c, 0x03, 0, 0, 0, 0, 1},
	}
	raw := []u8{0, 200, 100, 50, 128, 1, 2, 3, 0}
	valid := png_test_fixture(raw, 6)
	defer delete(valid)
	live: mem.Tracking_Allocator
	mem.tracking_allocator_init(&live, context.allocator)
	defer mem.tracking_allocator_destroy(&live)
	for stream in streams {
		fixture := png_test_fixture(raw, 6, stream = stream)
		defer delete(fixture)
		_, _, framing := png_envelope(fixture[:])
		testing.expect_value(t, framing.stage, "")
		for _ in 0 ..< 100 {
			when #config(ATLAS_NATIVE_FAULT_TEST, false) {atlas_test_reset(0)}
			image, e := decode_png(fixture[:], mem.tracking_allocator(&live))
			testing.expect(t, e.stage == "finish" && e.message[0] != 0 && len(image.pixels) == 0)
			destroy_decoded(&image)
			when #config(ATLAS_NATIVE_FAULT_TEST, false) {
				testing.expect(t, atlas_test_blocks() == 0 && atlas_test_bytes() == 0)
			}
			recovered, retry := decode_png(valid[:], mem.tracking_allocator(&live))
			testing.expect(t, retry.stage == "" && len(recovered.pixels) == 8)
			destroy_decoded(&recovered)
			testing.expect(t, len(live.allocation_map) == 0 && len(live.bad_free_array) == 0)
			when #config(ATLAS_NATIVE_FAULT_TEST, false) {
				testing.expect(t, atlas_test_blocks() == 0 && atlas_test_bytes() == 0)
			}
		}
	}
}
@(test)
png_rgb_rgba_transparency_and_optional_palette_have_known_unassociated_pixels :: proc(
	t: ^testing.T,
) {
	for mode in 0 ..< 4 {
		rgb := [7]u8{0, 10, 20, 30, 40, 50, 60}
		rgba := [9]u8{0, 200, 100, 50, 128, 1, 2, 3, 0}
		trns := [6]u8{0, 10, 0, 20, 0, 30}
		var_fixture: [dynamic]u8
		expected := [8]u8{10, 20, 30, 255, 40, 50, 60, 255}
		if mode ==
		   2 {var_fixture = png_test_fixture(rgba[:], 6); expected = {200, 100, 50, 128, 1, 2, 3, 0}} else if mode == 1 {var_fixture = png_test_fixture(rgb[:], 2, trns[:]); expected[3] = 0} else {var_fixture = png_test_fixture(rgb[:], 2, palette = mode == 3)}
		image, e := decode_png(var_fixture[:])
		if testing.expect(t, e.stage == "", "valid RGB8/RGBA8/tRNS/PLTE profile") {
			testing.expect(t, len(image.pixels) == 8)
			for b, i in expected {testing.expect_value(t, image.pixels[i], b)}
		}
		destroy_decoded(&image); delete(var_fixture)
	}
}
@(test)
png_malformed_native_streams_100_times_release_both_domains :: proc(t: ^testing.T) {
	live: mem.Tracking_Allocator
	mem.tracking_allocator_init(
		&live,
		context.allocator,
	); defer mem.tracking_allocator_destroy(&live)
	for mode in 0 ..< 3 {
		raw := [9]u8{0, 200, 100, 50, 128, 1, 2, 3, 0}
		if mode == 0 {raw[0] = 5}
		input := raw[:]; if mode == 1 {input = raw[:3]}
		fixture := png_test_fixture(input, 6, bad_checksum = mode == 2)
		for _ in 0 ..< 100 {
			when #config(ATLAS_NATIVE_FAULT_TEST, false) {atlas_test_reset(0)}
			image, e := decode_png(fixture[:], mem.tracking_allocator(&live))
			testing.expect(t, e.stage == "finish" && e.message[0] != 0 && len(image.pixels) == 0)
			destroy_decoded(&image)
			testing.expect(t, len(live.allocation_map) == 0 && len(live.bad_free_array) == 0)
			when #config(
				ATLAS_NATIVE_FAULT_TEST,
				false,
			) {testing.expect(t, atlas_test_blocks() == 0 && atlas_test_bytes() == 0)}
		}
		delete(fixture)
	}
}
