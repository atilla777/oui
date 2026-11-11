package ui_controls

import base "../ui_base"
import interaction "../ui_interaction"
import layers "../ui_layers"
import layout "../ui_layout"
import "core:testing"

@(test)
structural_dialog_results_and_declared_cancel_use_one_layer_sequence :: proc(t: ^testing.T) {
	for cancel in ([]bool{false, true}) {
		p, _ := base.create(context.allocator)
		stamp, _ := base.begin_attempt(&p, 1)
		nodes := [2]layout.Node {
			{
				id = "dialog",
				role = .Column,
				enabled = true,
				visible = true,
				layout = layout.Layout{},
			},
			{
				id = "stay",
				parent = "dialog",
				role = .Box,
				enabled = true,
				visible = true,
				layout = layout.Layout{},
			},
		}
		g, ge := layout.prepare(
			nodes[:],
			{drawable = {100, 100}, ui_scale = 1},
			{},
			context.allocator,
			stamp,
		); testing.expect(t, ge.code == .None)
		targets := [1]interaction.Target{{"stay", "button", true, true}}
		i, code := interaction.prepare(
			&g,
			targets[:],
			nil,
			context.allocator,
		); testing.expect(t, code == .Applied)
		modals := [1]layers.Modal{{"dialog", "stay", true}}
		plan := layers.Layers {
			modals = modals[:],
		}
		ds := [1]Description {
			{
				id = "question",
				node_id = "dialog",
				layer_id = "dialog",
				kind = .Dialog,
				open = true,
				initial_focus_id = "stay",
				cancel_id = "stay",
				items = []Item{{"stay", "stay", "Stay"}},
			},
		}
		c, e := prepare(&i, plan, ds[:], context.allocator, &g)
		if !testing.expect(
			t,
			e.code == .None,
		) {interaction.destroy_frame(&i); layout.destroy_frame(&g); base.destroy(&p); continue}
		s := create(); commit(&s, &c)
		ctx := interaction.create(context.allocator, &p)
		base.enter_commit(
			&p,
			stamp,
		); interaction.commit(&ctx, &i, "stay"); base.finish_commit(&p, stamp)
		// Borrowed read-only layer projection; no second owning focus Context.
		layer_state := layers.State {
			frame = {layers = plan, stamp = stamp},
		}
		a := Action {
			kind   = .Activate,
			id     = "stay",
			source = .Agent,
		}; if cancel {a.kind = .Cancel; a.id = ""}
		r := dispatch(&s, &ctx, a, &layer_state)
		if cancel {testing.expect(t, r.cancel != nil && r.cancel.?.root_id == "dialog", "dialog result retains its underlying single layer cancel")}
		testing.expect(
			t,
			r.event != nil &&
			r.event.?.kind == .Result &&
			r.event.?.item_id == "stay" &&
			r.event.?.sequence == 1 &&
			p.sequence == 1 &&
			!p.ready,
			"structural dialog owner must not block its declared result",
		)
		testing.expect(
			t,
			!dispatch(&s, &ctx, a, &layer_state).dispatch.has_event && p.sequence == 1,
		)
		destroy(
			&s,
		); interaction.destroy(&ctx); interaction.destroy_frame(&i); layout.destroy_frame(&g); base.destroy(&p)
	}
}
