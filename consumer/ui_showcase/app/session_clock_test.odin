package app

import "core:testing"

@(test)
test_time_never_accumulates_wall_hold_or_visual_page_steps :: proc(t: ^testing.T) {
	when TOOLS && #config(UI_DEMO_TEST, false) {
		f: Page_Fixture; defer stop_page_fixture(&f)
		if !start_page_fixture(t, &f, .Lab_Hud) {return}
		s := &f.s
		x := execute_tool_action(s, {op = "begin-hold", id = "hud/restore", test_time = true})
		if !testing.expect(t, x.code == "Applied") {return}
		session := Session {
			shell = s,
			options = {test_time = true},
		}
		testing.expect(t, step_session_clock(session, 100) && step_session_clock(session, 5000))
		h, _ := active_hold(&s.runtime)
		testing.expect(t, h.state.live.elapsed_ms == 0 && s.model.lab_hold_count == 0)
		x = execute_tool_action(s, {op = "advance-hold", duration_ms = 999, test_time = true})
		testing.expect(t, x.code == "Applied" && s.model.lab_hold_count == 0)
		testing.expect(
			t,
			s.runtime.tools_state.sample_ms == 999,
			"deterministic capture sample must match accepted hold time",
		)
		testing.expect(t, step_session_clock(session, 10000) && h.state.live.elapsed_ms == 999)
	}
}
