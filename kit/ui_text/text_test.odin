package ui_text

import base "../ui_base"
import layout "../ui_layout"
import "core:mem"
import "core:testing"
import "core:unicode/utf8"

font :: proc(
	id: string,
	size: f64,
	user: rawptr,
) -> (
	Text_Font_Metrics,
	Text_Metric_Error,
) {return {8, 2, 10, "fixture"}, .None}
measure :: proc(
	text, id: string,
	size: f64,
	user: rawptr,
) -> (
	Text_Line_Metrics,
	Text_Metric_Error,
) {
	w := f64(utf8.rune_count_in_string(text)) * 5
	return {w, {w, 10}}, .None
}

fractional_legacy_measure :: proc(
	text, id: string,
	size: f64,
	user: rawptr,
) -> (
	Text_Line_Metrics,
	Text_Metric_Error,
) {
	return {29.33333333333333, {29.33333333333333, 10}}, .None
}

@(test)
fractional_intrinsic_content_keeps_the_complete_measured_ink :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s, _ := base.begin_attempt(&p, 0)
	structure := fixture(100)
	structure[1].layout = layout.Layout {
		x = {mode = .Content},
		y = {mode = .Content},
	}
	nodes := [1]Text_Node{{"text", "fraction", {"fixture"}, 10, {}}}
	c, e := prepare(
		nodes[:],
		structure[:],
		{drawable = {150, 150}, ui_scale = 1.5},
		{font, fractional_legacy_measure, validate, nil},
		context.allocator,
		s,
	)
	defer destroy_candidate(&c)
	if !testing.expect(t, e.code == .None) {return}
	n, found := layout.find(&c.geometry, "text")
	if testing.expect(t, found) {
		testing.expect(t, n.measured.w <= n.content.w + 1e-8 && n.measured.h <= n.content.h + 1e-8)
	}
	for d in c.text.text_diagnostics {testing.expect(t, d.kind != .Pixel_Overflow)}
}

@(test)
input_bytes_do_not_escape_prepare :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s, _ := base.begin_attempt(&p, 0)
	structure := fixture(20)
	bytes := [3]u8{'a', 'b', 'c'}
	nodes := [1]Text_Node{{"text", string(bytes[:]), {"fixture"}, 10, {}}}
	c, e := prepare(
		nodes[:],
		structure[:],
		{drawable = {100, 100}, ui_scale = 1},
		{font, measure, validate, nil},
		context.allocator,
		s,
	)
	if !testing.expect(t, e.code == .None) {return}; defer destroy_candidate(&c)
	mem.zero_slice(bytes[:])
	testing.expect(
		t,
		c.text.text_blocks[0].original_text == "abc" &&
		c.text.text_blocks[0].lines[0].display_text == "abc",
	)
}

@(test)
error_view_preserves_outer_and_nested_codes :: proc(t: ^testing.T) {
	e := describe_error({code = .Existing, existing = {.Allocation, "node"}})
	testing.expect(
		t,
		e.family == .Text &&
		e.stage == .Prepare &&
		e.id == "node" &&
		e.code == u32(Text_Error_Code.Existing) &&
		e.existing_code == u32(layout.Error_Code.Allocation),
	)
}
validate :: proc(
	text, id: string,
	size: f64,
	user: rawptr,
) -> (
	Text_Metric_Error,
	int,
) {return .None, 0}
fixture :: proc(width: f64) -> [2]layout.Node {
	return {
		{
			id = "root",
			role = .Column,
			layout = layout.Layout{x = {mode = .Fixed, value = width}, y = {mode = .Content}},
			enabled = true,
			visible = true,
		},
		{
			id = "text",
			parent = "root",
			role = .Content,
			layout = layout.Layout{x = {mode = .Fill}, y = {mode = .Content}},
			enabled = true,
			visible = true,
		},
	}
}

@(test)
paragraph_egc_nonbreaking_and_ellipsis_characterization :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s, _ := base.begin_attempt(&p, 1)
	for test in ([]struct {
			value:   string,
			width:   f64,
			options: Text_Options,
			first:   string,
			count:   int,
		}{{"a\r\nb\n", 30, {}, "a", 3}, {"a\u0301b", 5, {wrap = .WordWrap}, "a\u0301", 2}, {"a\u00a0b", 5, {wrap = .WordWrap}, "a\u00a0b", 1}, {"abcdef", 15, {overflow = .Ellipsis}, "ab…", 1}, {"a\u0301bc", 15, {overflow = .Ellipsis}, "a\u0301…", 1}}) {
		structure := fixture(test.width)
		nodes := [1]Text_Node{{"text", test.value, {"fixture"}, 10, test.options}}
		c, e := prepare(
			nodes[:],
			structure[:],
			{drawable = {100, 100}, ui_scale = 1},
			{font, measure, validate, nil},
			context.allocator,
			s,
		)
		if testing.expect(t, e.code == .None) {
			b := c.text.text_blocks[0]
			testing.expect(t, len(b.lines) == test.count && b.lines[0].display_text == test.first)
		}
		destroy_candidate(&c)
	}
}
@(test)
unicode_wrap_source_and_owned_copy :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s, _ := base.begin_attempt(&p, 1)
	structure := fixture(15)
	nodes := [1]Text_Node{{"text", "a\u0301b c", {"fixture"}, 10, {wrap = .WordWrap}}}
	c, e := prepare(
		nodes[:],
		structure[:],
		{drawable = {100, 100}, ui_scale = 1},
		{font, measure, validate, nil},
		context.allocator,
		s,
	)
	if !testing.expect(t, e.code == .None) {return}
	defer destroy_candidate(&c)
	b := &c.text.text_blocks[0]
	testing.expect(
		t,
		len(b.lines) == 2 &&
		b.lines[0].display_text == "a\u0301b" &&
		b.lines[1].display_text == "c",
	)
	testing.expect(t, b.lines[0].source_byte_ranges[0].end == len("a\u0301b"))
	testing.expect(t, c.geometry.nodes[0].bounds.h == 20)
	reader, copied := try_copy_frame(&c.text, context.allocator)
	if !testing.expect(t, copied, "owning reader must copy text") {return}
	defer destroy_frame(&reader)
	destroy_candidate(&c)
	testing.expect(t, reader.text_blocks[0].lines[0].display_text == "a\u0301b")
}
@(test)
addressed_unicode_and_metric_errors :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	s, _ := base.begin_attempt(&p, 1)
	structure := fixture(20)
	for text in ([]string{"bad\xff", "a\tb"}) {
		nodes := [1]Text_Node{{"text", text, {"fixture"}, 10, {}}}
		c, e := prepare(
			nodes[:],
			structure[:],
			{drawable = {100, 100}, ui_scale = 1},
			{font, measure, validate, nil},
			context.allocator,
			s,
		)
		destroy_candidate(&c)
		testing.expect(
			t,
			e.id == "text" && (e.code == .Invalid_UTF8 || e.code == .Unsupported_Text_Control),
		)
	}
}
