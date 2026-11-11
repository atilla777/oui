package ui_debug
import "core:encoding/json"
import "core:mem"

// Stock json rejects nested any. These are fixed existing DTO fields, not a
// general reflection serializer, global marshaler or extension registry.
Object_Field :: struct {
	name:  string,
	value: any,
}
// Only locally encoded immutable fragments; never unchecked request bytes.
Encoded_Value :: distinct []u8
copy_bytes :: proc(data: []u8, a: mem.Allocator) -> []u8 {r, e := make([]u8, len(data), a); if e !=
	   nil {return nil}
	copy(r, data)
	return r}
encode_object :: proc(fields: []Object_Field, a: mem.Allocator) -> []u8 {
	b := make([dynamic]u8, 0, 0, context.temp_allocator); defer delete(b)
	if _, e := append(&b, '{'); e != nil {return nil}
	for f, k in fields {
		if k > 0 {if _, e := append(&b, ','); e != nil {return nil}}
		key, e := json.marshal(f.name, {}, context.temp_allocator); if e != nil {return nil}
		data := encode(f.value, context.temp_allocator); if data == nil {return nil}
		if _, e := append(&b, ..key);
		   e !=
		   nil {return nil}; if _, e := append(&b, ':'); e != nil {return nil}; if _, e := append(&b, ..data); e != nil {return nil}
	}
	if _, e := append(&b, '}'); e != nil {return nil}; return copy_bytes(b[:], a)
}
encode_dto :: proc(value: any, a: mem.Allocator) -> ([]u8, bool) {
	if value == nil {return copy_bytes(transmute([]u8)string("null"), a), true}
	switch v in value {
	case Encoded_Value:
		if len(v) == 0 {return copy_bytes(transmute([]u8)string("null"), a), true}
		return copy_bytes(([]u8)(v), a), true
	case Frame_Metadata:
		return encode_object(
				[]Object_Field {
					{"drawable", v.drawable},
					{"ui_scale", v.ui_scale},
					{"theme_revision", v.theme_revision},
					{"resource_revision", v.resource_revision},
					{"theme_provenance", v.theme_provenance},
					{"modal", v.modal},
					{"layers", v.layers},
					{"groups", v.groups},
					{"paint", v.paint},
					{"hold", v.hold},
					{"hold_result", v.hold_result},
				},
				a,
			),
			true
	case Wire_Node:
		return encode_object(
				[]Object_Field {
					{"parent_index", v.parent_index},
					{"children", v.children},
					{"structural_role", v.structural_role},
					{"role", v.role},
					{"name", v.name},
					{"source_hint", v.source_hint},
					{"resolved", v.resolved},
					{"presentation", v.presentation},
					{"text", v.text},
					{"scroll", v.scroll},
					{"progress", v.progress},
					{"hold", v.hold},
					{"selected", v.selected},
					{"actions", v.actions},
				},
				a,
			),
			true
	case []Wire_Node:
		b := make([dynamic]u8, 0, 0, context.temp_allocator); defer delete(b)
		if _, e := append(&b, '['); e != nil {return nil, true}
		for n, k in v {if k > 0 {if _, e := append(&b, ','); e != nil {return nil, true}}; data := encode(n, context.temp_allocator); if data == nil {return nil, true}; if _, e := append(&b, ..data); e != nil {return nil, true}}
		if _, e := append(&b, ']'); e != nil {return nil, true}; return copy_bytes(b[:], a), true
	case Result:
		return encode_object(
				[]Object_Field {
					{"frame", v.frame},
					{"capabilities", v.capabilities},
					{"family", v.family},
					{"indices", v.indices},
					{"nodes", v.nodes},
					{"diagnostics", v.diagnostics},
					{"strict", v.strict},
					{"observation", v.observation},
					{"path", v.path},
				},
				a,
			),
			true
	case Reply:
		return encode_object(
				[]Object_Field {
					{"protocol", v.protocol},
					{"request_id", v.request_id},
					{"ok", v.ok},
					{"error", v.error},
					{"ready", v.ready},
					{"historical", v.historical},
					{"model_revision", v.model_revision},
					{"published_revision", v.published_revision},
					{"frame_id", v.frame_id},
					{"result", v.result},
				},
				a,
			),
			true
	case Snapshot_Document:
		return encode_object(
				[]Object_Field {
					{"protocol", v.protocol},
					{"frame_id", v.frame_id},
					{"model_revision", v.model_revision},
					{"published_revision", v.published_revision},
					{"result", v.result},
					{"drawable", v.drawable},
					{"window_size", v.window_size},
					{"window_to_drawable", v.window_to_drawable},
					{"ui_scale", v.ui_scale},
					{"resource_revision", v.resource_revision},
					{"theme_revision", v.theme_revision},
					{"backend", v.backend},
					{"build_revision", v.build_revision},
					{"build_dirty", v.build_dirty},
					{"overlays", v.overlays},
				},
				a,
			),
			true
	}
	return nil, false
}
