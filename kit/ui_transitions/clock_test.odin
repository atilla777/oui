package ui_transitions

import "core:testing"
// Unchanged numerical oracle moved from the former SDL transitions suite.
@(test)
transition_clock_idle_pause_failure_recovery_and_deterministic :: proc(t: ^testing.T) {
	c: Transition_Clock
	for row in ([]struct {
			time:   i64,
			active: bool,
			epoch:  u64,
			want:   i64,
		}{{100, false, 0, 0}, {10000, true, 0, 0}, {10050, true, 0, 50}, {20000, false, 0, 0}, {90000, true, 0, 0}, {90020, true, 0, 20}, {99999, true, 1, 0}, {100000, true, 1, 1}, {2, true, 1, 0}, {3, true, 1, 1}}) {
		delta, ok := step_transition_clock(&c, row.time, row.active, row.epoch)
		testing.expect(t, ok && delta == row.want)
	}
	c.deterministic = true
	delta, ok := step_transition_clock(&c, max(i64), true, 1)
	testing.expect(t, ok && delta == 0 && !c.has_base)
	c.deterministic = false
	delta, ok = step_transition_clock(&c, max(i64), true, 1)
	testing.expect(t, ok && delta == 0)
	_, ok = step_transition_clock(&c, -1, true, 1)
	testing.expect(t, !ok && !c.has_base)
}
