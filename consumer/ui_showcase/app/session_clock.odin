package app

import hold_sdl "ui:ui_hold/sdl"
_ :: hold_sdl.Adapter

step_session_clock :: proc(session: Session, now: i64) -> bool {
	when TOOLS && #config(UI_DEMO_TEST, false) {
		if session.options.test_time {
			s := session.shell; r := &s.runtime
			if h, selected := active_hold(r); selected {
				h.input.deterministic = true; h.input.has_base = false
				// Drain release/loss cleanup only. No visual/gesture/transition
				// clock is stepped in the deterministic launch mode.
				if h.input.has_pending && current(r) {
					x := hold_sdl.step(&h.input, &h.state, &r.interaction, now)
					accept_hold(r, reader_stamp(&r.live), x)
					return finish_input(s, s.model.page, true)
				}
			}
			return true
		}
	}
	when TOOLS {if session.shell.runtime.tools_state.enabled {session.shell.runtime.tools_state.sample_ms = now}}
	return advance_page_clock(session.shell, now)
}
