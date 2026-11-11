package ui_gestures
import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"
@(test)
explicit_and_failed_rebuild_cancellation_preserve_history_and_cycle :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(); defer destroy(&s); ds := descriptions([]string{"card"})
	if !publish(t, &p, &ctx, &s, ds[:]) {return}
	dispatch(&s, &ctx, nil, {kind = .Begin, id = "drag", source = .Agent})
	if !publish(t, &p, &ctx, &s, ds[:]) {return}
	r := dispatch(&s, &ctx, nil, {kind = .Cancel, cycle = 1, source = .Agent, reason = .Explicit})
	if !testing.expect(
		t,
		r.code == .Applied &&
		r.phase == .Idle &&
		r.reason == .Explicit &&
		r.signals[0].kind == .Cancelled,
	) {return}
	if !publish(t, &p, &ctx, &s, ds[:]) {return}
	dispatch(&s, &ctx, nil, {kind = .Begin, id = "drag", source = .Agent})
	if !publish(t, &p, &ctx, &s, ds[:]) {return}
	before := s.frame.live.phase
	base.begin_attempt(&p, 7)
	testing.expect(
		t,
		block(&s, &p) &&
		!p.ready &&
		s.live.phase == .Idle &&
		s.live.reason == .Update_Failed &&
		s.live.cycle == 2,
	)
	testing.expect(
		t,
		s.frame.live.phase == before && s.frame.live.phase == .Active && p.sequence == 0,
	)
	if !publish(t, &p, &ctx, &s, ds[:]) {return}
	testing.expect(
		t,
		p.ready &&
		s.live.phase == .Idle &&
		s.live.cycle == 2 &&
		s.frame.result.reason == .Update_Failed,
	)
}
