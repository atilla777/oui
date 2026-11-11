package ui_controls

import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"

@(test)
recipes_reject_obvious_invalid_values_before_allocating_a_composition :: proc(t: ^testing.T) {
	cases := []Description {
		{kind = .Checkbox},
		{id = "bad", kind = Kind(99)},
		{id = "bad", kind = .Slider, maximum = 100, step = 0},
		{id = "bad", kind = .Slider, minimum = 10, maximum = 0, step = 1},
		{id = "bad", kind = .Slider, maximum = 100, step = 10, value = 55},
		{id = "bad", kind = .Toggle, step = 1},
		{id = "bad", kind = .Tabs, items = []Item{{id = ""}}},
		{id = "bad", kind = .List, items = []Item{{id = "same"}, {id = "same"}}},
	}
	for d in cases {p, e := compose_control(d, "base", "root", context.allocator); testing.expect(t, e.code != .None && len(p.nodes) == 0); destroy_composition(&p)}
}

@(test)
control_cannot_take_a_target_bound_to_exclusive_hold_completion :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	f := make_fixture(t, &p, .Checkbox); defer destroy_fixture(&f)
	testing.expect(
		t,
		interaction.bind_activation_owner(&f.interaction, f.recipe.control.node_id, "hold") ==
		.Applied,
	)
	ds := [1]Description{f.recipe.control}
	c, e := prepare(
		&f.interaction,
		f.layer.frame.layers,
		ds[:],
		context.allocator,
		&f.geometry,
	); defer destroy_candidate(&c)
	testing.expect(
		t,
		e.code == .Duplicate_Ownership,
		"controls cannot bypass or simultaneously own hold",
	)
}
