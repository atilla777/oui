package ui_editor

import graphemes "../unicode_graphemes"
import "core:mem"

Editor_Rejection :: enum {
	None,
	Invalid_UTF8,
	Unsupported_Control,
	Glyph_Missing,
	Limit,
	Invalid_Range,
	Stale_Value,
	Source_Limit,
	Allocation,
}
Editor_Splice :: struct {
	value:       string,
	caret:       int,
	count:       int,
	rejection:   Editor_Rejection,
	byte_offset: int,
	allocator:   mem.Allocator,
}

destroy_editor_splice :: proc(result: ^Editor_Splice) {
	delete(result.value, result.allocator)
	result^ = {}
}

editor_splice :: proc(
	value: string,
	anchor, caret: int,
	insertion: string,
	maximum: Maybe(int) = nil,
	allocator := context.allocator,
) -> Editor_Splice {
	r := Editor_Splice {
		allocator = allocator,
	}
	if len(value) > 65536 || len(insertion) > 65536 {
		r.rejection = .Source_Limit; return r
	}
	for text in ([]string{value, insertion}) {
		if invalid, failed := graphemes.count(text).(graphemes.Invalid_UTF8); failed {
			r.rejection = .Invalid_UTF8; r.byte_offset = invalid.byte_offset; return r
		}
	}
	old_result, allocation := graphemes.try_boundaries(value, allocator)
	if allocation != nil {r.rejection = .Allocation; return r}
	old := old_result.([]int)
	defer delete(old, allocator)
	valid_anchor, valid_caret := false, false
	for offset in old {valid_anchor ||= anchor == offset; valid_caret ||= caret == offset}
	if !valid_anchor || !valid_caret {r.rejection = .Invalid_Range; return r}
	if len(value) - abs(caret - anchor) + len(insertion) >
	   65536 {r.rejection = .Source_Limit; return r}
	for rune, offset in insertion {
		if rune < 0x20 ||
		   (rune >= 0x7f && rune <= 0x9f) ||
		   rune == 0x2028 ||
		   rune == 0x2029 ||
		   rune == 0x061c ||
		   rune == 0x200e ||
		   rune == 0x200f ||
		   (rune >= 0x202a && rune <= 0x202e) ||
		   (rune >= 0x2066 && rune <= 0x2069) {
			r.rejection = .Unsupported_Control; r.byte_offset = offset; return r
		}
	}
	bytes, be := make([]byte, len(value) - abs(caret - anchor) + len(insertion), allocator)
	if be != nil {r.rejection = .Allocation; return r}
	lo, hi := min(anchor, caret), max(anchor, caret)
	copy(
		bytes[:lo],
		value[:lo],
	); copy(bytes[lo:], insertion); copy(bytes[lo + len(insertion):], value[hi:])
	r.value = string(bytes)
	new_result, ne := graphemes.try_boundaries(r.value, allocator)
	if ne != nil {delete(r.value, allocator); r.value = ""; r.rejection = .Allocation; return r}
	offsets := new_result.([]int)
	defer delete(offsets, allocator)
	r.count = len(offsets) - 1
	if limit, ok := maximum.?; ok && (limit < 0 || r.count > limit) {
		delete(r.value, allocator); r.value = ""; r.rejection = .Limit; return r
	}
	for offset in offsets {
		if offset >= min(anchor, caret) + len(insertion) {r.caret = offset; break}
	}
	return r
}
