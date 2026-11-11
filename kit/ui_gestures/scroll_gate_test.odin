package ui_gestures
import base "../ui_base"
import interaction "../ui_interaction"
import scroll "../ui_scroll"
import "core:testing"
@(test)
disabled_scroll_region_cancels_repeat_even_when_trigger_is_available :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create()
	defer destroy(&s)
	ss := scroll.create(context.allocator)
	defer scroll.destroy(&ss)
	ds := scroll_descriptions()
	if !publish_scroll(t, &p, &ctx, &s, &ss, ds[:]) {return}
	dispatch(&s, &ctx, &ss, {kind = .Begin, id = "repeat", source = .Agent})
	if !publish_scroll(t, &p, &ctx, &s, &ss, ds[:], 100, 1, false) {return}
	v, _ := find(&s.frame, "repeat")
	testing.expect(
		t,
		v.availability == .Disabled &&
		s.live.phase == .Idle &&
		s.live.reason == .Unavailable &&
		s.live.cycle == 1 &&
		p.sequence == 0,
	)
}
