package ui_transitions_debug
import transitions ".."
import debug "../../ui_debug"
guard_request :: proc(r: Request, test_time: bool) -> string {if !test_time &&
	   (r.op == "advance" || r.op == "finish-transitions") {return "Interactive_Clock"}
	return ""}
step :: proc(r: Request, test_time: bool) -> (transitions.Step, string) {
	if r.op != "advance" && r.op != "finish-transitions" {return {}, "Invalid_Action"}
	if error := guard_request(r, test_time); error != "" {return {}, error}
	v := transitions.Step {
		kind     = .Advance,
		delta_ms = r.duration_ms,
	}; if r.op == "finish-transitions" {v.kind = .Finish_All}; return v, ""
}
configure :: proc(h: ^debug.Host) {h.protocol = 16; h.parse = parse_transition_request}
