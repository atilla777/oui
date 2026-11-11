package ui_collections

import layout "../ui_layout"
import scroll "../ui_scroll"

// Explicit typed selection, not a registry. A virtual region has exactly one
// offset owner; do not install an ordinary scroll.State for that same region.
validate_regions :: proc(
	g: ^layout.Frame,
	selected: []Collection_Description,
	ordinary: []scroll.Description = nil,
) -> Update_Error {
	for d, index in selected {
		n, found := layout.find(g, d.scroll_id); if !found {return {.Binding, ""}}
		for prior in selected[:index] {if prior.id == d.id || prior.content_id == d.content_id || region_within(g, d.scroll_id, prior.scroll_id) || region_within(g, prior.scroll_id, d.scroll_id) {return {.Binding, n.description.id}}}
		for other in ordinary {if region_within(g, d.scroll_id, other.id) || region_within(g, other.id, d.scroll_id) {return {.Binding, n.description.id}}}
	}
	return {}
}
region_within :: proc(g: ^layout.Frame, id, root: string) -> bool {
	at := id
	for depth := 0; at != "" && depth <= len(g.nodes); depth += 1 {
		if at == root {return true}
		n, found := layout.find(g, at); if !found {return false}; at = n.description.parent
	}
	return false
}
