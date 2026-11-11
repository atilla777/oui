package gestures_demo

// Application-owned fixture. No UI, SDL, time or scroll state belongs here.
Panel :: struct {
	id:        string,
	cards:     [12]string,
	count:     int,
	available: bool,
}
State :: struct {
	panels:                    [2]Panel,
	revision:                  u64,
	last_sequence, last_cycle: u64,
}
Drop_Request :: struct {
	source_id, target_id, payload_id, payload_type: string,
	cycle, sequence, frame_id, model_revision:      u64,
}
Rejection :: enum {
	None,
	Invalid_Request,
	Replay,
	Stale_Model,
	Unavailable,
	Unknown_Card,
	Unknown_Target,
	Same_Panel,
	Fixture_Rejection,
	Revision_Overflow,
}
Outcome :: struct {
	applied:                   bool,
	reason:                    Rejection,
	cycle, sequence, revision: u64,
}
initial :: proc() -> State {
	s := State{}
	s.panels[0] = {
		id        = "panel-left",
		count     = 6,
		available = true,
	}
	s.panels[1] = {
		id        = "panel-right",
		count     = 6,
		available = true,
	}
	for id, i in ([6]string{"card-01", "card-02", "card-03", "card-04", "card-05", "card-06"}) {s.panels[0].cards[i] = id}
	for id, i in ([6]string{"card-07", "card-08", "card-09", "card-10", "card-11", "card-12"}) {s.panels[1].cards[i] = id}
	return s
}
reduce :: proc(state: State, request: Drop_Request, reject := false) -> (State, Outcome) {
	next := state
	outcome := Outcome {
		cycle    = request.cycle,
		sequence = request.sequence,
		revision = state.revision,
	}
	if request.sequence == 0 ||
	   request.cycle == 0 ||
	   request.frame_id == 0 ||
	   request.payload_type != "card" ||
	   request.source_id != request.payload_id ||
	   request.payload_id == "" {
		outcome.reason = .Invalid_Request; return state, outcome
	}
	if request.sequence <= state.last_sequence || request.cycle <= state.last_cycle {
		outcome.reason = .Replay; return state, outcome
	}
	// Consume a well-formed command even when the application refuses it. The
	// monotonic watermark is bounded bookkeeping, not a history of proposals.
	next.last_sequence, next.last_cycle = request.sequence, request.cycle
	if request.model_revision !=
	   state.revision {outcome.reason = .Stale_Model; return next, outcome}
	source, index, target := -1, -1, -1
	for panel, p in state.panels {
		if panel.id == request.target_id {target = p}
		for i in 0 ..< panel.count {if panel.cards[i] == request.payload_id {source, index = p, i}}
	}
	if source < 0 {outcome.reason = .Unknown_Card; return next, outcome}
	if target < 0 {outcome.reason = .Unknown_Target; return next, outcome}
	if source == target {outcome.reason = .Same_Panel; return next, outcome}
	if !state.panels[source].available ||
	   !state.panels[target].available {outcome.reason = .Unavailable; return next, outcome}
	if reject {outcome.reason = .Fixture_Rejection; return next, outcome}
	if state.revision == max(u64) {outcome.reason = .Revision_Overflow; return next, outcome}
	for i := index;
	    i < next.panels[source].count - 1;
	    i += 1 {next.panels[source].cards[i] = next.panels[source].cards[i + 1]}
	next.panels[source].count -= 1
	next.panels[source].cards[next.panels[source].count] = ""
	// UI proposal strings are borrowed. Keep the model's own stable ID instead.
	next.panels[target].cards[next.panels[target].count] = state.panels[source].cards[index]
	next.panels[target].count += 1
	next.revision += 1
	outcome.applied = true
	outcome.revision = next.revision
	return next, outcome
}
