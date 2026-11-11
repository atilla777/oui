package ui_gestures
import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import "core:testing"
@(test)
destroy_recreate_same_family_address_does_not_revive_candidate :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	stamp, _ := base.begin_attempt(&p, 7)
	nodes := [3]layout.Resolved_Node {
		{description = {id = "root", role = .Row}},
		{description = {id = "source", parent = "root", role = .Box}},
		{description = {id = "target", parent = "root", role = .Box}},
	}
	g := layout.Frame {
		nodes    = nodes[:],
		stamp    = stamp,
		ui_scale = 1,
	}
	views := [2]interaction.Target_View {
		{
			description = {id = "source", role = "button"},
			availability = .Applied,
			activation_owner = "gestures",
		},
		{description = {id = "target", role = "drop"}, availability = .Applied},
	}
	i := interaction.Frame {
		targets = views[:],
		stamp   = stamp,
	}
	s := create(); defer destroy(&s); ds := descriptions([]string{"card"})
	c, ce := prepare(&s, &g, &i, nil, ds[:], 7); defer destroy_candidate(&c)
	if !testing.expect(t, ce.code == .None && validate_candidate(&p, &s, &c)) {return}
	destroy(&s); s = create()
	testing.expect(t, !validate_candidate(&p, &s, &c))
}
