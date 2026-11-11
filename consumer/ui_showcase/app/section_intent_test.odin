package app

import "core:testing"

// Exercise the existing navigation boundary before exposing the selected
// section-intent API. The oracles below do not depend on a button being present.
select_for_test :: proc(s: ^Shell, id: string) -> bool {
	r := request_section(s, id, .Agent)
	return r.code == .Applied && r.ready
}

@(test)
section_intent_can_reach_absent_catalogue_target_without_fake_activation :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Controls) {return}
	s := &f.s; before := s.model.effects
	testing.expect(t, select_for_test(s, "lab-hud"))
	if !testing.expect(t, s.model.page == .Lab_Hud && current(&s.runtime)) {return}
	testing.expect(t, s.model.effects == before + 1)
	epoch := reader_stamp(&s.runtime.live); revision := s.model.revision
	testing.expect(t, select_for_test(s, "lab-hud"))
	testing.expect(t, reader_stamp(&s.runtime.live) == epoch && s.model.revision == revision)
	testing.expect(t, !select_for_test(s, "unknown") && s.model.revision == revision)
}

@(test)
section_intent_settings_stay_discard_and_upper_decision_are_shared :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Lab_Settings) {return}
	s := &f.s
	if !testing.expect(t, dispatch(s, {.Activate, "lab/enabled", .Agent, false})) {return}
	testing.expect(t, select_for_test(s, "lab-hud"))
	v, _ := s.runtime.content.(^Lab_Menu_Runtime)
	if !testing.expect(
		t,
		v.discard && s.model.page == .Lab_Settings && v.destination == .Lab_Hud,
	) {return}
	sequence := s.runtime.publication.sequence; revision := s.model.revision
	testing.expect(t, !select_for_test(s, "layout"))
	testing.expect(t, sequence == s.runtime.publication.sequence && revision == s.model.revision)
	testing.expect(t, dispatch(s, {.Activate, "lab/stay", .Agent, false}))
	testing.expect(t, s.model.lab_enabled && s.model.page == .Lab_Settings)
	testing.expect(t, select_for_test(s, "lab-hud"))
	testing.expect(t, dispatch(s, {.Activate, "lab/discard", .Agent, false}))
	testing.expect(
		t,
		s.model.page == .Lab_Hud && s.model.lab_enabled == s.model.lab_applied_enabled,
	)
}

@(test)
section_intent_failed_entry_retains_destination_and_cannot_recover_by_query :: proc(
	t: ^testing.T,
) {
	when !TEST {return}
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Controls) {return}
	s := &f.s; s.fail_entry = true
	testing.expect(t, !select_for_test(s, "lab-hud"))
	testing.expect(t, s.model.page == .Lab_Hud && !s.runtime.publication.ready)
	effects := s.model.effects
	testing.expect(t, !select_for_test(s, "layout") && s.model.effects == effects)
	testing.expect(t, recover(s) && s.model.effects == effects && current(&s.runtime))
}
