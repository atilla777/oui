package ui_editor
import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import text "../ui_text"
import "core:testing"
@(test)
destroy_recreate_same_family_address_does_not_revive_candidate :: proc(t: ^testing.T) {
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
		{
			description = {id = "field", role = "editor"},
			availability = .Applied,
			activation_owner = "editor",
		},
	}
	i := interaction.Frame {
		targets = views[:],
		stamp   = stamp,
	}
	blocks := [1]text.Text_Block {
		{node_id = "value", original_text = "aяb", font_id = "font", font_size = 12},
	}
	tf := text.Frame {
		stamp       = stamp,
		text_blocks = blocks[:],
	}
	s := create(); defer destroy(&s)
	c, ce := prepare(
		&s,
		&g,
		&i,
		&tf,
		[]Description{description()},
		metrics(),
	); defer destroy_candidate(&c)
	if !testing.expect(t, ce.code == .None && validate_candidate(&p, &s, &c)) {return}
	destroy(&s); s = create()
	testing.expect(
		t,
		!validate_candidate(&p, &s, &c),
		"a destroyed family owner cannot be replaced at the same address",
	)
}
