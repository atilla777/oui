package ui_inspect

import base "../ui_base"
import "core:fmt"
import "core:mem"
import "core:strings"

Phase :: enum {
	update,
	published_frame,
}
Severity :: enum {
	Info,
	Warning,
	Error,
}
Diagnostic_Record :: struct {
	code, id, source_hint, reference, detail: string,
	severity:                                 Severity,
	phase:                                    Phase,
	frame_id, attempt_revision:               Maybe(u64),
	expected:                                 bool,
	required, available:                      base.Extent,
	byte_offset, occurrence:                  Maybe(int),
}
Strict_Result :: struct {
	ok:                    bool,
	offending_diagnostics: []Diagnostic_Record,
}
strict_result :: proc(i: ^Inspection) -> Strict_Result {return {
		is_ready(i) && !i.historical && len(i.offending) == 0,
		i.offending,
	}}
destroy_diagnostic :: proc(d: Diagnostic_Record, a: mem.Allocator) {for s in ([5]string{d.code, d.id, d.source_hint, d.reference, d.detail}) {delete(
			s,
			a,
		)}}
copy_diagnostics :: proc(i: ^Inspection, supplied: []Diagnostic_Record) -> bool {
	a := i.allocator
	n := len(i.frame.diagnostics) + len(supplied)
	e: mem.Allocator_Error
	i.diagnostics, e = make([]Diagnostic_Record, n, a); if e != nil {return false}
	i.offending, e = make([]Diagnostic_Record, n, a); if e != nil {return false}
	i.offending_storage = i.offending
	bad := 0
	for k in 0 ..< n {
		code_buffer: [64]u8
		d: Diagnostic_Record
		if k < len(i.frame.diagnostics) {
			v := i.frame.diagnostics[k]
			d = {
				code      = fmt.bprintf(code_buffer[:], "layout.%v", v.kind),
				id        = v.id,
				severity  = .Warning,
				phase     = .published_frame,
				frame_id  = i.frame.id,
				required  = v.required,
				available = v.available,
			}
		} else {d = supplied[k - len(i.frame.diagnostics)]}
		for s in i.semantics {if s.id == d.id {d.source_hint = s.source_hint; break}}
		v := &i.diagnostics[k]; v^ = d
		v.code, v.id, v.source_hint, v.reference, v.detail = "", "", "", "", ""
		v.code, e = strings.clone(d.code, a); if e != nil {return false}
		v.id, e = strings.clone(d.id, a); if e != nil {return false}
		v.source_hint, e = strings.clone(d.source_hint, a); if e != nil {return false}
		v.reference, e = strings.clone(d.reference, a); if e != nil {return false}
		v.detail, e = strings.clone(d.detail, a); if e != nil {return false}
		if v.severity == .Error ||
		   (v.severity == .Warning && !v.expected) {i.offending[bad] = v^; bad += 1}
	}
	i.offending = i.offending[:bad]
	return true
}
