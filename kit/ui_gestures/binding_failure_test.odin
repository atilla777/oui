package ui_gestures

import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:mem"
import "core:testing"

@(test)
activation_binding_refusal_is_allocation_not_invalid_description :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	stamp, _ := base.begin_attempt(&p, 7)
	nodes := [1]layout.Resolved_Node {
		{
			description = {id = "source", role = .Box},
			bounds = {w = 100, h = 20},
			paint_clip = {w = 100, h = 20},
		},
	}
	g := layout.Frame {
		nodes    = nodes[:],
		stamp    = stamp,
		ui_scale = 1,
	}
	views := [1]interaction.Target_View {
		{description = {id = "source", role = "button"}, availability = .Applied},
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
	ds := [1]Description {
		{
			id = "drag",
			node_id = "source",
			kind = .Drag_Source,
			payload_id = "card",
			payload_type = "card",
		},
	}
	s := create(); defer destroy(&s)
	refs := p.lifetime.references
	c, e := prepare(&s, &g, &i, nil, ds[:], 7)
	testing.expect(
		t,
		e.code == .Allocation && e.id == "drag",
		"EDIT-001: interaction allocator refusal must retain Allocation",
	)
	testing.expect(
		t,
		fault.requests == 1 &&
		views[0].activation_owner == "" &&
		c.frame.gestures == nil &&
		p.lifetime.references == refs,
	)
	destroy_candidate(&c)
	views[0].activation_owner = "foreign"; fault.requests = 0
	c, e = prepare(&s, &g, &i, nil, ds[:], 7)
	testing.expect(
		t,
		e.code == .Invalid && views[0].activation_owner == "foreign" && fault.requests == 0,
	)
	destroy_candidate(&c)
}
