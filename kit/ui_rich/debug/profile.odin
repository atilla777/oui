package ui_rich_debug
import debug "../../ui_debug"
configure :: proc(h: ^debug.Host) {h.protocol = 12; h.parse = parse_rich_request}
