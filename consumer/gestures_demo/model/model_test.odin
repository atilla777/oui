package gestures_demo

import "core:strings"

@(test)
malformed_requests_do_not_consume_watermarks_or_mutate_state :: proc(t: ^testing.T) {
	for invalid in 0 ..< 7 {
		s := initial()
		r := request_for()
		switch invalid {
		case 0:
			r.cycle = 0
		case 1:
			r.sequence = 0
		case 2:
			r.frame_id = 0
		case 3:
			r.payload_type = "unknown"
		case 4:
			r.payload_id = ""
		case 5:
			r.source_id = "other-card"
		case 6:
			r.source_id = ""
		}
		after, outcome := reduce(s, r)
		testing.expect_value(t, outcome.reason, Rejection.Invalid_Request)
		testing.expect(t, !outcome.applied)
		testing.expect_value(t, after, s)
	}
}

@(test)
source_availability_and_drag_time_model_drift_are_rechecked :: proc(t: ^testing.T) {
	s := initial()
	s.panels[0].available = false
	after, outcome := reduce(s, request_for())
	testing.expect_value(t, outcome.reason, Rejection.Unavailable)
	testing.expect_value(t, after.panels, s.panels)
	s = initial()
	stale := request_for()
	// An intervening application command moves another card while the first
	// drag still holds a proposal for revision zero.
	s, outcome = reduce(s, request_for("card-04", sequence = 1, cycle = 1))
	testing.expect(t, outcome.applied)
	stale.sequence, stale.cycle = 2, 2
	after, outcome = reduce(s, stale)
	testing.expect_value(t, outcome.reason, Rejection.Stale_Model)
	testing.expect_value(t, after.panels, s.panels)
	testing.expect_value(t, after.revision, s.revision)
}

@(test)
all_cards_can_move_to_one_panel_and_back_without_capacity_loss :: proc(t: ^testing.T) {
	s := initial()
	before := s
	for i in 0 ..< 6 {
		id := before.panels[0].cards[i]
		next, outcome := reduce(
			s,
			request_for(id, sequence = u64(i + 1), cycle = u64(i + 1), revision = s.revision),
		)
		testing.expect(t, outcome.applied)
		s = next
	}
	testing.expect_value(t, s.panels[0].count, 0)
	testing.expect_value(t, s.panels[1].count, 12)
	for i in 0 ..< 12 {
		id := s.panels[1].cards[0]
		next, outcome := reduce(
			s,
			request_for(id, "panel-left", u64(i + 7), u64(i + 7), s.revision),
		)
		testing.expect(t, outcome.applied)
		s = next
	}
	testing.expect_value(t, s.panels[0].count, 12)
	testing.expect_value(t, s.panels[1].count, 0)
	for panel in before.panels {for i in 0 ..< panel.count {
			count := 0
			for current in s.panels {for j in 0 ..< current.count {if current.cards[j] == panel.cards[i] {count += 1}}}
			testing.expect_value(t, count, 1)
		}}
}

@(test)
repeated_cycles_and_value_copies_have_no_history_or_shared_mutation :: proc(t: ^testing.T) {
	s := initial()
	original := s
	for i in 1 ..= 512 {
		target := "panel-right"; if i % 2 == 0 {target = "panel-left"}
		next, outcome := reduce(s, request_for("card-03", target, u64(i), u64(i), s.revision))
		testing.expect(t, outcome.applied)
		testing.expect_value(t, s.revision, u64(i - 1))
		s = next
	}
	testing.expect_value(t, original, initial())
	testing.expect_value(t, s.revision, u64(512))
	testing.expect_value(t, s.last_sequence, u64(512))
	testing.expect_value(t, s.last_cycle, u64(512))
	testing.expect_value(t, s.panels[0].count, 6)
	testing.expect_value(t, s.panels[1].count, 6)
}
import "core:testing"

@(test)
drop_retains_application_id_not_borrowed_request_storage :: proc(t: ^testing.T) {
	s := initial()
	id := strings.clone("card-03")
	r := request_for()
	r.source_id, r.payload_id = id, id
	after, outcome := reduce(s, r)
	testing.expect(t, outcome.applied)
	testing.expect(
		t,
		raw_data(after.panels[1].cards[6]) == raw_data(s.panels[0].cards[2]),
		"retained ID must belong to the model, not the borrowed UI proposal",
	)
	delete(id)
}

@(test)
rejections_leave_membership_order_and_revision_unchanged :: proc(t: ^testing.T) {
	for expected in ([]Rejection{.Same_Panel, .Unknown_Card, .Unknown_Target, .Unavailable, .Stale_Model, .Fixture_Rejection, .Revision_Overflow, .Invalid_Request}) {
		s := initial()
		r := request_for()
		reject := false
		#partial switch expected {
		case .Same_Panel:
			r.target_id = "panel-left"
		case .Unknown_Card:
			r.source_id, r.payload_id = "absent", "absent"
		case .Unknown_Target:
			r.target_id = "absent"
		case .Unavailable:
			s.panels[1].available = false
		case .Stale_Model:
			s.revision = 1
		case .Fixture_Rejection:
			reject = true
		case .Revision_Overflow:
			s.revision, r.model_revision = max(u64), max(u64)
		case .Invalid_Request:
			r.payload_type = "not-a-card"
		case:
		}
		after, outcome := reduce(s, r, reject)
		testing.expect(t, !outcome.applied)
		testing.expect_value(t, outcome.reason, expected)
		testing.expect_value(t, after.panels, s.panels)
		testing.expect_value(t, after.revision, s.revision)
		testing.expect_value(t, outcome.revision, s.revision)
	}
}

@(test)
accepted_and_rejected_requests_cannot_be_replayed_with_current_revision :: proc(t: ^testing.T) {
	for reject in ([]bool{false, true}) {
		s, first := reduce(initial(), request_for(), reject)
		testing.expect_value(t, first.applied, !reject)
		r := request_for(revision = s.revision)
		for _ in 0 ..< 3 {
			after, outcome := reduce(s, r)
			testing.expect_value(t, outcome.reason, Rejection.Replay)
			testing.expect_value(t, after, s)
		}
		// Neither a new sequence on an old cycle nor an old sequence on a new
		// cycle can turn a consumed result into a new application command.
		r.sequence = 2
		_, outcome := reduce(s, r)
		testing.expect_value(t, outcome.reason, Rejection.Replay)
		r.sequence, r.cycle = 1, 2
		_, outcome = reduce(s, r)
		testing.expect_value(t, outcome.reason, Rejection.Replay)
	}
}

request_for :: proc(
	id := "card-03",
	target := "panel-right",
	sequence: u64 = 1,
	cycle: u64 = 1,
	revision: u64 = 0,
) -> Drop_Request {
	return {
		source_id = id,
		target_id = target,
		payload_id = id,
		payload_type = "card",
		cycle = cycle,
		sequence = sequence,
		frame_id = 1,
		model_revision = revision,
	}
}

@(test)
drop_moves_once_to_end_preserving_every_other_id_and_order :: proc(t: ^testing.T) {
	before := initial()
	after, outcome := reduce(before, request_for())
	testing.expect(t, outcome.applied && outcome.reason == .None)
	testing.expect_value(t, after.revision, u64(1))
	testing.expect_value(t, before.panels[0].count, 6)
	testing.expect_value(t, after.panels[0].count, 5)
	testing.expect_value(t, after.panels[1].count, 7)
	for id, i in ([5]string{"card-01", "card-02", "card-04", "card-05", "card-06"}) {testing.expect_value(t, after.panels[0].cards[i], id)}
	for id, i in ([7]string{"card-07", "card-08", "card-09", "card-10", "card-11", "card-12", "card-03"}) {testing.expect_value(t, after.panels[1].cards[i], id)}
	testing.expect_value(t, after.panels[0].cards[5], "")
	testing.expect_value(t, outcome.cycle, u64(1))
	testing.expect_value(t, outcome.sequence, u64(1))
	testing.expect_value(t, outcome.revision, after.revision)
}

@(test)
fixture_has_twelve_stable_cards_in_two_panels :: proc(t: ^testing.T) {
	s := initial()
	testing.expect_value(t, s.panels[0].id, "panel-left")
	testing.expect_value(t, s.panels[1].id, "panel-right")
	for panel in s.panels {
		testing.expect_value(t, panel.count, 6)
		testing.expect(t, panel.available)
	}
	for id, i in ([6]string{"card-01", "card-02", "card-03", "card-04", "card-05", "card-06"}) {testing.expect_value(t, s.panels[0].cards[i], id)}
	for id, i in ([6]string{"card-07", "card-08", "card-09", "card-10", "card-11", "card-12"}) {testing.expect_value(t, s.panels[1].cards[i], id)}
	testing.expect_value(t, s.revision, u64(0))
}
