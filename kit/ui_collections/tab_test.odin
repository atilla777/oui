package ui_collections

import interaction "../ui_interaction"
import "core:strings"
import "core:testing"
@(test)
tab_collapses_materialized_rows_to_one_logical_stop :: proc(t: ^testing.T) {
	f, e := prepare_collection(
		fixture_description(
			[]Collection_Item{{"a", "A", true, true, ""}, {"b", "B", true, true, ""}},
		),
		{w = 100, h = 20},
		0,
	)
	defer destroy_frame(&f)
	if !testing.expect(t, e.code == .None) {return}
	f.bound, f.owner_gate = true, .Applied
	f.collections[0].focus_node_id = strings.clone(f.nodes[0].description.id)
	i := interaction.Frame {
		targets = []interaction.Target_View {
			{description = {id = "editor"}, availability = .Applied},
			{description = {id = "scroll"}, availability = .Invalid_Action},
			{description = {id = f.nodes[0].description.id}, availability = .Applied},
			{description = {id = f.nodes[1].description.id}, availability = .Applied},
			{description = {id = "after"}, availability = .Applied},
		},
	}
	id, code := tab_target(&f, &i, "editor", false)
	testing.expect(t, code == .Applied && id == f.collections[0].focus_node_id)
	id, code = tab_target(&f, &i, f.nodes[1].description.id, false)
	testing.expect(t, code == .Applied && id == "after")
	id, code = tab_target(&f, &i, f.nodes[1].description.id, true)
	testing.expect(t, code == .Applied && id == "editor")
}
