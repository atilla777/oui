package ui_controls

import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"

@(test)
list_reorder_keeps_item_identity_and_empty_selection_never_defaults :: proc(t: ^testing.T) {
	items := [2]Item{{id = "a", label = "Alpha"}, {id = "b", label = "Beta"}}
	d := Description {
		id          = "list",
		kind        = .List,
		selected_id = "b",
		items       = items[:],
	}
	first, e := compose_control(
		d,
		"base",
		"root",
		context.allocator,
	); if !testing.expect(t, e.code == .None) {return}; defer destroy_composition(&first)
	items[0], items[1] = items[1], items[0]
	second: Composition
	second, e = compose_control(
		d,
		"base",
		"root",
		context.allocator,
	); if !testing.expect(t, e.code == .None) {return}; defer destroy_composition(&second)
	testing.expect(
		t,
		second.control.items[0].id == "b" &&
		second.control.items[0].node_id == first.control.items[1].node_id &&
		second.control.selected_id == "b",
	)
	empty_selection: Composition
	d.selected_id = ""; empty_selection, e = compose_control(d, "base", "root", context.allocator); defer destroy_composition(&empty_selection)
	testing.expect(t, e.code == .None && empty_selection.control.selected_id == "")
	empty: Composition
	d.items =
		nil; empty, e = compose_control(d, "base", "root", context.allocator); defer destroy_composition(&empty)
	testing.expect(
		t,
		e.code == .None &&
		len(empty.control.items) == 0 &&
		len(empty.targets) == 0 &&
		len(empty.scroll) == 1,
	)
	bad: Composition
	d.selected_id = "missing"; bad, e = compose_control(d, "base", "root", context.allocator); defer destroy_composition(&bad)
	testing.expect(t, e.code == .Invalid_Item && len(bad.nodes) == 0)
}

@(test)
slider_i64_boundary_proposals_are_exact_and_do_not_mutate_the_model :: proc(t: ^testing.T) {
	for upper in ([]bool{false, true}) {
		p, _ := base.create(context.allocator); f := make_fixture(t, &p, .Slider)
		d :=
			f.recipe.control; d.minimum = min(i64); d.maximum = min(i64) + 2; d.step = 1; d.value = d.minimum
		delta := i64(-1); if upper {d.value = d.maximum; delta = 1}
		ds := [1]Description {
			d,
		}; c, e := prepare(&f.interaction, f.layer.frame.layers, ds[:], context.allocator, &f.geometry)
		if !testing.expect(t, e.code == .None) {destroy_fixture(&f); base.destroy(&p); continue}
		s := create(); commit(&s, &c)
		ctx := interaction.create(context.allocator, &p); stamp := f.geometry.stamp
		base.enter_commit(
			&p,
			stamp,
		); interaction.commit(&ctx, &f.interaction); base.finish_commit(&p, stamp)
		r := dispatch(&s, &ctx, {kind = .Adjust, id = d.node_id, source = .Agent, value = delta})
		testing.expect(
			t,
			r.dispatch.has_event &&
			r.event == nil &&
			s.frame.controls[0].value == d.value &&
			p.sequence == 1,
		)
		destroy(&s); interaction.destroy(&ctx); destroy_fixture(&f); base.destroy(&p)
	}
}
