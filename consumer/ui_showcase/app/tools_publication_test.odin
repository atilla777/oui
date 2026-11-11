package app

import "core:testing"

@(test)
tools_publication_freezes_names_state_focus_and_model_before_failure :: proc(t: ^testing.T) {
	when TOOLS {
		f: Page_Fixture; defer stop_page_fixture(&f)
		if !start_page_fixture(t, &f, .Controls) {return}
		s := &f.s; s.runtime.tools_state.enabled = true
		if !testing.expect(t, rebuild(&s.runtime)) {return}
		g := s.runtime.live.tools
		if !testing.expect(
			t,
			g != nil,
			"opted-in publication needs owning frozen metadata",
		) {return}
		testing.expect(
			t,
			g.observation.selected_section == "controls" && g.observation.locale == "ru",
		)
		testing.expect(t, g.inspection.focus_id == s.runtime.interaction.focus_id)
		focus := g.inspection.focus_id
		s.runtime.interaction.focus_id = "controls/toggle"
		s.model.locale = .English; s.model.revision += 1
		testing.expect(t, g.inspection.focus_id == focus && g.observation.locale == "ru")
		retained, ok := copy_reader(&s.runtime.live, s.allocator)
		if !testing.expect(t, ok) {return}; defer destroy_reader(&retained)
		testing.expect(t, retained.tools == g && g.references >= 2)
		destroy(&s.runtime)
		testing.expect(
			t,
			retained.tools.observation.locale == "ru" &&
			!retained.tools.inspection.frame.stamp.lifetime.alive,
		)
	}
}
