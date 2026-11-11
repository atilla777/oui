package ui_editor

import "base:runtime"
import "core:mem"
import "core:testing"

refuse :: proc(
	_: rawptr,
	_: mem.Allocator_Mode,
	_: int,
	_: int,
	_: rawptr,
	_: int,
	_: runtime.Source_Code_Location = #caller_location,
) -> (
	[]byte,
	mem.Allocator_Error,
) {
	return nil, .Out_Of_Memory
}

@(test)
splice_reports_allocator_refusal :: proc(t: ^testing.T) {
	r := editor_splice("abc", 0, 0, "я", nil, mem.Allocator{procedure = refuse})
	testing.expect(t, r.rejection == .Allocation && r.value == "")
}

@(test)
splice_keeps_unicode_and_control_oracles :: proc(t: ^testing.T) {
	for tc in ([]struct {
			value:               string,
			anchor, caret:       int,
			insertion, expected: string,
			count, end:          int,
		}{{"a", 1, 1, "\u0301", "a\u0301", 1, 3}, {"a\u0301я", 0, 3, "", "я", 1, 0}, {"👩\u200d👩x", 0, 11, "", "x", 1, 0}, {"🇺🇸🇨", 0, 8, "", "🇨", 1, 0}}) {
		r := editor_splice(tc.value, tc.anchor, tc.caret, tc.insertion)
		testing.expect(
			t,
			r.rejection == .None &&
			r.value == tc.expected &&
			r.count == tc.count &&
			r.caret == tc.end,
		)
		destroy_editor_splice(&r)
	}
	for insertion in ([]string{"\n", "\u202e", "\u2066", "\u200f", "\x00"}) {
		r := editor_splice("a", 1, 1, insertion)
		testing.expect(t, r.rejection == .Unsupported_Control); destroy_editor_splice(&r)
	}
	r := editor_splice("я", 1, 1, "x")
	testing.expect(t, r.rejection == .Invalid_Range); destroy_editor_splice(&r)
	r = editor_splice("a", 1, 1, "b", 1)
	testing.expect(t, r.rejection == .Limit); destroy_editor_splice(&r)
}
