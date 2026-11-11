package ui_gestures
import base "../ui_base"
import interaction "../ui_interaction"
import scroll "../ui_scroll"
import "core:testing"
@(test)
repeat_activation_is_one_step_not_a_hold_cycle_or_application_event :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create()
	defer destroy(&s)
	ss := scroll.create(context.allocator)
	defer scroll.destroy(&ss)
	ds := scroll_descriptions()
	if !publish_scroll(t, &p, &ctx, &s, &ss, ds[:]) {return}
	r := activate_repeat(&s, &ctx, &ss, "repeat")
	if !testing.expect(
		t,
		r.code == .Applied &&
		!r.has_event &&
		s.live.phase == .Idle &&
		s.live.cycle == 0 &&
		p.sequence == 0,
	) {return}
	if !publish_scroll(t, &p, &ctx, &s, &ss, ds[:]) {return}
	testing.expect(t, ss.frame.regions[0].offset == 24 && s.live.cycle == 0)
}
