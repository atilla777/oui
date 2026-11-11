package ui_interaction

import base "../ui_base"
import "core:testing"

@(test)
owned_activation_cannot_be_bypassed_by_plain_routed_or_pointer :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := create(context.allocator, &p); defer destroy(&ctx)
	targets := [1]Target{{"button", "button", true, true}}
	testing.expect(t, publish_fixture(&ctx, targets[:]) == .Applied)
	testing.expect(t, bind_activation_owner(&ctx.frame, "button", "hold") == .Applied)
	reader, copied := try_copy_frame(&ctx.frame, context.allocator); defer destroy_frame(&reader)
	owned, found := find(&reader, "button")
	testing.expect(
		t,
		copied && found && owned.activation_owner == "hold",
		"reader owns activation binding",
	)
	for source in Source {
		testing.expect(t, dispatch(&ctx, {.Focus, "button", source, false}).code == .Applied)
		base.finish_commit(&p, ctx.frame.stamp)
		testing.expect(
			t,
			dispatch(&ctx, {.Activate, "button", source, false}).code == .Activation_Required,
		)
		testing.expect(
			t,
			dispatch_routed(&ctx, {.Activate, "button", source, false}).code ==
			.Activation_Required,
		)
		testing.expect(t, p.ready && p.sequence == 0)
	}
	testing.expect(
		t,
		dispatch_owned(&ctx, {.Activate, "button", .Agent, false}, "wrong").code ==
		.Activation_Required,
	)
	r := dispatch_owned(&ctx, {.Activate, "button", .Agent, false}, "hold")
	testing.expect(t, r.has_event && r.event.sequence == 1 && !p.ready)
}
