package selected_tools
import "core:strings"
import "core:testing"
import collections "ui:ui_collections"
import ci "ui:ui_collections/inspect"
import ct "ui:ui_collections/testing"
import custom "ui:ui_custom"
import cd "ui:ui_custom/debug"
import debug "ui:ui_debug"
import common "ui:ui_inspect"
import layout "ui:ui_layout"
@(test)
logical_exact_id_and_real_node_name_queries_keep_original_scope :: proc(t: ^testing.T) {
	items := [3]collections.Collection_Item {
		{"a", "Same", true, true, ""},
		{"far", "Same", true, false, "locked"},
		{"hidden", "Hidden", false, true, ""},
	}
	f, e := collections.prepare_collection(
		{
			id = "list",
			scroll_id = "scroll",
			content_id = "content",
			mode = .List,
			items = items[:],
			selected_id = "far",
			height = 10,
			data_revision = 1,
		},
		{w = 100, h = 10},
		0,
	)
	defer collections.destroy_frame(&f); if !testing.expect(t, e.code == .None) {return}
	i := common.Inspection {
		frame = {nodes = []layout.Resolved_Node{{description = {id = "ordinary", role = .Box}}}},
		children = [][]int{nil},
		semantics = []common.Semantic{{"ordinary", "button", "Same", ""}},
	}
	v, ve := ci.inspect_item(
		&f,
		"list",
		"far",
		"4:list3:far",
	); testing.expect(t, ve == .None && v.name == "Same" && !v.enabled && v.selected && !v.materialized && !v.in_viewport && v.bounds == nil && v.logical_ordinal == 1)
	ct.expect_logical_item(t, &f, "list", "far", "4:list3:far", {enabled = false, selected = true})
	exact, ee := ci.find_with_collections(
		&i,
		&f,
		{.ID, "4:list3:far"},
		context.allocator,
	); defer delete(exact.logical_items); defer delete(exact.indices)
	testing.expect(t, ee == .None && len(exact.indices) == 0 && len(exact.logical_items) == 1)
	named, ne := ci.find_with_collections(
		&i,
		&f,
		{.Name, "Same"},
		context.allocator,
	); defer delete(named.indices); defer delete(named.logical_items)
	testing.expect(
		t,
		ne == .None &&
		len(named.indices) == 1 &&
		named.indices[0] == 0 &&
		len(named.logical_items) == 0,
	)
}
@(test)
custom_wire_projection_contains_only_serializable_metadata :: proc(t: ^testing.T) {
	f := custom.Frame {
		views = []custom.View {
			{
				description = {
					node_id = "button",
					type_id = "circle",
					revision = "v1",
					semantic_name = "Circle",
					hit_description = "round",
					payload = []u8{1, 2, 3},
				},
			},
		},
	}
	p := cd.custom_projection(&f)
	r := debug.encode(p, context.allocator); defer delete(r)
	testing.expect(
		t,
		strings.contains(string(r), `"custom_nodes":`) &&
		strings.contains(string(r), `"type_id":"circle"`) &&
		!strings.contains(string(r), "payload") &&
		!strings.contains(string(r), "validate") &&
		!strings.contains(string(r), "userdata"),
		string(r),
	)
}
