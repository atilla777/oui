package ui_transitions

Transition_Clock :: struct {
	deterministic, has_base: bool,
	last_ms:                 i64,
	epoch:                   u64,
}
reset_transition_clock :: proc(clock: ^Transition_Clock) {clock.has_base = false}
// The caller supplies monotonic time and active = ready && has unfinished tracks
// && !hidden && !minimized && !unfocused && !paused. Never reads an OS clock.
step_transition_clock :: proc(
	clock: ^Transition_Clock,
	now_ms: i64,
	active: bool,
	epoch: u64,
) -> (
	i64,
	bool,
) {
	if now_ms < 0 {clock.has_base = false; return 0, false}
	if clock.deterministic || !active {clock.has_base = false; return 0, true}
	delta := i64(0)
	if clock.has_base &&
	   clock.epoch == epoch &&
	   now_ms > clock.last_ms {delta = now_ms - clock.last_ms}
	clock.last_ms, clock.epoch, clock.has_base = now_ms, epoch, true
	return delta, true
}
