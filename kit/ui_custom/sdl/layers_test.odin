package ui_custom_sdl

import ui ".."
import base "../../ui_base"
import interaction "../../ui_interaction"
import layers "../../ui_layers"
import layout "../../ui_layout"
import backend "../../ui_sdl"
import "core:testing"
import sdl "vendor:sdl3"

@(test)
layered_circle_uses_the_one_layer_traversal_and_popup_shield :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	ls := layers.create(context.allocator); defer layers.destroy(&ls)
	cs := ui.create(); defer ui.destroy(&cs)
	device := backend.Input {
		window_id = 1,
	}
	for phase in 0 ..< 2 {
		stamp, _ := base.begin_attempt(&p, 1)
		nodes := []layout.Node {
			{
				id = "scene",
				role = .Stack,
				enabled = true,
				visible = true,
				layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
			},
			{
				id = "base",
				parent = "scene",
				role = .Stack,
				enabled = true,
				visible = true,
				layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
			},
			{
				id = "under",
				parent = "base",
				role = .Box,
				enabled = true,
				visible = true,
				layout = layout.Layout {
					x = {mode = .Fixed, value = 40},
					y = {mode = .Fixed, value = 40},
				},
			},
			{
				id = "popup",
				parent = "scene",
				role = .Stack,
				enabled = true,
				visible = true,
				layout = layout.Layout {
					x = {mode = .Fixed, value = 40},
					y = {mode = .Fixed, value = 40},
				},
			},
			{
				id = "disk",
				parent = "popup",
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
		if !testing.expect(t, ge.code == .None) {return}
		lc, le := layers.prepare(
			&ls,
			&ctx,
			&g,
			[]interaction.Target{{"under", "button", true, true}, {"disk", "button", true, true}},
			[]interaction.Capture_Claim{{"disk", "custom"}},
			{base_root_id = "base", popups = []layers.Popup{{"popup", "", "under"}}},
			context.allocator,
		)
		defer layers.destroy_candidate(&lc)
		if !testing.expect(t, le.code == .None) {return}
		if !testing.expect(
			t,
			interaction.bind_activation_owner(&lc.interaction, "disk", "custom") == .Applied,
		) {return}
		c, ce := ui.prepare(
			&g,
			&lc.interaction,
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
		if !testing.expect(t, ce.code == .None) {return}
		n, code := layers.hit_test(&lc.frame, &g, &lc.interaction, 1, 1, ui.hit_predicate, &c)
		testing.expect(
			t,
			n == nil && code == .Not_Found,
			"a transparent corner cannot bypass a popup shield",
		)
		n, code = layers.hit_test(&lc.frame, &g, &lc.interaction, 20, 20, ui.hit_predicate, &c)
		testing.expect(t, code == .Applied && n.description.id == "disk")
		testing.expect(t, ui.validate_candidate(&p, &c) && layers.validate_candidate(&p, &lc))
		base.enter_commit(
			&p,
			stamp,
		); layers.commit(&ls, &ctx, &lc); ui.commit(&cs, &c); base.finish_commit(&p, stamp)
		e: sdl.Event; e.button = {
			type     = .MOUSE_BUTTON_DOWN,
			windowID = 1,
			button   = 1,
			x        = 20,
			y        = 20,
		}
		if phase == 1 {e.button.type = .MOUSE_BUTTON_UP}
		normalized := backend.normalize_event(&device, &ctx, e, {100, 100})
		// One current layer traversal; selected=true forbids the custom adapter from
		// repeating a rectangular/default traversal and losing layer order/shields.
		target, selected_code := layers.hit_test(
			&ls.frame,
			&g,
			&ctx.frame,
			normalized.x,
			normalized.y,
			ui.hit_predicate,
			&cs.frame,
		)
		if !testing.expect(t, selected_code == .Applied) {return}
		r := handle(&cs, &ctx, normalized, target.description.id, true)
		if phase ==
		   0 {testing.expect(t, r.consumed && r.dispatch.code == .Applied && ctx.pressed_id == "disk" && !p.ready)} else {
			testing.expect(
				t,
				r.consumed &&
				r.dispatch.has_event &&
				r.dispatch.event.id == "disk" &&
				p.sequence == 1 &&
				!p.ready,
			)
		}
	}
}
