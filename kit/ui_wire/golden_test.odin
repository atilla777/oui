package ui_wire
import "core:encoding/json"
import "core:testing"
keys :: proc(t: ^testing.T, o: json.Object, names: []string) {
	testing.expect(
		t,
		len(o) == len(names),
	); for name in names {_, found := o[name]; testing.expect(t, found, name)}
}
@(test)
legacy_and_modern_field_sets_match_original_wire_oracles :: proc(t: ^testing.T) {
	n := Resolved_Node {
		description = {id = "button", text = "Text", role = .Button},
		availability = .Hold_Required,
	}
	for legacy in ([]bool{true, false}) {
		data: []u8; e: json.Marshal_Error
		if legacy {data, e = json.marshal(legacy_node(n), {use_enum_names = true}, context.allocator)} else {data, e = json.marshal(n, {use_enum_names = true}, context.allocator)}
		if !testing.expect(t, e == nil) {continue}
		v, pe := json.parse(string(data), allocator = context.temp_allocator); delete(data)
		if !testing.expect(t, pe == nil) {continue}; o := v.(json.Object)
		description := o["description"].(json.Object)
		if legacy {
			keys(
				t,
				o,
				[]string {
					"description",
					"bounds",
					"content",
					"clip",
					"paint_clip",
					"measured",
					"style",
					"enabled",
					"visible",
					"focused",
					"hovered",
					"pressed",
					"availability",
				},
			)
			keys(
				t,
				description,
				[]string {
					"id",
					"parent",
					"text",
					"role",
					"enabled",
					"visible",
					"width",
					"fixed_width",
					"padding",
					"gap",
					"style",
				},
			)
		} else {
			keys(
				t,
				o,
				[]string {
					"rows",
					"columns",
					"description",
					"bounds",
					"content",
					"clip",
					"paint_clip",
					"measured",
					"style",
					"enabled",
					"visible",
					"focused",
					"hovered",
					"pressed",
					"availability",
				},
			)
			keys(
				t,
				description,
				[]string {
					"layout",
					"id",
					"parent",
					"text",
					"role",
					"enabled",
					"visible",
					"width",
					"fixed_width",
					"padding",
					"gap",
					"style",
				},
			)
		}
		keys(
			t,
			o["style"].(json.Object),
			[]string {
				"font_size",
				"foreground",
				"background",
				"border",
				"border_width",
				"focus_width",
			},
		)
		testing.expect(
			t,
			o["availability"].(json.String) == "Hold_Required" &&
			description["role"].(json.String) == "Button",
		)
	}
	testing.expect(
		t,
		int(Code.Blocked_By_Modal) == 6 &&
		int(Code.Hold_Required) == 7 &&
		int(Code.Non_Interactive_Overlay) == 8 &&
		int(Code.Gesture_Busy) == 9,
	)
}
