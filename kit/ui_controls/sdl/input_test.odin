package ui_controls_sdl

import controls ".."
import base "../../ui_base"
import interaction "../../ui_interaction"
import layout "../../ui_layout"
import backend "../../ui_sdl"
import "core:testing"
import sdl "vendor:sdl3"

@(test)
slider_native_track_is_not_label_width_and_edges_are_shared :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	stamp, _ := base.begin_attempt(&p, 1)
	nodes := [2]layout.Node {
		{
			id = "slider",
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 300},
				y = {mode = .Fixed, value = 40},
			},
		},
		{
			id = "track",
			parent = "slider",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 100},
				y = {mode = .Fixed, value = 20},
			},
		},
	}
	g, e := layout.prepare(
		nodes[:],
		{drawable = {300, 40}, ui_scale = 1},
		{},
		context.allocator,
		stamp,
	); if !testing.expect(t, e.code == .None) {return}; defer layout.destroy_frame(&g)
	targets := [1]interaction.Target{{"slider", "button", true, true}}
	i, code := interaction.prepare(
		&g,
		targets[:],
		nil,
		context.allocator,
	); testing.expect(t, code == .Applied); defer interaction.destroy_frame(&i)
	ds := [1]controls.Description {
		{
			id = "level",
			node_id = "slider",
			kind = .Slider,
			track_id = "track",
			minimum = 0,
			maximum = 100,
			step = 1,
			value = 50,
		},
	}
	c, ce := controls.prepare(
		&i,
		{},
		ds[:],
		context.allocator,
	); if !testing.expect(t, ce.code == .None) {return}
	s := controls.create(); controls.commit(&s, &c); defer controls.destroy(&s)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	base.enter_commit(
		&p,
		stamp,
	); interaction.commit(&ctx, &i, "slider"); base.finish_commit(&p, stamp)
	device := backend.Input {
		window_id = 1,
	}
	a := create(context.allocator); defer destroy(&a)
	event: sdl.Event; event.button = {
		type     = .MOUSE_BUTTON_DOWN,
		windowID = 1,
		button   = 1,
		x        = 99.9,
		y        = 10,
	}
	n := backend.normalize_event(&device, &ctx, event, {300, 40})
	r := handle(&a, &s, &ctx, &g, n)
	testing.expect(
		t,
		r.consumed &&
		r.result.event != nil &&
		r.result.event.?.value == 100 &&
		a.capture_id == "level",
		"track endpoint maps to maximum",
	)
	testing.expect(t, s.frame.controls[0].value == 50)
	event.button.type = .MOUSE_BUTTON_UP; n = backend.normalize_event(&device, &ctx, event, {300, 40}); handle(&a, &s, &ctx, &g, n)
	testing.expect(t, a.capture_id == "", "release cleans capture even while not ready")
	ctx.frame.stamp.sequence = p.sequence; base.finish_commit(&p, ctx.frame.stamp)
	event.button.type = .MOUSE_BUTTON_DOWN; event.button.x = 250
	n = backend.normalize_event(&device, &ctx, event, {300, 40}); r = handle(&a, &s, &ctx, &g, n)
	testing.expect(
		t,
		r.result.event == nil && a.capture_id == "",
		"owner label/padding is not a rail",
	)
}
