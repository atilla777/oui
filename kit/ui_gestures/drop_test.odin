package ui_gestures
import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"
@(test)
semantic_drop_is_one_versioned_proposal_not_application_apply :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(); defer destroy(&s)
	ds := descriptions([]string{"card"})
	if !publish(t, &p, &ctx, &s, ds[:]) {return}
	r := dispatch(&s, &ctx, nil, {kind = .Begin, id = "drag", source = .Agent})
	if !testing.expect(
		t,
		r.code == .Applied &&
		r.count == 1 &&
		r.signals[0].kind == .Began &&
		r.cycle == 1 &&
		!r.has_proposal &&
		!p.ready,
	) {return}
	cycle := r.cycle
	testing.expect(
		t,
		dispatch(&s, &ctx, nil, {kind = .Begin, id = "drag", source = .Agent}).code == .Not_Ready,
	)
	if !publish(t, &p, &ctx, &s, ds[:]) {return}
	r = dispatch(&s, &ctx, nil, {kind = .Aim, id = "drop", source = .Agent, cycle = cycle})
	if !testing.expect(
		t,
		r.code == .Applied && r.phase == .Active && s.live.target_accepted,
	) {return}
	if !publish(t, &p, &ctx, &s, ds[:]) {return}
	testing.expect(
		t,
		dispatch(&s, &ctx, nil, {kind = .End, cycle = cycle + 1, source = .Agent}).code ==
		.Invalid_Action,
	)
	r = dispatch(&s, &ctx, nil, {kind = .End, cycle = cycle, source = .Agent})
	if !testing.expect(
		t,
		r.code == .Applied && r.has_proposal && r.count == 1 && r.signals[0].kind == .Ended,
	) {return}
	testing.expect(
		t,
		r.proposal.source_id == "drag" &&
		r.proposal.target_id == "drop" &&
		r.proposal.model_revision == 7 &&
		r.proposal.sequence == 1 &&
		p.sequence == 1 &&
		s.live.phase == .Idle,
	)
	if !publish(t, &p, &ctx, &s, ds[:], 8) {return}
	testing.expect(
		t,
		p.sequence == 1 &&
		s.frame.result.has_proposal &&
		s.frame.result.proposal.model_revision == 7,
	)
}
