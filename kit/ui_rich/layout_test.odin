package ui_rich

import graphemes "../unicode_graphemes"
import "core:testing"

@(test)
ellipsis_keeps_graphemes_and_reports_unavailable_marker :: proc(t: ^testing.T) {
	m := Rich_Text_Metrics {
		measure = rich_fake_measure,
		image   = rich_fake_image,
	}
	for width in ([]f64{0, 3, 10, 30}) {
		d, _ := parse_rich_text(
			"a\u0301[img id=\"star\" alt=\"star\" w=12 h=24/]b",
			{font_id = "body", size = 10},
		)
		b := Rich_Block {
			document = d,
			base_style = {font_id = "body", size = 10},
			options = {overflow = .Ellipsis},
		}
		e := rich_layout_block(&b, width, m, context.allocator)
		if !testing.expect(
			t,
			e.code == .None,
		) {destroy_rich_block(&b, context.allocator); continue}
		e = resolve_rich_display(&b, {0, 0, width, 30}, 1, m, context.allocator)
		testing.expect(t, e.code == .None)
		if width == 0 {testing.expect(t, b.visible_line_count == 0)}
		if width == 3 {testing.expect(t, b.ellipsis_unavailable && len(b.lines[0].fragments) == 0)}
		if width ==
		   10 {testing.expect(t, b.ellipsized && b.lines[0].decoded_range == (Text_Source_Range{0, 3}))}
		if width == 30 {testing.expect(t, !b.hidden && !b.ellipsized)}
		destroy_rich_block(&b, context.allocator)
	}
}

rich_fake_measure :: proc(
	value: string,
	style: Rich_Style,
	user: rawptr,
) -> (
	Rich_Run_Metrics,
	Rich_Error_Code,
) {
	n := graphemes.count(value).(int)
	w := f64(n) * style.size / 2; if value == "AV" {w = 7}
	return {w, style.size, style.size * .75, style.size * .75, style.size * .25, 0, "fake-v1"},
		.None
}
rich_fake_image :: proc(id: string, user: rawptr) -> bool {return id == "star"}
@(test)
whole_run_kerning_unicode_nonbreaking_and_inline_objects :: proc(t: ^testing.T) {
	cases := []struct {
		source: string,
		width:  f64,
		count:  int,
		first:  Text_Source_Range,
	} {
		{"AV", 7, 1, {0, 2}},
		{"A[u]V[/u]", 7, 2, {0, 1}},
		{"a\u0301bc", 5, 3, {0, 3}},
		{"a\u00a0bq", 5, 2, {0, 4}},
		{"a\u202fbq", 5, 2, {0, 5}},
		{"a\r\n\rb\n", 100, 4, {0, 1}},
		{"a\u00a0[img id=\"star\" alt=\"star\" w=12 h=24/]b", 5, 2, {0, 6}},
	}
	for c in cases {
		d, e := parse_rich_text(c.source, {font_id = "body", size = 10})
		if !testing.expect(t, e.code == .None) {continue}
		b := Rich_Block {
			document = d,
			base_style = {font_id = "body", size = 10},
			options = {wrap = .WordWrap},
		}
		err := rich_layout_block(
			&b,
			c.width,
			{measure = rich_fake_measure, image = rich_fake_image},
			context.allocator,
		)
		testing.expect_value(t, err.code, Rich_Error_Code.None)
		testing.expect_value(t, len(b.lines), c.count)
		if len(b.lines) > 0 {testing.expect_value(t, b.lines[0].decoded_range, c.first)}
		destroy_rich_block(&b, context.allocator)
	}
}
