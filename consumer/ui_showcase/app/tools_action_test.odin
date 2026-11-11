package app

import "core:testing"

@(test)
tools_hold_requires_explicit_test_clock_and_shared_threshold_without_replay :: proc(
	t: ^testing.T,
) {
	when TOOLS && #config(UI_DEMO_TEST, false) {
		f: Page_Fixture; defer stop_page_fixture(&f)
		if !start_page_fixture(t, &f, .Lab_Hud) {return}
		s := &f.s
		a := execute_tool_action(s, {op = "activate", id = "hud/restore"})
		testing.expect(t, a.code == "Hold_Required" && s.model.lab_hold_count == 0)
		b := execute_tool_action(s, {op = "begin-hold", id = "hud/restore"})
		if !testing.expect(t, b.code == "Applied") {return}
		x := execute_tool_action(s, {op = "advance-hold", duration_ms = 1000})
		testing.expect(t, x.code == "Interactive_Clock" && s.model.lab_hold_count == 0)
		x = execute_tool_action(s, {op = "advance-hold", duration_ms = 999, test_time = true})
		testing.expect(t, x.code == "Applied" && s.model.lab_hold_count == 0)
		x = execute_tool_action(s, {op = "release-hold"})
		testing.expect(t, x.code == "Applied" && s.model.lab_hold_count == 0)
		x = execute_tool_action(s, {op = "begin-hold", id = "hud/restore"})
		testing.expect(t, x.code == "Applied")
		x = execute_tool_action(s, {op = "advance-hold", duration_ms = 1000, test_time = true})
		testing.expect(
			t,
			x.code == "Applied" && x.application == "applied" && s.model.lab_hold_count == 1,
		)
		execute_tool_action(s, {op = "release-hold"})
		testing.expect(t, s.model.lab_hold_count == 1)
	}
}

@(test)
tools_refusal_preserves_real_family_reason_and_failed_rebuild_keeps_app_outcome :: proc(
	t: ^testing.T,
) {
	when TOOLS && TEST {
		f: Page_Fixture; defer stop_page_fixture(&f)
		if !start_page_fixture(t, &f, .Controls) {return}
		s := &f.s
		x := execute_tool_action(s, {op = "activate", id = "missing"})
		testing.expect(t, x.code == "Not_Found" && s.model.effects == 0)
		s.runtime.fault = .Copy
		x = execute_tool_action(s, {op = "activate", id = "controls/checkbox"})
		testing.expect(
			t,
			x.code == "Applied" &&
			!x.ready &&
			x.application == "applied" &&
			s.model.checkbox &&
			s.model.effects == 1,
		)
		x = execute_tool_action(s, {op = "activate", id = "controls/checkbox"})
		testing.expect(t, x.code == "Not_Ready" && s.model.checkbox && s.model.effects == 1)
		testing.expect(t, recover(s) && s.model.checkbox && s.model.effects == 1)
	}
}
