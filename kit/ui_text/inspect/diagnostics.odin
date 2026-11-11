package ui_text_inspect
import family ".."
import common "../../ui_inspect"
import "core:fmt"
import "core:mem"
import "core:strings"
diagnostics :: proc(f: ^family.Frame, a: mem.Allocator) -> ([]common.Diagnostic_Record, bool) {
	r, e := make(
		[]common.Diagnostic_Record,
		len(f.text_diagnostics),
		a,
	); if e != nil {return nil, false}
	complete := false; defer {if !complete {destroy_diagnostics(r, a)}}
	for d, k in f.text_diagnostics {
		b: [128]u8; v := &r[k]
		v^ = {
			id        = d.node_id,
			severity  = .Info if d.expected else .Warning,
			phase     = .published_frame,
			frame_id  = f.id,
			expected  = d.expected,
			required  = d.required_extent,
			available = d.available_extent,
		}
		v.code, e = strings.clone(
			fmt.bprintf(b[:], "text.%v", d.kind),
			a,
		); if e != nil {return nil, false}
		v.detail, e = strings.clone(
			fmt.bprintf(
				b[:],
				"lines=%d/%d policy=%v",
				d.visible_line_count,
				d.natural_line_count,
				d.policy,
			),
			a,
		); if e != nil {return nil, false}
	}
	complete = true; return r, true
}
destroy_diagnostics :: proc(r: []common.Diagnostic_Record, a: mem.Allocator) {for d in r {delete(
			d.code,
			a,
		)
		delete(d.detail, a)}
	delete(r, a)}
