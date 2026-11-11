package ui_custom_sdl

import ui ".."
import base "../../ui_base"
import interaction "../../ui_interaction"
import layout "../../ui_layout"
import backend "../../ui_sdl"
import "core:testing"
import sdl "vendor:sdl3"

publish_input :: proc(
	t: ^testing.T,
	p: ^base.Publication,
	ctx: ^interaction.Context,
	s: ^ui.State,
) -> bool {
	stamp, _ := base.begin_attempt(p, 1)
	nodes := []layout.Node {
		{
			id = "root",
			role = .Stack,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
		},
		{
			id = "under",
			parent = "root",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 40},
				y = {mode = .Fixed, value = 40},
			},
		},
		{
			id = "disk",
			parent = "root",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 40},
				y = {mode = .Fixed, value = 40},
			},
		},
	}
	g, ge := layout.prepare(
		nodes,
		{drawable = {100, 100}, ui_scale = 1},
		{},
		context.allocator,
		stamp,
	); defer layout.destroy_frame(&g)
	if !testing.expect(t, ge.code == .None) {return false}
	i, ie := interaction.prepare(
		&g,
		[]interaction.Target{{"under", "button", true, true}, {"disk", "button", true, true}},
		[]interaction.Capture_Claim{{"disk", "custom"}},
		context.allocator,
	); defer interaction.destroy_frame(&i)
	if !testing.expect(
		t,
		ie == .Applied && interaction.bind_activation_owner(&i, "disk", "custom") == .Applied,
	) {return false}
	c, ce := ui.prepare(
		&g,
		&i,
		[]ui.Description {
			{
				node_id = "disk",
				type_id = "circle",
				revision = "1",
				payload = []u8{3},
				validate = valid,
				measure = measure,
				hit = inside,
			},
		},
	); defer ui.destroy_candidate(&c)
	if !testing.expect(t, ce.code == .None && ui.validate_candidate(p, &c)) {return false}
	base.enter_commit(
		p,
		stamp,
	); interaction.commit(ctx, &i); ui.commit(s, &c); base.finish_commit(p, stamp)
	return true
}
@(test)
one_normalized_pointer_path_keeps_circle_shape_and_one_activation :: proc(t: ^testing.T) {
	for point, index in ([][2]f32{{1, 1}, {20, 20}}) {
		p, _ := base.create(
			context.allocator,
		); ctx := interaction.create(context.allocator, &p); s := ui.create()
		device := backend.Input {
			window_id = 1,
		}
		if !publish_input(
			t,
			&p,
			&ctx,
			&s,
		) {ui.destroy(&s); interaction.destroy(&ctx); base.destroy(&p); continue}
		event: sdl.Event; event.button = {
			type     = .MOUSE_BUTTON_DOWN,
			windowID = 1,
			button   = 1,
			x        = point[0],
			y        = point[1],
		}
		r := handle(&s, &ctx, backend.normalize_event(&device, &ctx, event, {100, 100}))
		want := "under"; if index == 1 {want = "disk"}
		testing.expect(
			t,
			r.consumed && r.dispatch.code == .Applied && ctx.focus_id == want && !p.ready,
		)
		if publish_input(t, &p, &ctx, &s) {
			event.button.type = .MOUSE_BUTTON_UP
			r = handle(&s, &ctx, backend.normalize_event(&device, &ctx, event, {100, 100}))
			testing.expect(
				t,
				r.consumed &&
				r.dispatch.has_event &&
				r.dispatch.event.id == want &&
				p.sequence == 1 &&
				!p.ready,
			)
			r = handle(&s, &ctx, backend.normalize_event(&device, &ctx, event, {100, 100}))
			testing.expect(t, !r.dispatch.has_event && p.sequence == 1)
		}
		ui.destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	}
}
