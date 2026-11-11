package model

import "core:testing"

@(test)
dirty_departure_all_results_and_escape :: proc(t: ^testing.T) {
	for outcome in ([]string{"apply-and-go", "discard-and-go", "stay", "escape"}) {
		s := create(); old := s.draft
		reduce(&s, {kind = .Intensity, value = 99})
		testing.expect_value(
			t,
			reduce(&s, {kind = .Select_Profile, id = fixture(0).id}).error,
			Error.None,
		)
		testing.expect(
			t,
			s.draft.intensity == 99 && s.dialog == .None,
			"repeat selection preserves draft",
		)
		testing.expect_value(
			t,
			reduce(&s, {kind = .Select_Profile, id = fixture(1).id}).error,
			Error.None,
		)
		testing.expect(
			t,
			s.dialog == .Dirty_Departure &&
			s.pending_id == fixture(1).id &&
			s.selected_id == fixture(0).id &&
			s.draft.intensity == 99,
		)
		before := s
		testing.expect_value(t, reduce(&s, {kind = .Apply}).error, Error.Blocked_By_Dialog)
		testing.expect_value(t, s, before)
		a := Action {
			kind = .Dialog_Result,
			id   = outcome,
		}; if outcome == "escape" {a.kind = .Escape}
		testing.expect_value(t, reduce(&s, a).error, Error.None)
		testing.expect(t, s.dialog == .None && s.pending_id == "")
		if outcome == "stay" || outcome == "escape" {
			testing.expect(
				t,
				s.selected_id == fixture(0).id && s.draft.intensity == 99 && s.applied[0] == old,
			)
		} else {
			testing.expect(t, s.selected_id == fixture(1).id && s.draft == s.applied[1])
			want := old; if outcome == "apply-and-go" {want.intensity = 99}
			testing.expect_value(t, s.applied[0], want)
		}
	}
}

@(test)
edits_tabs_reset_and_return_to_clean :: proc(t: ^testing.T) {
	s := create()
	for a in ([]Action{{kind = .Show_Help, checked = false}, {kind = .Enabled, checked = false}, {kind = .Mode, id = "calm"}, {kind = .Tab, id = "appearance"}}) {
		testing.expect_value(t, reduce(&s, a).error, Error.None)
	}
	testing.expect(
		t,
		!s.draft.show_help &&
		!s.draft.enabled &&
		s.draft.mode == "calm" &&
		s.active_tab == "appearance" &&
		dirty(&s),
	)
	reduce(&s, {kind = .Apply}); applied := s.draft
	reduce(&s, {kind = .Intensity, value = 0})
	reduce(&s, {kind = .Request_Reset})
	testing.expect(t, s.dialog == .Reset)
	reduce(&s, {kind = .Dialog_Result, id = "cancel"})
	testing.expect(t, s.draft.intensity == 0 && s.applied[0] == applied)
	reduce(&s, {kind = .Request_Reset})
	reduce(&s, {kind = .Escape})
	testing.expect(t, s.draft.intensity == 0)
	reduce(&s, {kind = .Request_Reset})
	testing.expect_value(t, reduce(&s, {kind = .Dialog_Result, id = "reset"}).error, Error.None)
	testing.expect(t, s.draft == fixture(0).initial && s.applied[0] == applied && dirty(&s))
	reduce(
		&s,
		{kind = .Apply},
	); testing.expect(t, s.applied[0] == fixture(0).initial && !dirty(&s))
	reduce(&s, {kind = .Intensity, value = 0})
	reduce(&s, {kind = .Intensity, value = fixture(0).initial.intensity})
	testing.expect(t, !dirty(&s))
	// Reset is profile-local, not hard-coded to the first fixture.
	reduce(&s, {kind = .Select_Profile, id = fixture(1).id})
	reduce(&s, {kind = .Intensity, value = 100}); reduce(&s, {kind = .Apply})
	reduce(&s, {kind = .Request_Reset}); reduce(&s, {kind = .Dialog_Result, id = "reset"})
	testing.expect(t, s.draft == fixture(1).initial && s.applied[1].intensity == 100)
}

@(test)
reducer_refusals_are_atomic_and_trace_is_bounded :: proc(t: ^testing.T) {
	s := create()
	for a in ([]Action{{kind = .Intensity, value = -1}, {kind = .Intensity, value = 101}, {kind = .Mode, id = "unknown"}, {kind = .Select_Profile, id = "unknown"}, {kind = .Tab, id = "unknown"}, {kind = .Dialog_Result, id = "reset"}, {kind = .Unavailable}}) {
		before := s; r := reduce(&s, a)
		testing.expect(t, r.error != .None && s == before)
	}
	reduce(&s, {kind = .Intensity, value = 99})
	reduce(&s, {kind = .Select_Profile, id = fixture(1).id})
	before := s
	testing.expect(
		t,
		reduce(&s, {kind = .Dialog_Result, id = "reset"}).error != .None && s == before,
	)
	s.pending_id = "unknown"; before = s
	testing.expect(
		t,
		reduce(&s, {kind = .Dialog_Result, id = "apply-and-go"}).error == .Invalid_State &&
		s == before,
	)
	s = create()
	for i in 1 ..= TRACE_CAPACITY + 10 {testing.expect_value(t, reduce(&s, {kind = .Intensity, value = i64(i % 2), sequence = u64(i), frame_id = u64(i), source = .Agent}).error, Error.None)}
	testing.expect(t, s.trace_count == TRACE_CAPACITY && s.trace_next < TRACE_CAPACITY)
	before = s
	testing.expect_value(
		t,
		reduce(&s, {kind = .Intensity, value = 50, sequence = 1}).error,
		Error.Duplicate_Intent,
	)
	testing.expect_value(t, s, before)
}

@(test)
profile_draft_apply_cancel_round_trip_and_restart :: proc(t: ^testing.T) {
	s := create()
	testing.expect(
		t,
		s.selected_id == fixture(0).id &&
		s.selected_id != "" &&
		s.active_tab == "general" &&
		s.draft == fixture(0).initial &&
		!dirty(&s),
	)
	testing.expect_value(t, reduce(&s, {kind = .Intensity, value = 100}).error, Error.None)
	testing.expect(t, dirty(&s) && s.applied[0] == fixture(0).initial)
	testing.expect_value(t, reduce(&s, {kind = .Cancel}).error, Error.None)
	testing.expect(t, !dirty(&s) && s.draft == fixture(0).initial)
	reduce(&s, {kind = .Intensity, value = 0})
	reduce(&s, {kind = .Apply})
	reduce(&s, {kind = .Select_Profile, id = fixture(1).id})
	reduce(&s, {kind = .Select_Profile, id = fixture(0).id})
	testing.expect(t, s.selected_id == fixture(0).id && s.draft.intensity == 0 && !dirty(&s))
	fresh := create()
	testing.expect(t, fresh.draft == fixture(0).initial && fresh.applied[0] == fixture(0).initial)
}
