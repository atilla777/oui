package ui_controls

import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"

@(test)
invalid_control_bindings_ranges_and_ownership_refuse_atomically :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	stamp, _ := base.begin_attempt(&p, 1)
	views := [3]interaction.Target_View {
		{description = {id = "button", role = "button"}, availability = .Applied},
		{description = {id = "item", role = "button"}, parent = "button", availability = .Applied},
		{description = {id = "tabs", role = "tabs"}, availability = .Invalid_Action},
	}
	f := interaction.Frame {
		targets = views[:],
		stamp   = stamp,
	}
	fixtures := []struct {
		d:    Description,
		code: Error_Code,
	} {
		{{id = "bad", node_id = "missing", kind = .Checkbox}, .Invalid_Control},
		{
			{id = "bad", node_id = "button", kind = .Slider, minimum = 0, maximum = 100, step = 3},
			.Invalid_Range,
		},
		{
			{
				id = "bad",
				node_id = "button",
				kind = .Slider,
				minimum = 0,
				maximum = 100,
				step = 10,
				value = 55,
			},
			.Invalid_Value,
		},
		{{id = "bad", node_id = "button", kind = .Checkbox, step = 1}, .Invalid_Control},
		{{id = "bad", node_id = "tabs", kind = .Tabs, selected_id = "missing"}, .Invalid_Item},
	}
	for fixture in fixtures {
		ds := [1]Description{fixture.d}; c, e := prepare(&f, {}, ds[:], context.allocator)
		testing.expect(
			t,
			e.code == fixture.code && c.controls == nil,
			"invalid metadata must not create a candidate",
		)
		destroy_candidate(&c)
	}
	ds := [2]Description {
		{id = "one", node_id = "button", kind = .Checkbox},
		{id = "two", node_id = "button", kind = .Toggle},
	}
	c, e := prepare(&f, {}, ds[:], context.allocator); defer destroy_candidate(&c)
	testing.expect(t, e.code == .Duplicate_Ownership)
}
