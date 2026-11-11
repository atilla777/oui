package ui_collections_testing
import inspect "../inspect"
import "core:testing"
Logical_State :: struct {
	hidden, enabled, selected, logical_focused, materialized, in_viewport: bool,
}
expect_logical_item :: proc(
	t: ^testing.T,
	i: ^inspect.Inspection,
	collection_id, item_id, id: string,
	expected: Logical_State,
) -> bool {
	v, e := inspect.inspect_item(i, collection_id, item_id, id)
	actual := Logical_State {
		v.hidden,
		v.enabled,
		v.selected,
		v.logical_focused,
		v.materialized,
		v.in_viewport,
	}
	return testing.expect(
		t,
		e == .None && actual == expected && (v.bounds != nil) == v.materialized,
		id,
	)
}
