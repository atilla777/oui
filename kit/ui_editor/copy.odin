package ui_editor
import base "../ui_base"
import "core:mem"
import "core:strings"
try_copy_frame :: proc(f: ^Frame, a := context.allocator) -> (Frame, bool) {
	r := Frame {
		allocator = a,
		drawable  = f.drawable,
		ui_scale  = f.ui_scale,
	}
	ok := false; defer {if !ok {destroy_frame(&r)}}
	if !base.retain(f.stamp) {return {}, false}; r.stamp = f.stamp
	ae: mem.Allocator_Error
	r.scope_id, ae = strings.clone(f.scope_id, a); if ae != nil {return {}, false}
	r.editors, ae = make([]View, len(f.editors), a); if ae != nil {return {}, false}
	for v, j in f.editors {
		e := &r.editors[j]; e^ = v
		e.id, e.node_id, e.text_node_id, e.label, e.value, e.font_id, e.font_revision =
			"", "", "", "", "", "", ""
		e.boundaries, e.stops, e.runs = nil, nil, nil
		for pair in ([]struct {
				src: string,
				dst: ^string,
			}{{v.id, &e.id}, {v.node_id, &e.node_id}, {v.text_node_id, &e.text_node_id}, {v.label, &e.label}, {v.value, &e.value}, {v.font_id, &e.font_id}, {v.font_revision, &e.font_revision}}) {
			pair.dst^, ae = strings.clone(pair.src, a); if ae != nil {return {}, false}
		}
		e.boundaries, ae = make(
			[]int,
			len(v.boundaries),
			a,
		); if ae != nil {return {}, false}; copy(e.boundaries, v.boundaries)
		e.stops, ae = make(
			[]f64,
			len(v.stops),
			a,
		); if ae != nil {return {}, false}; copy(e.stops, v.stops)
		e.runs, ae = make(
			[]Run,
			len(v.runs),
			a,
		); if ae != nil {return {}, false}; copy(e.runs, v.runs)
	}
	ok = true; return r, true
}
