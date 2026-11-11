package ui_custom_debug
import debug "../../ui_debug"
configure :: proc(h: ^debug.Host) {h.protocol = 15; h.parse = parse_custom_request}
