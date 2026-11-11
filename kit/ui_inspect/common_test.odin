package ui_inspect

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:testing"

@(test)
owning_common_projection_and_refusal :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator)
	s, _ := base.begin_attempt(&p, 3)
	nodes := [2]layout.Node {
		{
			id = "root",
			role = .Column,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
		},
		{
			id = "button",
			parent = "root",
			role = .Box,
			enabled = true,
			visible = true,
			layout = layout.Layout {
				x = {mode = .Fixed, value = 40},
				y = {mode = .Fixed, value = 20},
			},
		},
	}
	g, ge := layout.prepare(
		nodes[:],
		{drawable = {100, 100}, ui_scale = 1},
		{},
		context.allocator,
		s,
	)
	if !testing.expect(t, ge.code == .None) {base.destroy(&p); return}
	targets := [1]interaction.Target{{"button", "button", true, true}}
	f, fe := interaction.prepare(&g, targets[:], nil, context.allocator)
	testing.expect(t, fe == .Applied)
	caps: [Action]bool; caps[.Activate] = true
	input := Inspection_Input {
		frame              = &g,
		interaction        = &f,
		ready              = true,
		model_revision     = 3,
		published_revision = 3,
		semantics          = []Semantic{{"button", "button", "Имя", "source:1"}},
		capabilities       = caps,
		focus_id           = "button",
	}
	i, e := capture(input, context.allocator)
	testing.expect(t, e == .None)
	input.published_revision = 2
	bad, be := capture(input, context.allocator); destroy_inspection(&bad)
	testing.expect(t, be == .Metadata_Mismatch)
	layout.destroy_frame(&g); interaction.destroy_frame(&f)
	defer destroy_inspection(&i)
	v, ve := inspect(&i, "button")
	parent, has_parent := v.parent_index.?
	testing.expect(t, ve == .None && v.name == "Имя" && v.focused && has_parent && parent == 0)
	testing.expect(t, len(i.children[0]) == 1 && i.children[0][0] == 1)
	testing.expect(t, action_status(&i, "button", .Activate).code == .Applied)
	testing.expect(t, action_status(&i, "missing", .Activate).code == .Not_Found)
	base.destroy(&p)
	testing.expect(t, action_status(&i, "button", .Activate).code == .Not_Ready)
	i.ready, i.historical = false, true
	testing.expect(
		t,
		action_status(&i, "button", .Activate).code == .Not_Ready && !strict_result(&i).ok,
	)
	indices, qe := find(&i, {.Name, "Имя"}, context.allocator); defer delete(indices)
	testing.expect(t, qe == .None && len(indices) == 1 && indices[0] == 1)
}
