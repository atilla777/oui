package ui_text

import base "../ui_base"
import layout "../ui_layout"

try_copy_frame :: proc(source: ^Frame, allocator: mem.Allocator) -> (Frame, bool) {
	r := Frame {
		drawable  = source.drawable,
		allocator = allocator,
		id        = source.id,
		ui_scale  = source.ui_scale,
	}
	complete := false; defer {if !complete {destroy_frame(&r)}}
	if !base.retain(source.stamp) {return {}, false}
	r.stamp = source.stamp
	if try_clone_text_metadata(source, &r) != nil {return {}, false}
	complete = true
	return r, true
}
import "core:mem"
import "core:slice"
import "core:strings"

destroy_frame :: proc(f: ^Frame) {destroy_text(f); base.release(f.stamp); f^ = {}}
destroy_candidate :: proc(c: ^Candidate) {destroy_frame(&c.text); layout.destroy_frame(
		&c.geometry,
	)}
free_text_block :: proc(b: Text_Block, a: mem.Allocator) {
	delete(
		b.node_id,
		a,
	); delete(b.original_text, a); delete(b.font_id, a); delete(b.font_revision, a); free_text_lines(b.lines, a)
}
try_clone_text_block :: proc(
	s: Text_Block,
	a: mem.Allocator,
) -> (
	Text_Block,
	mem.Allocator_Error,
) {
	r := s; r.node_id, r.original_text, r.font_id, r.font_revision, r.lines = "", "", "", "", nil
	complete := false; defer {if !complete {free_text_block(r, a)}}
	e: mem.Allocator_Error
	r.node_id, e = strings.clone(s.node_id, a); if e != nil {return {}, e}
	r.original_text, e = strings.clone(s.original_text, a); if e != nil {return {}, e}
	r.font_id, e = strings.clone(s.font_id, a); if e != nil {return {}, e}
	r.font_revision, e = strings.clone(s.font_revision, a); if e != nil {return {}, e}
	r.lines, e = make([]Text_Line, len(s.lines), a); if e != nil {return {}, e}
	for line, i in s.lines {
		l := line; l.display_text, l.source_byte_ranges = "", nil; r.lines[i] = l
		r.lines[i].display_text, e = strings.clone(
			line.display_text,
			a,
		); if e != nil {return {}, e}
		r.lines[i].source_byte_ranges, e = slice.clone(
			line.source_byte_ranges,
			a,
		); if e != nil {return {}, e}
	}
	complete = true; return r, nil
}
try_clone_text_metadata :: proc(s, r: ^Frame) -> mem.Allocator_Error {
	a := r.allocator
	e: mem.Allocator_Error
	r.text_blocks, e = make([]Text_Block, len(s.text_blocks), a); if e != nil {return e}
	for b, i in s.text_blocks {r.text_blocks[i], e = try_clone_text_block(b, a); if e != nil {return e}}
	r.text_diagnostics, e = make(
		[]Text_Diagnostic,
		len(s.text_diagnostics),
		a,
	); if e != nil {return e}
	for d, i in s.text_diagnostics {
		r.text_diagnostics[i] = d; r.text_diagnostics[i].node_id = ""
		r.text_diagnostics[i].node_id, e = strings.clone(d.node_id, a); if e != nil {return e}
	}
	return nil
}
