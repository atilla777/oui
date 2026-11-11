package app

import model "../model"
import "core:strings"
import "core:testing"
import interaction "ui:ui_interaction"

@(test)
g20_diagnostic_explanation_has_both_ui_locales :: proc(t: ^testing.T) {
	m := model.initial(); r := Runtime {
		model = &m,
	}
	p: Performance_Page_Runtime
	testing.expect(t, strings.contains(diagnostic_message(&r, &p), "без повтора"))
	m.locale = .English
	testing.expect(t, strings.contains(diagnostic_message(&r, &p), "without replay"))
}

@(test)
g20_unexpected_failure_survives_recovery_as_historical_observation :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Diagnostics_Performance) {return}
	s := &f.s
	s.runtime.fault = .Copy
	testing.expect(t, !rebuild(&s.runtime))
	p, _ := s.runtime.content.(^Performance_Page_Runtime)
	testing.expect(
		t,
		p.diagnostic.has && !p.diagnostic.expected && p.diagnostic.stage == "Copy",
		"actual failure must replace the expected probe, not disappear",
	)
	testing.expect(t, recover(s) && present(&s.runtime))
	testing.expect(t, p.diagnostic.has && !p.diagnostic.expected && p.diagnostic.code != 0)
	testing.expect(
		t,
		strings.contains(diagnostic_message(&s.runtime, p), "historical"),
		"recovered bundle must not label a failed attempt current",
	)
}

@(test)
g20_diagnostic_fixtures_are_reachable_actions_not_static_claims :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Diagnostics_Performance) {return}; s := &f.s
	before := s.model.revision
	testing.expect(t, dispatch(s, {.Activate, "diagnostics/duplicate", .Agent, false}))
	testing.expect(
		t,
		s.model.revision == before + 1,
		"G20 must run a real validator fixture and publish its observation",
	)
}

@(test)
g20_all_probes_use_real_guards_and_recovery_does_not_replay :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Diagnostics_Performance) {return}; s := &f.s
	for id in ([]string{"diagnostics/duplicate", "diagnostics/invalid", "diagnostics/resource", "diagnostics/ownership", "diagnostics/unsupported"}) {
		before := s.model.effects
		testing.expect(t, dispatch(s, {.Activate, id, .Agent, false}) && present(&s.runtime))
		p, _ := s.runtime.content.(^Performance_Page_Runtime)
		if id ==
		   "diagnostics/ownership" {testing.expect(t, p.diagnostic.code == u32(interaction.Code.Conflict))}
		testing.expect(
			t,
			p.diagnostic.has &&
			p.diagnostic.expected &&
			p.diagnostic.code != 0 &&
			p.diagnostic.model_revision == s.model.revision &&
			s.model.effects == before,
		)
		testing.expect(t, dispatch(s, {.Activate, "shell/language", .Agent, false}))
		testing.expect(t, p.diagnostic.model_revision != s.model.revision)
		effects := s.model.effects; s.runtime.fault = .Copy
		testing.expect(t, !rebuild(&s.runtime) && recover(s) && s.model.effects == effects)
	}
}
