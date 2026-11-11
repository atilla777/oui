package ui_gestures_debug
import gestures ".."
import debug "../../ui_debug"
import wire "../../ui_wire"
action :: proc(r: Request, f: ^gestures.Frame) -> (gestures.Action, bool) {
	v, ok := r.extension.(Gesture_Request); if !ok || !r.extended_action {return {}, false}
	if v.action.kind ==
	   .Begin {d, found := gestures.find(f, v.action.id); if found && ((d.kind == .Pan_Scroll) != v.point_present) {return {}, false}}
	return v.action, true
}
// Conflict is Gesture_Busy only for the original reachable busy Begin case.
// Allocation, version exhaustion and unrelated Conflict are not fake old codes.
reply :: proc(
	r: gestures.Result,
	a: gestures.Action,
	before: gestures.Phase,
) -> (
	Gesture_Reply,
	bool,
) {
	c, ok := wire.code(r.code)
	if r.code == .Conflict && a.kind == .Begin && before != .Idle {c, ok = .Gesture_Busy, true}
	if !ok {return {}, false}
	e := ""; if c != .Applied {e = wire.code_name(c)}
	return {e, c, r.cycle, r.phase, r.reason}, true
}
configure :: proc(h: ^debug.Host) {h.protocol = 14; h.parse = parse_gestures_request}
