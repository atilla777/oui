package ui_editor_debug
import editor ".."
import debug "../../ui_debug"
action :: proc(r: Request) -> (editor.Action, bool) {v, ok := r.extension.(editor.Action)
	return v, ok && r.extended_action}
configure :: proc(h: ^debug.Host) {h.protocol = 11; h.parse = parse_editor_request}
