package ui_controls

import base "../ui_base"
import interaction "../ui_interaction"
import layers "../ui_layers"
import "core:testing"

@(test)
items_select_and_declared_dialog_return_controlled_intentions :: proc(t: ^testing.T) {
	for kind in ([]Kind{.Tabs, .List, .Select, .Dialog}) {
		p, _ := base.create(context.allocator)
		stamp, _ := base.begin_attempt(&p, 1)
		role := "container"; if kind == .Select {role = "button"}
		item_id := "item"; if kind == .List {item_id = "6:choice3:yes"}
		views := [3]interaction.Target_View {
			{
				description = {id = "owner", role = role, enabled = true, visible = true},
				availability = .Applied,
			},
			{
				description = {id = item_id, role = "button", enabled = true, visible = true},
				parent = "owner",
				availability = .Applied,
			},
			{
				description = {id = "popup", role = "popup", enabled = true, visible = true},
				availability = .Applied,
			},
		}
		f := interaction.Frame {
			targets = views[:],
			stamp   = stamp,
		}
		ds := [1]Description {
			{
				id = "choice",
				node_id = "owner",
				kind = kind,
				open = true,
				items = []Item{{"yes", item_id, "Yes"}},
			},
		}
		l := layers.Layers{}
		popups := [1]layers.Popup{{"popup", "", "owner"}}
		modals := [1]layers.Modal{{"owner", item_id, false}}
		if kind ==
		   .Select {views[1].parent = "popup"; ds[0].layer_id = "popup"; l.popups = popups[:]}
		if kind ==
		   .Dialog {ds[0].layer_id = "owner"; ds[0].initial_focus_id = item_id; l.modals = modals[:]}
		c, e := prepare(&f, l, ds[:], context.allocator)
		if !testing.expect(t, e.code == .None) {base.destroy(&p); continue}
		s := create(); commit(&s, &c)
		ctx := interaction.create(context.allocator, &p)
		owned, ok := interaction.try_copy_frame(&f, context.allocator); testing.expect(t, ok)
		base.enter_commit(
			&p,
			stamp,
		); interaction.commit(&ctx, &owned); base.finish_commit(&p, stamp)
		r := dispatch(&s, &ctx, {kind = .Activate, id = item_id, source = .Agent})
		want := Event_Kind.Item; if kind == .Dialog {want = .Result}
		testing.expect(
			t,
			r.event != nil &&
			r.event.?.kind == want &&
			r.event.?.item_id == "yes" &&
			s.frame.controls[0].selected_id == "",
			"item activation never applies selection",
		)
		destroy(&s); interaction.destroy(&ctx); base.destroy(&p)
	}
}

@(test)
select_cancel_precedes_dialog_and_never_falls_through :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	stamp, _ := base.begin_attempt(&p, 1)
	views := [3]interaction.Target_View {
		{
			description = {id = "select", role = "button", enabled = true, visible = true},
			parent = "dialog",
			availability = .Applied,
		},
		{
			description = {id = "dialog", role = "dialog", enabled = true, visible = true},
			availability = .Applied,
		},
		{
			description = {id = "popup", role = "popup", enabled = true, visible = true},
			availability = .Applied,
		},
	}
	f := interaction.Frame {
		targets = views[:],
		stamp   = stamp,
	}
	ds := [2]Description {
		{
			id = "dialog",
			node_id = "dialog",
			kind = .Dialog,
			open = true,
			layer_id = "dialog",
			initial_focus_id = "select",
		},
		{
			id = "select",
			node_id = "select",
			kind = .Select,
			open = true,
			layer_id = "popup",
			owner_scope_id = "dialog",
		},
	}
	modals := [1]layers.Modal{{"dialog", "select", false}}
	popups := [1]layers.Popup{{"popup", "dialog", "select"}}
	c, e := prepare(
		&f,
		{modals = modals[:], popups = popups[:]},
		ds[:],
		context.allocator,
	); if !testing.expect(t, e.code == .None) {return}
	s := create(); commit(&s, &c); defer destroy(&s)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	owned, ok := interaction.try_copy_frame(&f, context.allocator); testing.expect(t, ok)
	base.enter_commit(&p, stamp); interaction.commit(&ctx, &owned); base.finish_commit(&p, stamp)
	r := dispatch(&s, &ctx, {kind = .Cancel, source = .Agent})
	testing.expect(
		t,
		r.event != nil && r.event.?.control_id == "select" && r.event.?.kind == .Close,
	)
}
