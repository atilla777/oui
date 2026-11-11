package app

@(test)
g21_original_native_resize_pair_is_preserved_alongside_large_readable_pair :: proc(t: ^testing.T) {
	for size in ([][3]i32{{800, 960, 720}, {960, 800, 600}, {1280, 1200, 900}, {1200, 1280, 960}}) {
		w, h := test_resize_extent(.Diagnostics_Performance, size[0])
		testing.expect(
			t,
			w == size[1] && h == size[2],
			"G21 original 800/960 and larger readable resize pairs are separate fixtures",
		)
	}
}

import sdl "vendor:sdl3"

@(test)
recovery_r_is_reachable_with_russian_physical_keyboard :: proc(t: ^testing.T) {
	e: sdl.Event
	e.key = {
		type     = .KEY_DOWN,
		key      = sdl.Keycode(0x043a),
		scancode = .R,
	}
	testing.expect(
		t,
		recovery_key(e),
		"host recovery must remain reachable at physical R under the supported ru input layout",
	)
}

import "core:testing"

@(test)
host_rejects_invalid_start_before_window :: proc(t: ^testing.T) {
	testing.expect(t, !run(nil))
	testing.expect(t, !run([]string{"--font", "no-such-showcase-font.ttf"}))
	testing.expect(t, !run([]string{"--font", "missing", "--section", "unknown"}))
}
