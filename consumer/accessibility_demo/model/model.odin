package accessibility_model

import ui "ui:ui_interaction"

Mode :: enum {
	Hold,
	Dialog,
}
Status :: enum {
	Idle,
	Pending,
	Cancelled,
	Applied,
	Rejected,
}
Error :: enum {
	None,
	Unavailable,
	Invalid_Action,
	Stale,
	Exhausted,
	Reentrant,
}
Action_Kind :: enum {
	Hold_Started,
	Hold_Cancelled,
	Hold_Completed,
	Open,
	Confirm,
	Cancel,
	Set_Mode,
	Set_Available,
	Language,
	Reduced,
	Thresholds,
	Strict,
	Target,
	Presence,
}
Action :: struct {
	kind:                   Action_Kind,
	mode:                   Mode,
	available:              bool,
	token, cycle, sequence: u64,
	source:                 ui.Source,
}
Request :: struct {
	token, cycle, sequence: u64,
	source:                 ui.Source,
	mode:                   Mode,
}
Request_Result :: struct {
	request:  Request,
	accepted: bool,
}
State :: struct {
	mode:                                                                        Mode,
	status:                                                                      Status,
	available, english, reduced, strict_thresholds, strict, target_b, present:   bool,
	revision, policy_revision, issued, pending_token, pending_cycle, last_cycle: u64,
	counter, requests, last_sequence:                                            u64,
	pending_source:                                                              ui.Source,
	last_result:                                                                 Request_Result,
	dispatching:                                                                 bool,
}
Result :: struct {
	error:                Error,
	changed, has_request: bool,
	request:              Request,
}
Apply :: proc(request: Request, user: rawptr) -> bool
create :: proc() -> State {return {available = true, present = true}}
// The owner calls this once after routing. No borrowed IDs, allocator, history,
// clock or platform state are retained. apply must be synchronous on this thread.
reduce :: proc(s: ^State, a: Action, apply: Apply = nil, user: rawptr = nil) -> Result {
	if s.dispatching {return {error = .Reentrant}}
	if a.kind < .Hold_Started ||
	   a.kind > .Presence ||
	   s.mode < .Hold ||
	   s.mode > .Dialog {return {error = .Invalid_Action}}
	if a.sequence != 0 && a.sequence <= s.last_sequence {return {error = .Stale}}
	n := s^
	request: Request
	has_request := false
	switch a.kind {
	case .Hold_Started:
		if s.mode != .Hold || !s.available {return {error = .Unavailable}}
		if s.pending_token != 0 || a.cycle <= s.last_cycle {return {error = .Stale}}
		if s.issued == max(u64) {return {error = .Exhausted}}
		n.issued += 1; n.pending_token, n.pending_cycle, n.last_cycle, n.pending_source = n.issued, a.cycle, a.cycle, a.source
		n.status = .Pending
	case .Open:
		if s.mode != .Dialog || !s.available {return {error = .Unavailable}}
		if s.pending_token != 0 || a.sequence == 0 {return {error = .Stale}}
		if s.issued == max(u64) {return {error = .Exhausted}}
		n.issued += 1; n.pending_token, n.pending_cycle, n.pending_source = n.issued, 0, a.source; n.status = .Pending
	case .Hold_Cancelled:
		if s.mode != .Hold ||
		   s.pending_token == 0 ||
		   a.cycle != s.pending_cycle {return {error = .Stale}}
		n.pending_token, n.pending_cycle, n.status = 0, 0, .Cancelled
	case .Cancel:
		if s.mode != .Dialog ||
		   s.pending_token == 0 ||
		   a.token != s.pending_token {return {error = .Stale}}
		n.pending_token, n.pending_cycle, n.status = 0, 0, .Cancelled
	case .Hold_Completed, .Confirm:
		if !s.available {return {error = .Unavailable}}
		if s.pending_token == 0 ||
		   a.token != s.pending_token ||
		   a.sequence == 0 {return {error = .Stale}}
		if a.kind == .Hold_Completed {
			if s.mode != .Hold ||
			   a.cycle != s.pending_cycle ||
			   a.source != s.pending_source {return {error = .Stale}}
		} else if s.mode != .Dialog {return {error = .Stale}}
		if s.counter == max(u64) || s.requests == max(u64) {return {error = .Exhausted}}
		request = {a.token, s.pending_cycle, a.sequence, a.source, s.mode}; has_request = true
		n.pending_token, n.pending_cycle = 0, 0
		n.requests += 1
	case .Set_Mode:
		if a.mode < .Hold || a.mode > .Dialog {return {error = .Invalid_Action}}
		if a.mode == s.mode {return {}}
		n.mode = a.mode
		if n.pending_token != 0 {n.status = .Cancelled}
		n.pending_token, n.pending_cycle = 0, 0
	case .Set_Available:
		if a.available == s.available {return {}}
		n.available = a.available
		if !a.available {if n.pending_token != 0 {n.status = .Cancelled}; n.pending_token, n.pending_cycle = 0, 0}
	case .Language:
		n.english = !n.english
	case .Reduced:
		n.reduced = !n.reduced
	case .Thresholds:
		if s.policy_revision == max(u64) {return {error = .Exhausted}}
		n.strict_thresholds = !n.strict_thresholds; n.policy_revision += 1
	case .Strict:
		n.strict = !n.strict
	case .Target:
		n.target_b = !n.target_b
	case .Presence:
		n.present = !n.present
	}
	if s.revision == max(u64) {return {error = .Exhausted}}
	n.revision += 1
	if a.sequence != 0 {n.last_sequence = a.sequence}
	if !has_request {s^ = n; return {changed = true}}
	// Consume the token/close the dialog before the application effect. Rebuild
	// and recovery only present this result; neither calls apply again.
	n.dispatching = true; s^ = n
	accepted := true
	if apply != nil {accepted = apply(request, user)}
	if accepted {s.counter += 1; s.status = .Applied} else {s.status = .Rejected}
	s.last_result = {request, accepted}; s.dispatching = false
	return {changed = true, has_request = true, request = request}
}
