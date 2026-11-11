package ui_editor

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import text "../ui_text"
import "core:mem"
import "core:testing"

@(test)
activation_binding_refusal_is_allocation_not_invalid_description :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	stamp, _ := base.begin_attempt(&p, 1)
	nodes := [2]layout.Resolved_Node {
		{description = {id = "field", role = .Stack}, content = {w = 100, h = 20}},
		{
			description = {id = "value", parent = "field", role = .Content},
			paint_clip = {w = 100, h = 20},
		},
	}
	g := layout.Frame {
		nodes    = nodes[:],
		stamp    = stamp,
		ui_scale = 1,
	}
	views := [1]interaction.Target_View {
		{description = {id = "field", role = "editor"}, availability = .Applied},
	}
	fault := Fault {
		backing = context.allocator,
		refuse  = 1,
	}
	i := interaction.Frame {
		targets   = views[:],
		stamp     = stamp,
		allocator = mem.Allocator{fault_allocator, &fault},
	}
	blocks := [1]text.Text_Block {
		{node_id = "value", original_text = "aяb", font_id = "font", font_size = 12},
	}
	tf := text.Frame {
		stamp       = stamp,
		text_blocks = blocks[:],
	}
	s := create(); defer destroy(&s)
	refs := p.lifetime.references
	c, e := prepare(&s, &g, &i, &tf, []Description{description()}, metrics())
	testing.expect(
		t,
		e.code == .Allocation && e.id == "name",
		"EDIT-001: interaction allocator refusal must retain Allocation",
	)
	testing.expect(
		t,
		fault.requests == 1 &&
		views[0].activation_owner == "" &&
		c.frame.editors == nil &&
		p.lifetime.references == refs,
	)
	destroy_candidate(&c)
	// A foreign activation owner is still invalid input, not resource refusal.
	views[0].activation_owner = "foreign"; fault.requests = 0
	c, e = prepare(&s, &g, &i, &tf, []Description{description()}, metrics())
	testing.expect(
		t,
		e.code == .Invalid && views[0].activation_owner == "foreign" && fault.requests == 0,
	)
	destroy_candidate(&c)
}
