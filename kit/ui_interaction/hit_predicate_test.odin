package ui_interaction

import base "../ui_base"
import "core:testing"
Hit_Probe :: struct {
	calls: int,
}
decline_last :: proc(id: string, point: [2]f64, user: rawptr) -> bool {
	p := cast(^Hit_Probe)user; p.calls += 1
	return id != "last"
}
@(test)
borrowed_predicate_selects_underlying_target_without_changing_default :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := create(context.allocator, &p); defer destroy(&ctx)
	if !testing.expect(
		t,
		publish_fixture(
			&ctx,
			[]Target{{"button", "button", true, true}, {"last", "button", true, true}},
			.Stack,
		) ==
		.Applied,
	) {return}
	n, code := hit_test(&ctx.frame, 5, 5)
	testing.expect(t, code == .Applied && n.description.id == "last")
	probe: Hit_Probe
	n, code = hit_test(&ctx.frame, 5, 5, decline_last, &probe)
	testing.expect(t, code == .Applied && n.description.id == "button" && probe.calls == 2)
	testing.expect(t, ctx.hover_id == "" && p.ready && p.sequence == 0)
}
@(test)
selected_hover_uses_current_guard_and_borrows_only_current_owned_id :: proc(t: ^testing.T) {
	p, _ := base.create(context.allocator); defer base.destroy(&p)
	ctx := create(context.allocator, &p); defer destroy(&ctx)
	if !testing.expect(
		t,
		publish_fixture(&ctx, []Target{{"button", "button", true, true}}, .Stack) == .Applied,
	) {return}
	testing.expect(
		t,
		observe_target(&ctx, "button") == .Applied && ctx.hover_id == "button" && !p.ready,
	)
	testing.expect(t, observe_target(&ctx, "") == .Not_Ready)
}
