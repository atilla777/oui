package ui_rich

import base "../ui_base"
import layout "../ui_layout"
import "core:mem"
import "core:testing"
pipeline_fixture :: proc(
	stamp: base.Frame_Stamp,
	a: mem.Allocator,
	metrics: Rich_Text_Metrics,
) -> (
	Candidate,
	Rich_Error,
) {
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
			source = "ab [size=20]cd[/size] [img id=\"star\" alt=\"star\" w=12 h=24/] ef gh ij kl",
			base_style = {font_id = "body", size = 16},
			options = {
				wrap = .WordWrap,
				overflow = .Ellipsis,
				max_lines = 1,
				overflow_expected = true,
			},
		},
	}
	return prepare(nodes, {drawable = {30, 100}, ui_scale = 1}, descriptions, metrics, a, stamp)
}
@(test)
rich_reader_survives_source_and_publication_destroy :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	stamp, _ := base.begin_attempt(&p, 1)
	c, e := pipeline_fixture(
		stamp,
		context.allocator,
		{measure = rich_fake_measure, image = rich_fake_image},
	)
	if !testing.expect(t, e.code == .None) {destroy_candidate(&c); return}
	r, copied := try_copy_frame(&c.frame)
	destroy_candidate(&c); base.destroy(&p)
	defer destroy_frame(&r)
	if !testing.expect(t, copied) {return}
	testing.expect(
		t,
		r.rich_blocks[0].node_id == "text" &&
		r.rich_blocks[0].ellipsized &&
		r.rich_blocks[0].document.runs[0].style.font_id == "body",
	)
}
