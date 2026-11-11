package app

import "core:testing"
import "core:time"

@(test)
qualification_failed_attempt_does_not_reuse_phase_history :: proc(t: ^testing.T) {
	when QUALIFICATION {
		f: Page_Fixture; defer stop_page_fixture(&f)
		if !start_page_fixture(t, &f, .Lab_Hud) {return}
		r := &f.s.runtime
		testing.expect(t, rebuild(r) && present(r))
		for phase in Performance_Phase {testing.expect(t, r.qualification.phases[phase].available)}
		r.fault = .Copy
		testing.expect(t, !rebuild(r))
		for phase in ([]Performance_Phase{.Copy, .Commit, .Draw, .Readback, .Present}) {
			testing.expect(
				t,
				!r.qualification.phases[phase].available,
				"failed attempt cannot report a previous attempt's phase",
			)
		}
		testing.expect(t, recover(&f.s) && present(r))
		f.s.model.measurements_off = true
		testing.expect(t, rebuild(r) && present(r))
		for phase in Performance_Phase {testing.expect(t, !r.qualification.phases[phase].available)}
	}
}

@(test)
qualification_phase_clock_covers_non_g21_workloads :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Hud) {return}
	started := sample_begin(&f.s.runtime)
	testing.expect(
		t,
		(started != time.Tick{}) == QUALIFICATION,
		"only qualification builds measure actual selected operations outside G21",
	)
	f.s.model.measurements_off = true
	testing.expect(
		t,
		sample_begin(&f.s.runtime) == time.Tick{},
		"off must not read observer clocks",
	)
}
