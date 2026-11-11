package ui_interaction

import base "../ui_base"
import "core:testing"

@(test)
family_consumes_one_press_without_base_activation :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := create(context.allocator, &p); defer destroy(&ctx)
	targets := [1]Target{{"button", "button", true, true}}
	publish_fixture(&ctx, targets[:])
	begin_press(&ctx, "button"); base.finish_commit(&p, ctx.frame.stamp)
	testing.expect(
		t,
		consume_press(&ctx, "button") == .Applied &&
		ctx.pressed_id == "" &&
		p.sequence == 0 &&
		p.ready,
	)
	testing.expect(t, consume_press(&ctx, "button") == .Invalid_Action)
}
