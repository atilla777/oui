package ui_debug
import inspect "../ui_inspect"
// Explicit projections must still describe the captured immutable common frame.
// This check never derives family data or dispatches an application action.
projection_error :: proc(c: ^Capture, protocol: int) -> string {
	if c.error != "" {return c.error}
	if c.inspection.ready && !inspect.is_ready(&c.inspection) {return "Not_Ready"}
	if c.required_protocol != 0 &&
	   c.required_protocol != protocol {return "Unsupported_Projection"}
	f := &c.inspection.frame
	if c.frame.drawable != f.drawable ||
	   c.frame.ui_scale != f.ui_scale ||
	   len(c.nodes) != len(f.nodes) {return "Metadata_Mismatch"}
	for n, k in c.nodes {
		g := f.nodes[k]
		if n.resolved.description.id != g.description.id ||
		   n.resolved.description.parent != g.description.parent ||
		   n.resolved.bounds != g.bounds ||
		   n.resolved.content != g.content ||
		   n.resolved.clip != g.clip ||
		   n.resolved.paint_clip != g.paint_clip ||
		   n.resolved.enabled != g.enabled ||
		   n.resolved.visible != g.visible {return "Metadata_Mismatch"}
	}
	return ""
}
