package ui_style_inspect
import family ".."
import common "../../ui_inspect"
import "core:fmt"
import "core:mem"
import "core:strings"
diagnostics :: proc(f: ^family.Frame, a: mem.Allocator) -> ([]common.Diagnostic_Record, bool) {
	r, e := make(
		[]common.Diagnostic_Record,
		len(f.diagnostics),
		a,
	); if e != nil {return nil, false}
	complete := false; defer {if !complete {destroy_diagnostics(r, a)}}
	for d, k in f.diagnostics {
		b: [64]u8
		code, ce := strings.clone(
			fmt.bprintf(b[:], "presentation.%v", d.kind),
			a,
		); if ce != nil {return nil, false}
		r[k] = {
			code      = code,
			id        = d.id,
			severity  = .Error,
			phase     = .published_frame,
			frame_id  = f.stamp.attempt,
			reference = d.reference,
		}
	}
	complete = true; return r, true
}
destroy_diagnostics :: proc(r: []common.Diagnostic_Record, a: mem.Allocator) {for d in r {delete(
			d.code,
			a,
		)}
	delete(r, a)}
