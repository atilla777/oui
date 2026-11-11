package app

import "core:testing"
import interaction "ui:ui_interaction"
import sdl "vendor:sdl3"

// The removed umbrella hosts are not rebuilt. Preserve their applicable
// application/registration invariants through the current publisher instead.
@(test)
g15_all_sources_and_repeated_registration_keep_one_application_outcome :: proc(t: ^testing.T) {
	for source in interaction.Source {
		f: Page_Fixture; defer stop_page_fixture(&f)
		if !start_page_fixture(t, &f, .Composition) {return}; s := &f.s
		baseline := len(s.runtime.interaction.registrations)
		for cycle in 0 ..< 10 {
			before := s.model.effects
			testing.expect(t, dispatch(s, {.Activate, "composition/child", source, false}))
			testing.expect(
				t,
				s.model.composition.child_count == u64(cycle + 1) &&
				s.model.composition.parent_count == 0 &&
				s.model.effects == before + 1,
			)
			testing.expect(t, dispatch(s, {.Activate, "composition/presence", source, false}))
			testing.expect(t, len(s.runtime.interaction.registrations) == baseline - 1)
			before = s.model.effects
			testing.expect(
				t,
				!dispatch(s, {.Activate, "composition/child", source, false}) &&
				s.model.effects == before,
			)
			testing.expect(t, dispatch(s, {.Activate, "composition/presence", source, false}))
			testing.expect(t, len(s.runtime.interaction.registrations) == baseline)
		}
		testing.expect(t, dispatch(s, {.Activate, "composition/stop", source, false}))
		before := s.model.effects
		testing.expect(t, dispatch(s, {.Activate, "composition/child", source, false}))
		testing.expect(
			t,
			s.model.composition.child_count == 11 &&
			s.model.composition.parent_count == 1 &&
			s.model.effects == before + 1,
		)
	}
}

@(test)
g13_rejected_application_completion_is_not_replayed_after_rebuild :: proc(t: ^testing.T) {
	f: Page_Fixture; defer stop_page_fixture(&f)
	if !start_page_fixture(t, &f, .Hud) {return}; s := &f.s
	s.model.hud_count = max(u64)
	testing.expect(t, rebuild(&s.runtime))
	before := s.model
	e: sdl.Event; e.key = {
		type     = .KEY_DOWN,
		windowID = 17,
		key      = sdl.K_SPACE,
	}
	testing.expect(t, handle_input(s, e, {1280, 960}))
	testing.expect(t, advance_page_clock(s, 0) && advance_page_clock(s, 1000))
	testing.expect(
		t,
		s.model == before,
		"overflow is an application refusal, not a partial HP effect",
	)
	for now in ([3]i64{2000, 3000, 4000}) {
		testing.expect(t, rebuild(&s.runtime) && advance_page_clock(s, now))
		testing.expect(t, s.model == before)
	}
	// Remove the application refusal while the UI cycle still awaits release.
	// Neither rebuilding nor additional elapsed time may resend its completion.
	s.model.hud_count = 0
	testing.expect(t, rebuild(&s.runtime) && advance_page_clock(s, 5000))
	testing.expect(
		t,
		s.model.hud_count == 0 && s.model.hud_hp == 60 && s.model.effects == before.effects,
	)
	e.key.type = .KEY_UP; handle_input(s, e, {1280, 960})
	e.key.type = .KEY_DOWN; handle_input(s, e, {1280, 960})
	testing.expect(t, advance_page_clock(s, 6000) && advance_page_clock(s, 7000))
	testing.expect(
		t,
		s.model.hud_count == 1 && s.model.hud_hp == 100 && s.model.effects == before.effects + 1,
	)
}
