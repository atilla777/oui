package ui_controls

import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"

@(test)
rejects_wrong_roles_layer_bindings_ownership_and_item_ancestry :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	stamp, _ := base.begin_attempt(&p, 1)
	views := [5]interaction.Target_View {
		{
			description = {id = "button", role = "button", visible = true, enabled = true},
			availability = .Applied,
		},
		{
			description = {id = "aux", role = "button", visible = true, enabled = true},
			parent = "button",
			availability = .Applied,
		},
		{
			description = {id = "container", role = "container", visible = true, enabled = true},
			availability = .Applied,
		},
		{
			description = {id = "outside", role = "decoration", visible = true, enabled = true},
			availability = .Applied,
		},
		{
			description = {id = "item", role = "button", visible = true, enabled = true},
			parent = "outside",
			availability = .Applied,
		},
	}
	f := interaction.Frame {
		targets = views[:],
		stamp   = stamp,
	}
	cases := []Description {
		{id = "bad", kind = .Checkbox, node_id = "container"},
		{id = "bad", kind = .Checkbox, node_id = "button", items = []Item{{"x", "aux", "X"}}},
		{id = "bad", kind = .Slider, node_id = "button", maximum = 100, step = 1, checked = true},
		{
			id = "bad",
			kind = .Slider,
			node_id = "button",
			maximum = 100,
			step = 1,
			track_id = "outside",
		},
		{id = "bad", kind = .Select, node_id = "button", open = true, layer_id = "outside"},
		{id = "bad", kind = .Dialog, node_id = "container", open = true, layer_id = "container"},
		{
			id = "bad",
			kind = .Tooltip,
			node_id = "container",
			layer_id = "container",
			trigger_id = "button",
		},
		{id = "bad", kind = .Tabs, node_id = "container", items = []Item{{"x", "item", "X"}}},
		{id = "bad", kind = .List, node_id = "container", items = []Item{{"x", "aux", "X"}}},
	}
	for d in cases {
		ds := [1]Description {
			d,
		}; c, e := prepare(&f, {}, ds[:], context.allocator); destroy_candidate(&c)
		testing.expect(
			t,
			e.code != .None && c.controls == nil,
			"invalid family binding must refuse without publishing metadata",
		)
	}
	ds := [2]Description {
		{
			id = "slider",
			kind = .Slider,
			node_id = "button",
			maximum = 100,
			step = 1,
			increment_id = "aux",
		},
		{id = "toggle", kind = .Toggle, node_id = "aux"},
	}
	c, e := prepare(&f, {}, ds[:], context.allocator); defer destroy_candidate(&c)
	testing.expect(
		t,
		e.code == .Duplicate_Ownership,
		"auxiliary targets cannot have two control owners",
	)
}
