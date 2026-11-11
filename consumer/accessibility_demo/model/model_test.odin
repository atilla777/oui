package accessibility_model

import "core:testing"

@(test)
presentation_preferences_never_create_or_complete_a_request :: proc(t: ^testing.T) {
	s := create(); reduce(&s, {kind = .Hold_Started, cycle = 1})
	for kind in ([]Action_Kind{.Language, .Reduced, .Thresholds, .Strict, .Target, .Presence}) {
		before := s.revision
		r := reduce(&s, {kind = kind})
		testing.expect(
			t,
			r.changed &&
			s.revision == before + 1 &&
			s.pending_token == 1 &&
			s.requests == 0 &&
			s.counter == 0,
		)
	}
	testing.expect(
		t,
		s.english &&
		s.reduced &&
		s.strict_thresholds &&
		s.strict &&
		s.target_b &&
		!s.present &&
		s.policy_revision == 1,
	)
}

@(test)
initial_hold_and_dialog_token_exactly_once :: proc(t: ^testing.T) {
	s := create()
	testing.expect(t, s.mode == .Hold && s.available && s.present && !s.reduced && s.counter == 0)
	testing.expect_value(t, reduce(&s, {kind = .Set_Mode, mode = .Dialog}).error, Error.None)
	r := reduce(&s, {kind = .Open, source = .Keyboard, sequence = 1})
	testing.expect(t, r.changed && s.pending_token == 1 && s.counter == 0 && s.requests == 0)
	token := s.pending_token
	before := s
	reduce(&s, {kind = .Open, source = .Keyboard, sequence = 2})
	testing.expect_value(t, s, before)
	r = reduce(&s, {kind = .Confirm, token = token, sequence = 2, source = .Agent})
	testing.expect(
		t,
		r.has_request &&
		r.request.token == token &&
		s.counter == 1 &&
		s.requests == 1 &&
		s.pending_token == 0 &&
		s.status == .Applied,
	)
	before = s
	reduce(&s, {kind = .Confirm, token = token, sequence = 3})
	testing.expect_value(t, s, before)
	reduce(&s, {kind = .Open, sequence = 3})
	testing.expect(t, s.pending_token == 2)
	reduce(&s, {kind = .Cancel, token = s.pending_token, sequence = 4})
	testing.expect(
		t,
		s.counter == 1 && s.requests == 1 && s.pending_token == 0 && s.status == .Cancelled,
	)
}

@(test)
hold_cycle_progress_cancel_duplicate_and_second_cycle :: proc(t: ^testing.T) {
	s := create()
	r := reduce(&s, {kind = .Hold_Started, cycle = 8, source = .Gamepad})
	testing.expect(t, r.changed && s.pending_token == 1 && s.pending_cycle == 8)
	before := s
	reduce(&s, {kind = .Hold_Started, cycle = 8, source = .Gamepad})
	testing.expect_value(t, s, before)
	reduce(&s, {kind = .Hold_Completed, token = 1, cycle = 7, sequence = 1, source = .Gamepad})
	testing.expect_value(t, s, before)
	reduce(&s, {kind = .Hold_Cancelled, cycle = 8})
	testing.expect(t, s.pending_token == 0 && s.requests == 0)
	reduce(&s, {kind = .Hold_Started, cycle = 8})
	testing.expect(t, s.pending_token == 0)
	reduce(&s, {kind = .Hold_Started, cycle = 9, source = .Mouse})
	r = reduce(
		&s,
		{
			kind = .Hold_Completed,
			token = s.pending_token,
			cycle = 9,
			source = .Mouse,
			sequence = 1,
		},
	)
	testing.expect(t, r.has_request && s.counter == 1 && s.requests == 1)
	before = s
	reduce(
		&s,
		{
			kind = .Hold_Completed,
			token = r.request.token,
			cycle = 9,
			source = .Mouse,
			sequence = 1,
		},
	)
	testing.expect_value(t, s, before)
}

reject :: proc(request: Request, user: rawptr) -> bool {return false}
@(test)
rejection_and_mode_availability_changes_never_replay :: proc(t: ^testing.T) {
	s := create()
	reduce(&s, {kind = .Set_Mode, mode = .Dialog})
	reduce(&s, {kind = .Open, sequence = 1})
	r := reduce(&s, {kind = .Confirm, token = s.pending_token, sequence = 2}, reject)
	testing.expect(
		t,
		r.has_request &&
		s.requests == 1 &&
		s.counter == 0 &&
		s.status == .Rejected &&
		s.pending_token == 0,
	)
	reduce(&s, {kind = .Confirm, token = r.request.token, sequence = 3})
	testing.expect(t, s.requests == 1)
	reduce(&s, {kind = .Open, sequence = 3})
	reduce(&s, {kind = .Set_Mode, mode = .Hold})
	testing.expect(t, s.pending_token == 0 && s.counter == 0)
	reduce(&s, {kind = .Hold_Started, cycle = 1})
	reduce(&s, {kind = .Set_Available, available = false})
	testing.expect(t, s.pending_token == 0)
	reduce(&s, {kind = .Set_Available, available = true})
	testing.expect(t, s.pending_token == 0 && s.requests == 1)
}

@(test)
all_increments_are_prechecked_before_state_or_callback :: proc(t: ^testing.T) {
	for field in 0 ..< 5 {
		s := create(); reduce(&s, {kind = .Set_Mode, mode = .Dialog})
		reduce(&s, {kind = .Open, sequence = 1})
		switch field {case 0:
			s.revision = max(u64); case 1:
			s.counter = max(u64); case 2:
			s.requests = max(u64); case 3:
			s.issued = max(u64); case 4:
			s.policy_revision = max(u64)}
		a := Action {
			kind     = .Confirm,
			token    = s.pending_token,
			sequence = 2,
		}
		if field == 3 {reduce(&s, {kind = .Cancel, token = s.pending_token}); a = {
				kind     = .Open,
				sequence = 2,
			}}
		if field == 4 {a = {
				kind = .Thresholds,
			}}
		before := s; calls := 0
		r := reduce(&s, a, count_apply, &calls)
		testing.expect(t, r.error == .Exhausted && s == before && calls == 0)
	}
}
count_apply :: proc(request: Request, user: rawptr) -> bool {(^int)(user)^ += 1; return true}

reenter :: proc(request: Request, user: rawptr) -> bool {
	s := (^State)(user)
	r := reduce(s, {kind = .Open, sequence = request.sequence + 1})
	return r.error == .Reentrant && s.pending_token == 0
}
@(test)
callback_sees_consumed_token_and_cannot_reenter :: proc(t: ^testing.T) {
	s := create()
	reduce(&s, {kind = .Set_Mode, mode = .Dialog})
	reduce(&s, {kind = .Open, sequence = 1})
	r := reduce(&s, {kind = .Confirm, token = s.pending_token, sequence = 2}, reenter, &s)
	testing.expect(t, r.has_request && s.counter == 1 && s.requests == 1 && !s.dispatching)
}
