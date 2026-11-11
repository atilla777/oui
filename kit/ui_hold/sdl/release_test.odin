package ui_hold_sdl

import hold ".."
import base "../../ui_base"
import interaction "../../ui_interaction"
import backend "../../ui_sdl"
import "core:testing"
import sdl "vendor:sdl3"

@(test)
mouse_release_without_valid_coordinates_is_not_lost_while_blocked :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := hold.create(context.allocator); defer hold.destroy(&s)
	rebuild(t, &p, &ctx, &s); a: Adapter; device := backend.Input {
		window_id = 1,
	}
	e: sdl.Event; e.button = {
		type     = .MOUSE_BUTTON_DOWN,
		windowID = 1,
		button   = 1,
		x        = 10,
		y        = 10,
	}
	r := handle(
		&a,
		&s,
		&ctx,
		backend.normalize_event(&device, &ctx, e, {100, 40}),
	); testing.expect(t, r.consumed && s.live.phase == .Holding)
	e.button.type = .MOUSE_BUTTON_UP
	r = handle(&a, &s, &ctx, backend.normalize_event(&device, &ctx, e, {}))
	testing.expect(
		t,
		r.consumed && a.has_pending,
		"physical up must survive unavailable coordinate projection",
	)
	rebuild(t, &p, &ctx, &s); step(&a, &s, &ctx, 900000)
	testing.expect(t, s.live.phase == .Idle && p.sequence == 0)
}
