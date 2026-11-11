package main

import "core:testing"
import sdl "vendor:sdl3"

@(test)
native_wheel_retains_three_anchor_item_heights_and_flipped_sign :: proc(t: ^testing.T) {
	r: Runtime; init(&r); defer destroy(&r); testing.expect(t, publish(&r))
	e: sdl.Event; e.wheel = {
		type     = .MOUSE_WHEEL,
		windowID = 1,
		mouse_x  = 10,
		mouse_y  = 140,
		y        = -1,
	}
	a := input(
		&r,
		e,
	); testing.expect(t, a.scroll.code == .Applied && r.scroll.pending.delta_y == 90, "legacy wheel quantum is 3 * anchor item height (30), not a fixed pixel quantum")
	testing.expect(t, publish(&r)); e.wheel.direction = .FLIPPED
	a = input(
		&r,
		e,
	); testing.expect(t, a.scroll.code == .Applied && r.scroll.pending.delta_y == -90)
}
