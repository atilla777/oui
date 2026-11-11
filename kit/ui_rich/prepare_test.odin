package ui_rich

import base "../ui_base"
import layout "../ui_layout"
import "core:testing"

@(test)
effective_state_color_preserves_equal_override_grapheme_oracle :: proc(t: ^testing.T) {
	d, e := parse_rich_text(
		"a[color=#f0f0f0ff]\u0301[/color]",
		{font_id = "body", size = 16, color = {240, 240, 240, 255}},
	)
	defer destroy_rich_document(&d)
	testing.expect(t, e.code == .None)
	disabled, de := parse_rich_text(
		"a[color=#f0f0f0ff]\u0301[/color]",
		{font_id = "body", size = 16, color = {90, 90, 90, 255}},
	)
	defer destroy_rich_document(&disabled)
	testing.expect(t, de.code == .Invalid_Grapheme_Boundary)
}

@(test)
owned_two_stage_width_dependent_layout_and_failure_barrier :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s := create(); defer destroy(&s)
	nodes := []layout.Node {
		{
			id = "root",
			role = .Column,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Fill}},
		},
		{
			id = "text",
			parent = "root",
			role = .Content,
			enabled = true,
			visible = true,
			layout = layout.Layout{x = {mode = .Fixed, value = 30}, y = {mode = .Content}},
		},
	}
	descriptions := []Description {
		{
			id = "text",
			source = "ab cd ef",
			base_style = {font_id = "body", size = 16},
			options = {wrap = .WordWrap, overflow = .Ellipsis, max_lines = 1},
		},
	}
	stamp, _ := base.begin_attempt(&p, 1)
	c, e := prepare(
		nodes,
		{drawable = {30, 100}, ui_scale = 1},
		descriptions,
		{measure = rich_fake_measure, image = rich_fake_image},
		context.allocator,
		stamp,
	)
	defer destroy_candidate(&c)
	if !testing.expect(t, e.code == .None && validate_candidate(&p, &c)) {return}
	testing.expect(
		t,
		c.frame.rich_blocks[0].ellipsized &&
		c.frame.rich_blocks[0].hidden &&
		c.frame.rich_blocks[0].visible_line_count == 1,
	)
	base.enter_commit(&p, stamp); commit(&s, &c); base.finish_commit(&p, stamp)
	before := raw_data(s.frame.rich_blocks)
	descriptions[0].source = "a[b]\u0301[/b]"
	stamp, _ = base.begin_attempt(&p, 1)
	failed, fe := prepare(
		nodes,
		{drawable = {30, 100}, ui_scale = 1},
		descriptions,
		{measure = rich_fake_measure, image = rich_fake_image},
		context.allocator,
		stamp,
	)
	defer destroy_candidate(&failed)
	testing.expect(
		t,
		fe.code == .Invalid_Grapheme_Boundary &&
		!p.ready &&
		raw_data(s.frame.rich_blocks) == before,
	)
}
