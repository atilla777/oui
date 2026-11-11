package ui_rich_inspect
import family ".."
import common "../../ui_inspect"
import "core:fmt"
import "core:mem"
import "core:strings"
diagnostics :: proc(f: ^family.Frame, a: mem.Allocator) -> ([]common.Diagnostic_Record, bool) {
	count := 0; for b in f.rich_blocks {if b.hidden {count += 1}}
	r, e := make([]common.Diagnostic_Record, count, a); if e != nil {return nil, false}
	complete := false; defer {if !complete {destroy_diagnostics(r, a)}}
	at := 0
	for block in f.rich_blocks {
		if !block.hidden {continue}; v := &r[at]; at += 1
		v^ = {
			id        = block.node_id,
			severity  = .Info if block.options.overflow_expected else .Warning,
			phase     = .published_frame,
			frame_id  = f.stamp.attempt,
			expected  = block.options.overflow_expected,
			required  = block.natural_extent,
			available = {block.content_width, 0},
		}
		v.code, e = strings.clone("rich.Hidden_Content", a); if e != nil {return nil, false}
		b: [192]u8
		v.detail, e = strings.clone(
			fmt.bprintf(
				b[:],
				"lines=%d/%d ellipsized=%v unavailable=%v",
				block.visible_line_count,
				len(block.lines),
				block.ellipsized,
				block.ellipsis_unavailable,
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
