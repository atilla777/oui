package ui_controls

import base "../ui_base"
import interaction "../ui_interaction"
import layers "../ui_layers"
import "core:testing"

@(test)
ordinary_modal_cancel_is_preserved_when_no_dialog_control_owns_it :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	f := make_fixture(t, &p, .Dialog); defer destroy_fixture(&f)
	c, e := prepare(
		&f.interaction,
		f.layer.frame.layers,
		nil,
		context.allocator,
		&f.geometry,
	); if !testing.expect(t, e.code == .None) {return}
	s := create(); commit(&s, &c); defer destroy(&s)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	stamp :=
		f.geometry.stamp; base.enter_commit(&p, stamp); interaction.commit(&ctx, &f.interaction); base.finish_commit(&p, stamp)
	r := dispatch(&s, &ctx, {kind = .Cancel, source = .Agent}, &f.layer)
	testing.expect(
		t,
		r.cancel != nil &&
		r.cancel.?.root_id == f.recipe.control.layer_id &&
		p.sequence == 1 &&
		!p.ready,
	)
}

@(test)
select_cancel_priority_and_refusal_are_source_and_descriptor_order_independent :: proc(
	t: ^testing.T,
) {
	for reverse in ([]bool{false, true}) {for disabled in ([]bool{false, true}) {for source in interaction.Source {
				p, _ := base.create(context.allocator); stamp, _ := base.begin_attempt(&p, 1)
				views := [4]interaction.Target_View {
					{
						description = {
							id = "select",
							role = "button",
							enabled = true,
							visible = true,
						},
						parent = "dialog",
						availability = .Applied,
					},
					{
						description = {
							id = "dialog",
							role = "dialog",
							enabled = true,
							visible = true,
						},
						availability = .Applied,
					},
					{
						description = {
							id = "popup",
							role = "popup",
							enabled = true,
							visible = true,
						},
						availability = .Applied,
					},
					{
						description = {
							id = "stay",
							role = "button",
							enabled = true,
							visible = true,
						},
						parent = "dialog",
						availability = .Applied,
					},
				}
				if disabled {views[0].availability = .Disabled}
				i := interaction.Frame {
					targets = views[:],
					stamp   = stamp,
				}
				modals := [1]layers.Modal {
					{"dialog", "select", true},
				}; popups := [1]layers.Popup{{"popup", "dialog", "select"}}
				plan := layers.Layers {
					modals = modals[:],
					popups = popups[:],
				}
				ds := [2]Description {
					{
						id = "dialog",
						node_id = "dialog",
						layer_id = "dialog",
						kind = .Dialog,
						open = true,
						initial_focus_id = "select",
						cancel_id = "stay",
						items = []Item{{"stay", "stay", "Stay"}},
					},
					{
						id = "select",
						node_id = "select",
						layer_id = "popup",
						owner_scope_id = "dialog",
						kind = .Select,
						open = true,
					},
				}
				if reverse {ds[0], ds[1] = ds[1], ds[0]}
				c, e := prepare(
					&i,
					plan,
					ds[:],
					context.allocator,
				); if !testing.expect(t, e.code == .None) {base.destroy(&p); continue}
				s := create(); commit(&s, &c)
				ctx := interaction.create(context.allocator, &p)
				owned, ok := interaction.try_copy_frame(
					&i,
					context.allocator,
				); testing.expect(t, ok)
				base.enter_commit(
					&p,
					stamp,
				); interaction.commit(&ctx, &owned); base.finish_commit(&p, stamp)
				ls := layers.State {
					frame = {layers = plan, stamp = stamp},
				}
				r := dispatch(&s, &ctx, {kind = .Cancel, source = source}, &ls)
				if disabled {testing.expect(t, r.dispatch.code == .Disabled && r.event == nil && r.cancel == nil && p.ready && p.sequence == 0)
				} else {testing.expect(
						t,
						r.event != nil &&
						r.event.?.control_id == "select" &&
						r.event.?.kind == .Close &&
						r.cancel == nil &&
						p.sequence == 1,
					)}
				destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
			}}}
}
