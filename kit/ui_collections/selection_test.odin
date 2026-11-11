package ui_collections

import layout "../ui_layout"
import scroll "../ui_scroll"
import "core:testing"
@(test)
separate_region_owners_are_supported_but_duplicate_or_nested_are_refused :: proc(t: ^testing.T) {
	g := layout.Frame {
		nodes = []layout.Resolved_Node {
			{description = {id = "root"}},
			{description = {id = "virtual", parent = "root"}},
			{description = {id = "content", parent = "virtual"}},
			{description = {id = "ordinary", parent = "root"}},
			{description = {id = "nested", parent = "content"}},
		},
	}
	d := []Collection_Description{{id = "list", scroll_id = "virtual", content_id = "content"}}
	e := validate_regions(&g, d, []scroll.Description{{"ordinary", "other-content"}})
	testing.expect(t, e.code == .None)
	e = validate_regions(&g, d, []scroll.Description{{"virtual", "content"}})
	testing.expect(t, e.code == .Binding)
	e = validate_regions(&g, d, []scroll.Description{{"nested", "other-content"}})
	testing.expect(t, e.code == .Binding)
}
