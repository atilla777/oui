package ui_collections_debug
import collections ".."
import debug "../../ui_debug"
action :: proc(r: Request) -> (collections.Action, bool) {
	c, item, ok := decode_collection_id(r.id)
	return {kind = .Scroll_To_Item, collection_id = c, item_id = item, source = .Agent},
		ok && r.extended_action && r.op == "scroll_to_item"
}
configure :: proc(h: ^debug.Host) {h.protocol = 13; h.parse = parse_collections_request}
