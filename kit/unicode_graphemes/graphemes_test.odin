package unicode_graphemes

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:testing"
import "core:unicode/utf8"

refuse_boundaries_allocation :: proc(
	data: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old: rawptr,
	old_size: int,
	loc: runtime.Source_Code_Location,
) -> (
	[]u8,
	mem.Allocator_Error,
) {
	return nil, .Out_Of_Memory
}

@(test)
fallible_boundaries_match_the_original_and_report_refusal :: proc(t: ^testing.T) {
	for text in ([]string{"", "abc", "снова", "👩‍💻 é\r\n"}) {
		expected := boundaries(text).([]int); defer delete(expected)
		result, e := try_boundaries(text)
		if !testing.expect(t, e == nil) {return}
		actual := result.([]int); defer delete(actual)
		testing.expect(t, slice.equal(actual, expected))
		_, failure := try_boundaries(text, {refuse_boundaries_allocation, nil})
		testing.expect(t, failure != nil)
	}
	result, e := try_boundaries("\xff", {refuse_boundaries_allocation, nil})
	_, invalid := result.(Invalid_UTF8)
	testing.expect(t, e == nil && invalid)
}

expect_segmentation :: proc(t: ^testing.T, text: string, expected: []int) {
	result := boundaries(text)
	offsets, ok := result.([]int)
	if !testing.expect(t, ok) {return}
	defer delete(offsets)
	testing.expect(t, slice.equal(offsets, expected))
	n, valid := count(text).(int)
	testing.expect(t, valid)
	testing.expect_value(t, n, len(expected) - 1)
}

@(test)
empty_and_scalar_boundaries :: proc(t: ^testing.T) {
	expect_segmentation(t, "", []int{0})
	expect_segmentation(t, "Aя𐀀�", []int{0, 1, 3, 7, 10})
}

@(test)
malformed_utf8_reports_start_of_first_invalid_sequence :: proc(t: ^testing.T) {
	cases := []string {
		"\x80",
		"\xbf",
		"\xc0\xaf",
		"\xc1\xbf",
		"\xc2",
		"\xc2A",
		"\xe0\x80\x80",
		"\xed\xa0\x80",
		"\xed\xbf\xbf",
		"\xe2\x82",
		"\xe2A\xac",
		"\xe2\x82A",
		"\xf0\x80\x80\x80",
		"\xf4\x90\x80\x80",
		"\xf0\x9f\x92",
		"\xf0\x9fA\x80",
		"\xf0\x9f\x92A",
		"\xf5\x80\x80\x80",
		"\xff",
	}
	prefixes := []string{"", "я", "👩‍💻"}
	for bad in cases {
		for prefix in prefixes {
			text := strings.concatenate({prefix, bad})
			defer delete(text)
			result := boundaries(text)
			if offsets, valid := result.([]int); valid {delete(offsets)}
			a, a_ok := result.(Invalid_UTF8)
			b, b_ok := count(text).(Invalid_UTF8)
			testing.expect(t, a_ok && b_ok)
			testing.expect_value(t, a.byte_offset, len(prefix))
			testing.expect_value(t, b.byte_offset, len(prefix))
		}
	}
}

@(test)
unicode_15_1_complete_conformance_oracle :: proc(t: ^testing.T) {
	// Parse the original oracle, not expectations made by our table generator.
	lines := strings.split_lines(#load("data/GraphemeBreakTest.txt"))
	defer delete(lines)
	cases := 0
	for line, line_index in lines {
		body := line
		if comment := strings.index_byte(line, '#'); comment >= 0 {body = line[:comment]}
		fields := strings.fields(body)
		defer delete(fields)
		if len(fields) == 0 {continue}
		bytes := make([dynamic]u8)
		expected := make([dynamic]int)
		defer delete(bytes)
		defer delete(expected)
		for field in fields {
			if field == "÷" {
				append(&expected, len(bytes))
			} else if field != "×" {
				cp, ok := strconv.parse_uint(field, 16)
				if !testing.expect(t, ok) {return}
				encoded, size := utf8.encode_rune(rune(cp))
				append(&bytes, ..encoded[:size])
			}
		}
		result := boundaries(string(bytes[:]))
		offsets, valid := result.([]int)
		if !testing.expect(t, valid) {return}
		n, count_valid := count(string(bytes[:])).(int)
		matches := slice.equal(offsets, expected[:]) && count_valid && n == len(expected) - 1
		delete(offsets)
		if !testing.expect(t, matches, "Unicode oracle boundary/count mismatch") {
			fmt.eprintf("GraphemeBreakTest.txt line %d: %s\n", line_index + 1, line)
			return
		}
		cases += 1
	}
	testing.expect_value(t, cases, 1187)
}

@(test)
rule_order_and_context_regressions :: proc(t: ^testing.T) {
	expect_segmentation(t, "a\r\nb", []int{0, 1, 3, 4})
	expect_segmentation(t, "a\u2028\u0301", []int{0, 1, 4, 6})
	expect_segmentation(t, "\u0600a", []int{0, 3})
	expect_segmentation(t, "\u0600\u0301a", []int{0, 4, 5})
	expect_segmentation(t, "\u1100\u1161\u11a8", []int{0, 9})
	expect_segmentation(t, "👩\u0308‍💻", []int{0, 13})
	expect_segmentation(t, "a‍💻", []int{0, 4, 8})
	expect_segmentation(t, "👩‍\u0308💻", []int{0, 9, 13})
	expect_segmentation(t, "🇦🇧🇨🇩🇪", []int{0, 8, 16, 20})
	expect_segmentation(t, "🇦\u0308🇧🇨", []int{0, 6, 14})
	expect_segmentation(t, "क्‍क", []int{0, 12})
	expect_segmentation(t, "क्‌क", []int{0, 9, 12})
	// The pure core accepts controls/noncharacters/private use, not UI policy.
	expect_segmentation(t, "\x00\t\u0085\u2029\uE000\U0010FFFF", []int{0, 1, 2, 4, 7, 10, 14})
}

@(test)
every_unicode_scalar_is_valid_without_font_or_language_restrictions :: proc(t: ^testing.T) {
	for cp: rune = 0; cp <= 0x10FFFF; cp += 1 {
		if 0xD800 <= cp && cp <= 0xDFFF {continue}
		bytes, size := utf8.encode_rune(cp)
		n, ok := count(string(bytes[:size])).(int)
		if !testing.expect(t, ok && n == 1) {
			fmt.eprintf("Scalar U+%X rejected\n", cp)
			return
		}
	}
}

@(test)
explicit_allocator_owned_offsets_and_allocation_free_count :: proc(t: ^testing.T) {
	tracker, temp_tracker: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracker, context.allocator)
	defer mem.tracking_allocator_destroy(&tracker)
	mem.tracking_allocator_init(&temp_tracker, context.temp_allocator)
	defer mem.tracking_allocator_destroy(&temp_tracker)
	allocator := mem.tracking_allocator(&tracker)
	previous := context
	context.allocator = allocator
	context.temp_allocator = mem.tracking_allocator(&temp_tracker)
	valid := true
	for _ in 0 ..< 1000 {
		n, ok := count("é\r\n👩‍💻🇦🇧क्‍क").(int)
		valid = valid && ok && n == 5
		error, failed := count("é\xff").(Invalid_UTF8)
		valid = valid && failed && error.byte_offset == 3
	}
	context = previous
	testing.expect(t, valid)
	testing.expect_value(t, tracker.total_allocation_count, 0)
	testing.expect_value(t, temp_tracker.total_allocation_count, 0)

	input := strings.clone("éx")
	result := boundaries(input, allocator)
	delete(input)
	offsets, ok := result.([]int)
	if !testing.expect(t, ok) {return}
	testing.expect(t, slice.equal(offsets, []int{0, 3, 4}))
	testing.expect(t, tracker.total_allocation_count > 0)
	delete(offsets, allocator)
	// Even after building a valid prefix, error must release partial storage.
	_, failed := boundaries("abc\xf0\x9f", allocator).(Invalid_UTF8)
	testing.expect(t, failed)
	testing.expect_value(t, len(tracker.allocation_map), 0)
	testing.expect_value(t, len(tracker.bad_free_array), 0)
}

@(test)
long_runs_do_not_inherit_ui_limits :: proc(t: ^testing.T) {
	marks := strings.repeat("\u0301", 40000)
	defer delete(marks)
	expect_segmentation(t, marks, []int{0, 80000})
	letters := strings.repeat("a", 70000)
	defer delete(letters)
	result := boundaries(letters)
	offsets, ok := result.([]int)
	if !testing.expect(t, ok) {return}
	defer delete(offsets)
	if !testing.expect_value(t, len(offsets), 70001) {return}
	for offset, i in offsets {testing.expect_value(t, offset, i)}
	n, valid := count(letters).(int)
	testing.expect(t, valid && n == 70000)
}
