package main

import "core:unicode/utf8"
import base "ui:ui_base"
import layout "ui:ui_layout"
import text "ui:ui_text"

font :: proc(
	id: string,
	size: f64,
	user: rawptr,
) -> (
	text.Text_Font_Metrics,
	text.Text_Metric_Error,
) {return {8, 2, 10, "fixture"}, .None}
measure :: proc(
	s, id: string,
	size: f64,
	user: rawptr,
) -> (
	text.Text_Line_Metrics,
	text.Text_Metric_Error,
) {w := f64(utf8.rune_count_in_string(s)) * 5; return {w, {w, 10}}, .None}
validate :: proc(
	s, id: string,
	size: f64,
	user: rawptr,
) -> (
	text.Text_Metric_Error,
	int,
) {return .None, 0}
main :: proc() {
	p, e := base.create(context.allocator); assert(e == .None); defer base.destroy(&p)
	s, _ := base.begin_attempt(&p, 1)
	nodes := [1]layout.Node {
		{
			id = "text",
			role = .Content,
			layout = layout.Layout{x = {mode = .Fixed, value = 15}, y = {mode = .Content}},
			enabled = true,
			visible = true,
		},
	}
	texts := [1]text.Text_Node{{"text", "a\u0301b c", {"fixture"}, 10, {wrap = .WordWrap}}}
	c, error := text.prepare(
		texts[:],
		nodes[:],
		{drawable = {100, 100}, ui_scale = 1},
		{font, measure, validate, nil},
		context.allocator,
		s,
	)
	assert(error.code == .None); defer text.destroy_candidate(&c)
	assert(
		len(c.text.text_blocks[0].lines) == 2 &&
		c.text.text_blocks[0].lines[0].display_text == "a\u0301b",
	)
	reader, copied := text.try_copy_frame(
		&c.text,
		context.allocator,
	); assert(copied); defer text.destroy_frame(&reader)
	text.destroy_candidate(&c); base.destroy(&p)
	assert(reader.text_blocks[0].lines[1].display_text == "c")
}
