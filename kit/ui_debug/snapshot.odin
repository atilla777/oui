package ui_debug
import base "../ui_base"
import "core:encoding/json"
import "core:mem"
Snapshot_Metadata :: struct {
	window_size:             base.Extent,
	backend, build_revision: string,
	build_dirty:             bool,
	overlays:                [3]bool,
}
Snapshot_Document :: struct {
	protocol:                                                   int,
	frame_id, model_revision, published_revision:               u64,
	result:                                                     Result,
	drawable, window_size, window_to_drawable:                  base.Extent,
	ui_scale:                                                   f64,
	resource_revision, theme_revision, backend, build_revision: string,
	build_dirty:                                                bool,
	overlays:                                                   [3]bool,
}
encode_snapshot :: proc(
	c: ^Capture,
	capabilities: Capabilities,
	m: Snapshot_Metadata,
	a: mem.Allocator,
	protocol := 10,
) -> []u8 {
	i := &c.inspection
	if protocol == 17 || projection_error(c, protocol) != "" {return nil}
	if c.error != "" ||
	   !i.ready ||
	   m.window_size.w <= 0 ||
	   m.window_size.h <= 0 ||
	   (c.required_protocol != 0 && c.required_protocol != protocol) {return nil}
	observation: json.Value; raw: []u8
	if len(c.observation) > 0 {
		e: json.Error
		if protocol ==
		   10 {observation, e = parse_checked_observation(string(c.observation), context.temp_allocator)} else {observation, e = json.parse(string(c.observation), allocator = context.temp_allocator)}
		if e != nil {return nil}
		if protocol == 14 ||
		   protocol == 15 ||
		   protocol == 16 ||
		   protocol == 17 {observation = nil; raw = c.observation}
	}
	d := Snapshot_Document {
		protocol = protocol,
		frame_id = i.frame.id,
		model_revision = i.model_revision,
		published_revision = i.published_revision,
		result = {
			frame = c.frame,
			capabilities = capabilities,
			family = c.family,
			nodes = c.nodes,
			diagnostics = i.diagnostics,
			observation = observation,
		},
		drawable = i.frame.drawable,
		window_size = m.window_size,
		window_to_drawable = {
			i.frame.drawable.w / m.window_size.w,
			i.frame.drawable.h / m.window_size.h,
		},
		ui_scale = i.frame.ui_scale,
		resource_revision = c.frame.resource_revision,
		theme_revision = c.frame.theme_revision,
		backend = m.backend,
		build_revision = m.build_revision,
		build_dirty = m.build_dirty,
		overlays = m.overlays,
	}
	data := encode(d, a); if data == nil {return nil}
	if c.fields !=
	   nil {old := data; data = encode_result_projection(old, c.fields, a); delete(old, a)}
	if data != nil &&
	   len(raw) > 0 {old := data; data = encode_observation(old, raw, a); delete(old, a)}
	return data
}
