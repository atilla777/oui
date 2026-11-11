package ui_editor
import base "../ui_base"
import interaction "../ui_interaction"
import layout "../ui_layout"
import text "../ui_text"
import "core:mem"
import "core:testing"

@(test)
prepare_allocation_positions_clean_and_stale_candidates_cannot_commit :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(); defer destroy(&s)
	if !publish(t, &p, &ctx, &s, description()) {return}
	stamp, _ := base.begin_attempt(&p, 1)
	nodes := [2]layout.Resolved_Node {
		{description = {id = "field", role = .Stack}, content = {w = 100, h = 20}},
		{
			description = {id = "value", parent = "field", role = .Box},
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
	tracking: mem.Tracking_Allocator; mem.tracking_allocator_init(&tracking, context.allocator); defer mem.tracking_allocator_destroy(&tracking)
	tracking.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array
	fault := Fault {
		backing = mem.tracking_allocator(&tracking),
	}; a := mem.Allocator{fault_allocator, &fault}
	refs := p.lifetime.references
	c, ce := prepare(&s, &g, &i, &tf, []Description{description()}, metrics(), a, "modal")
	if !testing.expect(t, ce.code == .None && validate_candidate(&p, &s, &c)) {return}
	count := fault.requests
	testing.expect(t, c.frame.scope_id == "modal")
	other := create(); defer destroy(&other)
	testing.expect(t, !validate_candidate(&p, &other, &c))
	base.begin_attempt(&p, 1)
	testing.expect(t, !validate_candidate(&p, &s, &c))
	destroy_candidate(&c)
	for position in 1 ..= count {
		fault.requests, fault.refuse = 0, position
		c, ce = prepare(&s, &g, &i, &tf, []Description{description()}, metrics(), a, "modal")
		testing.expect(t, ce.code == .Allocation && c.frame.editors == nil)
		destroy_candidate(&c)
		testing.expect(
			t,
			tracking.current_memory_allocated == 0 &&
			len(tracking.bad_free_array) == 0 &&
			p.lifetime.references == refs,
		)
	}
	// Same application revision recovers without losing the old owning frame.
	testing.expect(t, s.frame.editors[0].value == "aяb" && !p.ready)
	if !publish(t, &p, &ctx, &s, description()) {return}
	testing.expect(t, p.ready && p.sequence == 0)
}
