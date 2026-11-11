package ui_rich

import "core:strings"
import "core:testing"

@(test)
rich_parser_styles_and_source :: proc(t: ^testing.T) {
	d, e := parse_rich_text(
		"A[b]B[i]C[/i][/b]\\[D",
		{font_id = "body", size = 16, color = {1, 2, 3, 255}},
	)
	defer destroy_rich_document(&d)
	testing.expect(t, e.code == .None)
	testing.expect_value(t, d.decoded, "ABC[D")
	testing.expect_value(t, len(d.runs), 4)
	if len(d.runs) == 4 {
		testing.expect(t, d.runs[1].style.bold)
		testing.expect(t, d.runs[2].style.bold && d.runs[2].style.italic)
	}
}

@(test)
rich_parser_objects_escapes_and_owned_copy :: proc(t: ^testing.T) {
	s := "[color=#12aB00fF][size=28][u]a\u0301[/u][/size][/color][img id=\"star\" alt=\"звезда \\\"\\[\\]\\\\\" w=24 h=32/]"
	d, e := parse_rich_text(s, {font_id = "body", size = 16})
	defer destroy_rich_document(&d)
	testing.expect_value(t, e.code, Rich_Error_Code.None)
	testing.expect_value(t, d.decoded, "a\u0301\ufffc")
	testing.expect_value(t, len(d.runs), 2)
	if len(d.runs) == 2 {
		testing.expect_value(t, d.runs[0].style.size, f64(28))
		testing.expect(t, d.runs[0].style.underline)
		testing.expect_value(t, d.runs[0].style.color, Color{0x12, 0xab, 0, 0xff})
		testing.expect_value(t, d.runs[1].alt, "звезда \"[]\\")
		testing.expect_value(t, d.runs[1].width, f64(24))
		testing.expect_value(t, d.runs[1].height, f64(32))
	}
	c, copied := try_copy_document(&d, context.allocator)
	testing.expect(t, copied)
	destroy_rich_document(&d)
	defer destroy_rich_document(&c)
	testing.expect_value(t, c.source, s)
	testing.expect_value(t, c.alt_text, "a\u0301звезда \"[]\\")
	esc, ee := parse_rich_text("\\[\\]\\\\\\\"", {})
	defer destroy_rich_document(&esc)
	testing.expect_value(t, ee.code, Rich_Error_Code.None)
	testing.expect_value(t, esc.decoded, "[]\\\"")
	if len(esc.mappings) ==
	   4 {testing.expect_value(t, esc.mappings[0].source_range, Text_Source_Range{0, 2})} else {testing.expect(t, false)}
}

@(test)
rich_parser_rejects_invalid_inputs :: proc(t: ^testing.T) {
	cases := []struct {
		s:      string,
		code:   Rich_Error_Code,
		offset: int,
	} {
		{"x[wat]", .Invalid_Markup, 1},
		{"[b]x[/i]", .Invalid_Markup, 4},
		{"x]", .Invalid_Markup, 1},
		{"\\q", .Invalid_Markup, 0},
		{"x\\", .Invalid_Markup, 1},
		{"[size=01]x[/size]", .Invalid_Attribute, 0},
		{"[size=129]", .Invalid_Attribute, 0},
		{"[color=#fffffffff]", .Invalid_Attribute, 0},
		{"[color=#zzffffff]", .Invalid_Attribute, 0},
		{"[img id=\"a\" alt=\"\" w=1 h=1/]", .Invalid_Attribute, 0},
		{"[img id=\"a\" alt=\"x\" h=1 w=1/]", .Invalid_Attribute, 0},
		{"[img id=\"a\" alt=\"x\" w=257 h=1/]", .Invalid_Attribute, 0},
		{"a[b]\u0301[/b]", .Invalid_Grapheme_Boundary, 4},
		{"[img id=\"a\" alt=\"x\" w=1 h=1/]\u0301", .Invalid_Grapheme_Boundary, 0},
		{"x\ufffc", .Unsupported_Text_Control, 1},
		{"x\t", .Unsupported_Text_Control, 1},
		{"\xff", .Invalid_UTF8, 0},
	}
	for c in cases {
		d, e := parse_rich_text(c.s, {size = 16}); defer destroy_rich_document(&d)
		testing.expect_value(t, e.code, c.code)
		testing.expect_value(t, e.source_range.start, c.offset)
		testing.expect_value(t, d.source, "")
	}
	// Idempotent markup within a single EGC is not a real style boundary.
	d, e := parse_rich_text("[b]a[b]\u0301[/b][/b]", {size = 16})
	defer destroy_rich_document(&d)
	testing.expect_value(t, e.code, Rich_Error_Code.None)
	testing.expect_value(t, len(d.runs), 1)
}

@(test)
rich_parser_limits :: proc(t: ^testing.T) {
	for count in ([]int{4096, 4097}) {
		s := strings.repeat("[b][/b]", 4096); defer delete(s)
		if count == 4097 {next := strings.concatenate({s, "[b]"}); delete(s); s = next}
		d, e := parse_rich_text(s, {}); defer destroy_rich_document(&d)
		testing.expect(t, (e.code == .None) == (count == 4096))
	}
	for count in ([]int{4096, 4097}) {
		s := strings.repeat("a[b]b[/b]", 2048); defer delete(s)
		if count == 4097 {next := strings.concatenate({s, "a"}); delete(s); s = next}
		d, e := parse_rich_text(s, {}); defer destroy_rich_document(&d)
		testing.expect(t, (e.code == .None) == (count == 4096))
	}
	for n in ([]int{65536, 65537}) {
		s := strings.repeat("a", n); defer delete(s)
		d, e := parse_rich_text(s, {}); defer destroy_rich_document(&d)
		testing.expect(t, (e.code == .None) == (n == 65536))
	}
	for n in ([]int{16, 17}) {
		a := strings.repeat("[b]", n); defer delete(a)
		b := strings.repeat("[/b]", n); defer delete(b)
		s := strings.concatenate({a, "a", b}); defer delete(s)
		d, e := parse_rich_text(s, {}); defer destroy_rich_document(&d)
		testing.expect(t, (e.code == .None) == (n == 16))
	}
}

@(test)
rich_alt_has_independent_text_space :: proc(t: ^testing.T) {
	d, e := parse_rich_text("[img id=\"x\" alt=\"\ufffc\" w=1 h=1/]", {})
	defer destroy_rich_document(&d)
	testing.expect_value(t, e.code, Rich_Error_Code.None)
	testing.expect_value(t, d.alt_text, "\ufffc")
}
