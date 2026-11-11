package ui_gestures
import base "../ui_base"
import interaction "../ui_interaction"
import "core:testing"
@(test)
frozen_hit_and_navigation_order_follows_layout_not_description_order :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := interaction.create(context.allocator, &p); defer interaction.destroy(&ctx)
	s := create(); defer destroy(&s); ds := descriptions([]string{"card"})
	ds[0], ds[1] = ds[1], ds[0]
	if !publish(t, &p, &ctx, &s, ds[:]) {return}
	testing.expect(
		t,
		s.frame.gestures[0].node_id == "source" && s.frame.gestures[1].node_id == "target",
	)
}
